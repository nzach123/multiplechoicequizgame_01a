extends Control

# --- UI NODES ---
@onready var question_label = $VBoxContainer/MarginContainer2/QuestionLabel
@onready var score_label = $VBoxContainer/MarginContainer3/HBoxContainer/ScoreLabel
@onready var timer_bar = $VBoxContainer/MarginContainer3/HBoxContainer/TimerBar
@onready var circular_timer = $VBoxContainer/MarginContainer3/HBoxContainer/TimerContainer/CircularTimer
# We treat the old IntegrityBar as the new RescueBar
@onready var rescue_bar = $VBoxContainer/MarginContainer3/HBoxContainer/RescueBar 

# --- TIMERS ---
@onready var question_timer = $QuizTimer 
@onready var round_timer = $RoundTimer   

@onready var feedback_label = $FeedbackLabel
@onready var remediation_popup = $RemediationPopup
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
var current_shuffled_answers = []

# --- RESCUE MECHANIC VARIABLES ---
var total_population: int = 0
var citizens_saved: int = 0
var save_weight: int = 0

func _ready():
	# Connect Timers
	if not question_timer.timeout.is_connected(_on_question_timeout):
		question_timer.timeout.connect(_on_question_timeout)
	
	if not round_timer.timeout.is_connected(_on_round_timeout):
		round_timer.timeout.connect(_on_round_timeout)

	# Initialize Population Logic
	total_population = rng.randi_range(2000, 5000)
	citizens_saved = 0
	
	# Setup Rescue Bar UI
	rescue_bar.min_value = 0
	rescue_bar.max_value = total_population
	rescue_bar.value = 0
	rescue_bar.show_percentage = false # We will handle text manually if needed, or rely on the bar visuals
	
	# Sync Question Timer visual
	question_timer.wait_time = 15.0
	timer_bar.max_value = question_timer.wait_time 
	
	# Start Audio
	if not sfx_ambience.playing:
		sfx_ambience.play()
		
	remediation_popup.acknowledged.connect(_on_remediation_acknowledged)

	# Load Data
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
	
	current_q_index = 0
	GameManager.questions_pool.shuffle()
	
	# Calculate weight per question based on total questions
	var q_count = GameManager.questions_pool.size()
	if q_count > 0:
		save_weight = total_population / q_count
	else:
		save_weight = 100 # Fallback
	
	update_score_ui()
	update_rescue_ui()
	
	connect_buttons()
	
	# START THE ROUND TIMER (60s hard limit)
	round_timer.start(60.0) 
	load_question(0)

func load_question(index: int):
	if index >= GameManager.questions_pool.size():
		finish_game()
		return
	
	reset_button_visuals()
	inputs_locked = false
	feedback_label.text = ""
	timer_bar.modulate = Color(1, 1, 1)
	
	var q_data = GameManager.questions_pool[index]
	animate_text(question_label, q_data["question"])
	
	current_shuffled_answers = q_data["answers"].duplicate()
	current_shuffled_answers.shuffle()
	
	for i in range(buttons.size()):
		if i < current_shuffled_answers.size():
			buttons[i].text = current_shuffled_answers[i]["text"]
			buttons[i].show()
		else:
			buttons[i].hide()
	
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
	question_timer.stop() 
	
	var q_data = GameManager.questions_pool[current_q_index]
	var selected_answer_obj = current_shuffled_answers[selected_idx]
	var is_correct = selected_answer_obj["is_correct"]
	
	var correct_idx = -1
	for i in range(current_shuffled_answers.size()):
		if current_shuffled_answers[i]["is_correct"]:
			correct_idx = i
			break
	
	if is_correct: 
		handle_correct(selected_idx)
		# Wait and load next
		await get_tree().create_timer(1.5).timeout
		if not round_timer.is_stopped(): 
			current_q_index += 1
			load_question(current_q_index)
	else: 
		handle_wrong(selected_idx, correct_idx, q_data, selected_answer_obj["text"])

# --- EVENT HANDLERS ---

func _on_question_timeout():
	if inputs_locked: return
	inputs_locked = true
	
	play_sound(sfx_alarm)
	
	var q_data = GameManager.questions_pool[current_q_index]
	var correct_idx = 0
	for i in range(current_shuffled_answers.size()):
		if current_shuffled_answers[i]["is_correct"]:
			correct_idx = i
			break
		
	# Handle timeout as wrong
	handle_wrong(-1, correct_idx, q_data, "TIMEOUT")

