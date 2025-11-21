extends Node

# Course Data
var questions_pool = []
var current_course_id = ""

# Session Data
var current_score = 0
var current_integrity = 100


var session_log = [] # Stores dictionary of { "question": "", "user_choice": "", "correct_answer": "" }

func load_course_data(course_id: String):
	current_course_id = course_id
	var file_path = "res://assets/questions/" + course_id + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			questions_pool = json.data
			return true
	return false

func reset_stats():
	current_score = 0
	current_integrity = 100
	session_log.clear() 

func log_mistake(question_text, user_choice, correct_answer):
	session_log.append({
		"question": question_text,
		"user_choice": user_choice,
		"correct_answer": correct_answer
	})
