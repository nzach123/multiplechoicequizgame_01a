extends Control

# --- UI NODES ---
@onready var question_label = $VBoxContainer/MarginContainer2/QuestionLabel
@onready var score_label = $VBoxContainer/MarginContainer3/HBoxContainer/ScoreLabel
@onready var timer_bar = $VBoxContainer/MarginContainer3/HBoxContainer/TimerBar
@onready var circular_timer = $VBoxContainer/MarginContainer3/HBoxContainer/TimerContainer/CircularTimer
@onready var integrity_bar = $VBoxContainer/MarginContainer3/HBoxContainer/IntegrityBar
# NOTE: If you want to show the total round time remaining, add a Label or Bar for it.
# For now, we rely on the internal timer.

# --- TIMERS ---
@onready var question_timer = $QuizTimer # Set to 15s in Inspector or Code
@onready var round_timer = $RoundTimer   # Set to 60s in Inspector

@onready var feedback_label = $FeedbackLabel
@onready var buttons = [
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button,
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button2,
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button3,
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button4
]

# --- AUDIO ---
@onready var sfx_click = $AudioManager/SFX_Click
@onready var sfx_correct = $AudioManager/SFX_Correct
@onready var sfx_wrong = $AudioManager/SFX_Wrong
@onready var sfx_alarm = $AudioManager/SFX_Alarm
@onready var sfx_ambience = $AudioManager/SFX_BackgroundMusic

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var rng = RandomNumberGenerator.new()
var camera: Camera2D
var current_q_index: int = 0
var inputs_locked: bool = false
var index_to_letter = { 0: "A", 1: "B", 2: "C", 3: "D" }

func _ready():
	# Connect Timers
	if not question_timer.timeout.is_connected(_on_question_timeout):
		question_timer.timeout.connect(_on_question_timeout)
	
	if not round_timer.timeout.is_connected(_on_round_timeout):
		round_timer.timeout.connect(_on_round_timeout)

	# Initialize UI
	integrity_bar.value = 100
	integrity_bar.max_value = 100
	
	# Sync Question Timer visual max to the timer's wait time (15s)
	question_timer.wait_time = 15.0
	timer_bar.max_value = question_timer.wait_time 
	
	# Start Audio
	if not sfx_ambience.playing:
		sfx_ambience.play()
		
	# Load Data and Start
	# If we have questions loaded (from Main Menu), use them. Otherwise load default (debug/testing).
	if GameManager.questions_pool.size() > 0:
		start_game()
	elif GameManager.load_course_data("1110"): 
		start_game()
	
	# Camera Setup
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)

func _process(delta):
	# 1. Animate Question Timer Bar
	if not question_timer.is_stopped():
		timer_bar.value = question_timer.time_left
		# Turn red if time is low
		if question_timer.time_left < 5:
			timer_bar.modulate = Color(1, 0, 0)
		else:
			timer_bar.modulate = Color(1, 1, 1)

	# 2. Update Round Timer (Circular)
	if not round_timer.is_stopped():
		circular_timer.value = round_timer.time_left

	# 3. Handle Screen Shake
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		camera.offset = Vector2(
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength)
		)

func apply_shake(intensity: float):
	shake_strength = intensity

func start_game():
	GameManager.reset_stats()
	update_score_ui()
	update_integrity_ui() # Ensure bar starts full
	
	current_q_index = 0
	GameManager.questions_pool.shuffle()
	connect_buttons()
	
	# START THE ROUND TIMER (60s hard limit)
	round_timer.start(60.0) 
	load_question(0)

func load_question(index: int):
	# Check if we ran out of questions
	if index >= GameManager.questions_pool.size():
		finish_game()
		return
	
	reset_button_visuals()
	inputs_locked = false
	feedback_label.text = ""
	timer_bar.modulate = Color(1, 1, 1)
	
	var q_data = GameManager.questions_pool[index]
	animate_text(question_label, q_data["question"])
	
	buttons[0].text = q_data["options"]["A"]
	buttons[1].text = q_data["options"]["B"]
	buttons[2].text = q_data["options"]["C"]
	buttons[3].text = q_data["options"]["D"]
	
	for btn in buttons: btn.show()
	
	# Restart Question Timer (15s)
	question_timer.start(15.0)

func animate_text(label: Label, text_content: String):
	label.text = text_content
	label.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(label, "visible_ratio", 1.0, text_content.length() * 0.02)

