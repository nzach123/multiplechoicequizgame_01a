extends Node

# DATA MANAGEMENT
var questions_pool: Array = [] # Holds the raw list of questions
var current_score: int = 0
var current_integrity: int = 100
var max_integrity: int = 100

# LOADER
func load_course_data(filename: String) -> bool:
	questions_pool.clear() # Clean slate
	
	var path = "res://assets/questions/" + filename + ".json"
	if not FileAccess.file_exists(path):
		printerr("CRITICAL: File not found at " + path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		if json.data is Array:
			questions_pool = json.data
			print("SUCCESS: Loaded " + str(questions_pool.size()) + " questions.")
			return true
		else:
			printerr("CRITICAL: JSON format error. Expected an Array [ ... ]")
			return false
	else:
		printerr("JSON Parse Error: " + json.get_error_message())
		return false

func reset_stats():
	current_score = 0
	current_integrity = max_integrity
