extends Control

# --- 1. NODES ---
@onready var question_label = $VBoxContainer/MarginContainer2/QuestionLabel
@onready var score_label = $VBoxContainer/HBoxContainer/ScoreLabel
@onready var timer_label = $VBoxContainer/HBoxContainer/TimerLabel
@onready var feedback_label = $FeedbackLabel
@onready var quiz_timer = $QuizTimer

@onready var buttons = [
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button,  # Maps to "A"
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button2, # Maps to "B"
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button3, # Maps to "C"
	$VBoxContainer/MarginContainer/AnswerGridContainer/Button4  # Maps to "D"
]

# --- 2. STATE ---
var current_q_index: int = 0
var inputs_locked: bool = false
# Helper to map Index to Letter
var index_to_letter = { 0: "A", 1: "B", 2: "C", 3: "D" }

func _ready():
	if not quiz_timer.timeout.is_connected(_on_timer_timeout):
		quiz_timer.timeout.connect(_on_timer_timeout)

	# Load Data (filename is "1110" based on your uploaded file)
	if GameManager.load_course_data("1110"):
		start_game()
	else:
		question_label.text = "CRITICAL ERROR: DATA NOT FOUND"

func _process(_delta):
	if not quiz_timer.is_stopped():
		timer_label.text = "Time: " + str(ceil(quiz_timer.time_left))

func start_game():
	GameManager.reset_stats()
	update_score_ui()
	current_q_index = 0
	
	# Shuffle the question order so it's not the same every time
	GameManager.questions_pool.shuffle()
	
	connect_buttons()
	load_question(0)

func connect_buttons():
	for i in range(buttons.size()):
		if buttons[i].pressed.is_connected(_on_button_pressed):
			buttons[i].pressed.disconnect(_on_button_pressed)
		buttons[i].pressed.connect(_on_button_pressed.bind(i))

func load_question(index: int):
	if index >= GameManager.questions_pool.size():
		finish_game()
		return
		
	reset_button_visuals()
	inputs_locked = false
	feedback_label.text = ""
	
	var q_data = GameManager.questions_pool[index]
	
	# 1. Set Question Text (using your key: "question")
	question_label.text = q_data["question"]
	
	# 2. Set Option Text (using your key: "options" -> "A", "B"...)
	# We force the mapping: Button 0 gets "A", Button 1 gets "B"
	buttons[0].text = q_data["options"]["A"]
	buttons[1].text = q_data["options"]["B"]
	buttons[2].text = q_data["options"]["C"]
	buttons[3].text = q_data["options"]["D"]
	
	for btn in buttons:
		btn.show()
	
	quiz_timer.start(15)

func _on_button_pressed(selected_idx: int):
	if inputs_locked: return
	inputs_locked = true
	quiz_timer.stop()
	
	# Convert the button index (0) to the letter ("A")
	var selected_letter = index_to_letter[selected_idx]
	var correct_letter = GameManager.questions_pool[current_q_index]["answer"]
	
	# We need the index of the correct answer to highlight it Green
	var correct_idx = -1
	if correct_letter == "A": correct_idx = 0
	elif correct_letter == "B": correct_idx = 1
	elif correct_letter == "C": correct_idx = 2
	elif correct_letter == "D": correct_idx = 3
	
	if selected_letter == correct_letter:
		handle_correct(selected_idx)
	else:
		handle_wrong(selected_idx, correct_idx)
	
	await get_tree().create_timer(1.5).timeout
	current_q_index += 1
	load_question(current_q_index)

func _on_timer_timeout():
	if inputs_locked: return
	inputs_locked = true
	
	# Find the correct index to show them what they missed
	var correct_letter = GameManager.questions_pool[current_q_index]["answer"]
	var correct_idx = 0
	if correct_letter == "B": correct_idx = 1
	elif correct_letter == "C": correct_idx = 2
	elif correct_letter == "D": correct_idx = 3
	
	handle_wrong(-1, correct_idx)
	
	await get_tree().create_timer(1.5).timeout
	current_q_index += 1
	load_question(current_q_index)

func handle_correct(idx):
	feedback_label.text = "STATUS: OPTIMAL"
	feedback_label.modulate = Color.GREEN
	GameManager.current_score += 100
	update_score_ui()
	buttons[idx].modulate = Color.GREEN

func handle_wrong(selected_idx, correct_idx):
	feedback_label.text = "STATUS: FAILURE"
	feedback_label.modulate = Color.RED
	GameManager.current_integrity -= 20
	
	if selected_idx != -1:
		buttons[selected_idx].modulate = Color.RED
	buttons[correct_idx].modulate = Color.GREEN 

func reset_button_visuals():
	for btn in buttons:
		btn.modulate = Color.WHITE

func update_score_ui():
	score_label.text = "Score: " + str(GameManager.current_score)

func finish_game():
	quiz_timer.stop()
	question_label.text = "SIMULATION COMPLETE"
	feedback_label.text = "Final Score: " + str(GameManager.current_score)
	timer_label.text = "Time: --"
	for btn in buttons:
		btn.hide()