func _on_round_timeout():
	finish_game()

# --- LOGIC HANDLERS ---

func handle_correct(idx):
	play_sound(sfx_correct)
	
	# Logic: Save Citizens
	citizens_saved += save_weight
	# Clamp to max just in case
	if citizens_saved > total_population:
		citizens_saved = total_population
		
	feedback_label.text = "RESCUE CONFIRMED"
	feedback_label.modulate = Color.CYAN # Blue-ish for rescue
	apply_shake(5.0)
	
	GameManager.add_correct_answer()
	update_score_ui()
	update_rescue_ui()
	buttons[idx].modulate = Color.GREEN

func handle_wrong(selected_idx, correct_idx, q_data, user_choice_text):
	# Logic: Signal Lost / Static (No deduction)
	play_sound(sfx_wrong) 
	feedback_label.text = "SIGNAL LOST - RESCUE FAILED"
	feedback_label.modulate = Color.ORANGE
	apply_shake(10.0)
	
	var correct_text = "Unknown"
	for ans in current_shuffled_answers:
		if ans["is_correct"]:
			correct_text = ans["text"]
			break
	
	GameManager.log_mistake(q_data["question"], user_choice_text, correct_text)
	
	# Visuals only
	if selected_idx != -1 and selected_idx < buttons.size(): 
		buttons[selected_idx].modulate = Color.RED
	if correct_idx != -1 and correct_idx < buttons.size():
		buttons[correct_idx].modulate = Color.GREEN 
	
	# Wait for remediation
	round_timer.paused = true
	question_timer.paused = true
	
	await get_tree().create_timer(1.5).timeout
	
	var explanation = q_data.get("explanation", "No explanation provided.")
	remediation_popup.set_explanation(explanation)
	remediation_popup.show()

func _on_remediation_acknowledged():
	remediation_popup.hide()
	
	round_timer.paused = false
	question_timer.paused = false
	
	current_q_index += 1
	load_question(current_q_index)

func update_score_ui():
	score_label.text = "Score: " + str(GameManager.current_score)

func update_rescue_ui():
	var tween = create_tween()
	tween.tween_property(rescue_bar, "value", citizens_saved, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# We can reuse the tooltip or add a dynamic label if the node structure allows, 
	# but for now the bar fills up visually. 
	# If score_label can double as info, we might append it, but let's stick to the bar filling.
	rescue_bar.tooltip_text = "Rescued: %d / %d" % [citizens_saved, total_population]

func finish_game():
	question_timer.stop()
	round_timer.stop()
	sfx_ambience.stop()
	inputs_locked = true
	
	# Save Logic
	var total_attempted = GameManager.correct_answers_count + GameManager.session_log.size()
	var mastery_percent = 0.0
	if total_attempted > 0:
		mastery_percent = (float(GameManager.correct_answers_count) / total_attempted) * 100.0
	
	var course_id = GameManager.current_course_id
	if not GameManager.player_progress.has(course_id):
		GameManager.player_progress[course_id] = { "high_score": 0, "mastery_percent": 0.0 }
	
	if GameManager.current_score > GameManager.player_progress[course_id]["high_score"]:
		GameManager.player_progress[course_id]["high_score"] = GameManager.current_score
	if mastery_percent > GameManager.player_progress[course_id]["mastery_percent"]:
		GameManager.player_progress[course_id]["mastery_percent"] = mastery_percent
		
	GameManager.save_game()
	
	# Win/Loss Calculation
	var rescue_percentage = 0.0
	if total_population > 0:
		rescue_percentage = float(citizens_saved) / float(total_population)
	
	question_label.text = "OPERATION COMPLETE"
	
	if rescue_percentage >= 0.5:
		feedback_label.text = "SUCCESS: CIVILIAN EVAC COMPLETE"
		feedback_label.modulate = Color.GREEN
	else:
		feedback_label.text = "MISSION FAILED: CASUALTIES TOO HIGH"
		feedback_label.modulate = Color.RED

	await get_tree().create_timer(2.0).timeout
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
