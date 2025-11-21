extends Node

# Course Data
var questions_pool = []
var current_course_id = ""

# Session Data
var current_score = 0
var correct_answers_count = 0
var current_integrity = 100

# Persistent Data
var player_progress = {}
var save_path = "user://savegame.save"

var session_log = [] # Stores dictionary of { "question": "", "user_choice": "", "correct_answer": "" }

func _ready():
	load_game()

func load_course_data(course_id: String):
	current_course_id = course_id
	var file_path = "res://assets/questions/" + course_id + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			# Basic validation for new schema
			if json.data.size() > 0 and json.data[0].has("answers") and json.data[0]["answers"] is Array:
				questions_pool = json.data
				return true
			else:
				print("Error: Loaded data does not match expected schema.")
				return false
	return false

func reset_stats():
	current_score = 0
	correct_answers_count = 0
	current_integrity = 100
	session_log.clear() 

func add_correct_answer():
	correct_answers_count += 1
	current_score = correct_answers_count * 100

func save_game():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(player_progress)
		file.store_string(json_string)
		file.close()

func load_game():
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			player_progress = json.data
		file.close()

func log_mistake(question_text, user_choice, correct_answer):
	session_log.append({
		"question": question_text,
		"user_choice": user_choice,
		"correct_answer": correct_answer
	})