func connect_buttons():
	for i in range(buttons.size()):
		if buttons[i].pressed.is_connected(_on_button_pressed):
			buttons[i].pressed.disconnect(_on_button_pressed)
		buttons[i].pressed.connect(_on_button_pressed.bind(i))

func _on_button_pressed(selected_idx: int):
	if inputs_locked: return
	
	play_sound(sfx_click, true)
	
	inputs_locked = true
	question_timer.stop() # Stop the 15s timer, but Round Timer keeps ticking
	
	var selected_letter = index_to_letter[selected_idx]
	var q_data = GameManager.questions_pool[current_q_index]
	var correct_letter = q_data["answer"]
	
	var correct_idx = -1
	match correct_letter:
		"A": correct_idx = 0
		"B": correct_idx = 1
		"C": correct_idx = 2
		"D": correct_idx = 3
	
	if selected_letter == correct_letter: 
		handle_correct(selected_idx)
	else: 
		handle_wrong(selected_idx, correct_idx, q_data, selected_letter)
	
	# If game isn't over, wait and load next
	if GameManager.current_integrity > 0:
		await get_tree().create_timer(1.5).timeout
		# Double check integrity didn't drop while waiting (edge case) and timer didn't run out
		if not round_timer.is_stopped(): 
			current_q_index += 1
			load_question(current_q_index)

# --- EVENT HANDLERS ---

func _on_question_timeout():
	if inputs_locked: return
	inputs_locked = true
	
	play_sound(sfx_alarm)
	
	var q_data = GameManager.questions_pool[current_q_index]
	var correct_letter = q_data["answer"]
	var correct_idx = 0
	match correct_letter:
		"B": correct_idx = 1
		"C": correct_idx = 2
		"D": correct_idx = 3
		
	# Handle timeout as a wrong answer
	handle_wrong(-1, correct_idx, q_data, "TIMEOUT")
	
	# Check if we survived the hit
	if GameManager.current_integrity > 0:
		await get_tree().create_timer(1.5).timeout
		if not round_timer.is_stopped():
			current_q_index += 1
			load_question(current_q_index)

func _on_round_timeout():
	# 60 Seconds are up - Immediate Game Over
	finish_game()

# --- LOGIC HANDLERS ---

func handle_correct(idx):
	play_sound(sfx_correct)
	feedback_label.text = "STATUS: OPTIMAL"
	feedback_label.modulate = Color.GREEN
	apply_shake(5.0)
	
	GameManager.current_score += 100
	update_score_ui()
	buttons[idx].modulate = Color.GREEN

func handle_wrong(selected_idx, correct_idx, q_data, user_choice):
	play_sound(sfx_wrong)
	feedback_label.text = "STATUS: FAILURE - INTEGRITY LOSS"
	feedback_label.modulate = Color.RED
	apply_shake(20.0)
	
	# 1. Log the mistake
	GameManager.log_mistake(q_data["question"], user_choice, q_data["options"][q_data["answer"]])
	
	# 2. Decrease Integrity
	GameManager.current_integrity -= 20
	update_integrity_ui()
	
	# 3. Visual Feedback
	if selected_idx != -1: 
		buttons[selected_idx].modulate = Color.RED
	buttons[correct_idx].modulate = Color.GREEN 
	
	# 4. Check for Game Over triggered by Integrity
	if GameManager.current_integrity <= 0:
		finish_game()

func update_score_ui():
	score_label.text = "Score: " + str(GameManager.current_score)

func update_integrity_ui():
	var tween = create_tween()
	tween.tween_property(integrity_bar, "value", GameManager.current_integrity, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func finish_game():
	# Stop everything
	question_timer.stop()
	round_timer.stop()
	sfx_ambience.stop()
	inputs_locked = true
	
	question_label.text = "SIMULATION ENDED"
	
	# Determine reason for end
	if GameManager.current_integrity <= 0:
		feedback_label.text = "CRITICAL FAILURE: SYSTEM DESTROYED"
	else:
		feedback_label.text = "TIME LIMIT REACHED"

	# Wait briefly then switch
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/AARScreen.tscn")

# --- HELPERS ---
func play_sound(player: AudioStreamPlayer, randomize_pitch: bool = false):
	if randomize_pitch:
		player.pitch_scale = rng.randf_range(0.9, 1.1)
	else:
		player.pitch_scale = 1.0
	player.play()

func reset_button_visuals():
	for btn in buttons: 
		btn.modulate = Color.WHITE
		btn.show()
