extends Control

@onready var score_label = $VBoxContainer/ScoreLabel
@onready var rank_label = $VBoxContainer/RankLabel
@onready var mistake_container = $VBoxContainer/ScrollContainer/VBoxContainer

func _ready():
	display_results()
	$VBoxContainer/RetryButton.pressed.connect(_on_retry)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu)

func display_results():
	score_label.text = "FINAL SCORE: " + str(GameManager.current_score)
	
	# Calculate Rank
	var rank = "F"
	var integrity = GameManager.current_integrity
	var score = GameManager.current_score
	
	if integrity <= 0: rank = "KIA (F)"
	elif score >= 1000 and integrity == 100: rank = "INCIDENT COMMANDER (S)" # Adjust threshold
	elif score >= 800: rank = "SECTION CHIEF (A)"
	elif score >= 500: rank = "DEPUTY (B)"
	else: rank = "INTERN (C)"
	
	rank_label.text = "PERFORMANCE RATING: " + rank
	
	# Populate Mistake List
	if GameManager.session_log.size() == 0:
		var lbl = Label.new()
		lbl.text = "NO ERRORS DETECTED. EXCELLENT WORK."
		lbl.modulate = Color.GREEN
		mistake_container.add_child(lbl)
	else:
		for entry in GameManager.session_log:
			var entry_label = Label.new()
			entry_label.text = "Q: " + entry["question"] + "\n" + "You chose: " + entry["user_choice"] + " | Correct: " + entry["correct_answer"] + "\n"
			entry_label.modulate = Color(1, 0.5, 0.5) # Pale Red
			entry_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			mistake_container.add_child(entry_label)

func _on_retry():
	get_tree().change_scene_to_file("res://scenes/quiz_scene.tscn")

func _on_menu():
	# For now, just restart. Later we will link to a Main Menu.
	get_tree().change_scene_to_file("res://scenes/quiz_scene.tscn")
