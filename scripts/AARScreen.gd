extends Control
@onready var sfx_click: AudioStreamPlayer = $AudioManager/SFX_Click
@onready var sfx_result: AudioStreamPlayer = $AudioManager/SFX_Result
@onready var stats_label: Label = $VBoxContainer/StatsLabel

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
	
	# Display High Score & Mastery
	var course_id = GameManager.current_course_id
	if GameManager.player_progress.has(course_id):
		var p_data = GameManager.player_progress[course_id]
		var high_score = p_data.get("high_score", 0)
		var mastery = p_data.get("mastery_percent", 0.0)

		stats_label.text = "BEST RECORD: Score %d | Mastery %.1f%%" % [high_score, mastery]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.modulate = Color(0.8, 0.8, 1.0) # Light Blue
		
		$VBoxContainer.add_child(stats_label)
		$VBoxContainer.move_child(stats_label, 2)

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
	
	# --- FULL HISTORY DISPLAY LOGIC ---
	
	# Clear any dummy children first
	for child in mistake_container.get_children():
		child.queue_free()

	if GameManager.session_log.size() == 0:
		var lbl = Label.new()
		lbl.text = "NO DATA RECORDED."
		lbl.modulate = Color.GRAY
		mistake_container.add_child(lbl)
	else:
		for entry in GameManager.session_log:
			var entry_label = Label.new()
			
			# Default to Success styling
			var status_text = "[SUCCESS]"
			var status_color = Color.GREEN
			
			# Check for Failure
			if entry.has("is_correct") and entry["is_correct"] == false:
				status_text = "[FAIL]"
				status_color = Color(1, 0.4, 0.4) # Pale Red
			
			# Build the text string
			# Format: "Q: [Question] \n [SUCCESS] You chose: [Answer]"
			var final_text = "Q: " + entry["question"] + "\n" 
			final_text += status_text + " You chose: " + entry["user_choice"]
			
			# If wrong, append the correct answer
			if entry.has("is_correct") and entry["is_correct"] == false:
				final_text += " | Correct: " + entry["correct_answer"]
			
			final_text += "\n" # Spacing
			
			entry_label.text = final_text
			entry_label.modulate = status_color
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
