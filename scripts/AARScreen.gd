extends Control
@onready var sfx_click: AudioStreamPlayer = $AudioManager/SFX_Click
@onready var sfx_result: AudioStreamPlayer = $AudioManager/SFX_Result

@onready var score_label = $VBoxContainer/ScoreLabel
@onready var rank_label = $VBoxContainer/RankLabel
@onready var mistake_container = $VBoxContainer/ScrollContainer/VBoxContainer

var sfx_success = preload("res://assets/audio/Loops/Retro Polka.ogg")
var sfx_fail = preload("res://assets/audio/Loops/computerNoise_003.ogg")

func _ready():
	display_results()
	$VBoxContainer/RetryButton.pressed.connect(func(): play_click(); _on_retry())
	$VBoxContainer/MenuButton.pressed.connect(func(): play_click(); _on_menu())

func display_results():
	score_label.text = "FINAL SCORE: " + str(GameManager.current_score)
	
	# Calculate Rank
	var rank = "F"
	var color = Color.WHITE # Default
	var integrity = GameManager.current_integrity
	var score = GameManager.current_score
	
	if integrity <= 0:
		rank = "KIA (F)"
		color = Color(0.9, 0, 0) # Bright Red
	elif score >= 1000 and integrity == 100:
		rank = "INCIDENT COMMANDER (S)"
		color = Color(1, 0.84, 0) # Gold
	elif score >= 800:
		rank = "SECTION CHIEF (A)"
		color = Color(0, 1, 0) # Green
	elif score >= 500:
		rank = "DEPUTY (B)"
		color = Color(0.5, 0.5, 1) # Blue
	else:
		rank = "INTERN (C)"
		color = Color(0.7, 0.7, 0.7) # Grey
	
	rank_label.text = "PERFORMANCE RATING: " + rank
	rank_label.modulate = color
	
	# Play Audio based on outcome
	if integrity <= 0:
		sfx_result.stream = sfx_fail
	else:
		sfx_result.stream = sfx_success
	
	sfx_result.play()
	
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
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	
func play_click():
	sfx_click.play()
	await sfx_click.finished
