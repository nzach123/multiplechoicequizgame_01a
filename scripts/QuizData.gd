extends Node

var question_bank = []

const QUESTION_FILES = [
	"res://assets/questions/1110.json",
	"res://assets/questions/1120.json",
	"res://assets/questions/1130.json",
	"res://assets/questions/1140.json",
]

func _ready() -> void:
	load_all_questions()

func load_all_questions():
	for file_path in QUESTION_FILES:
		var file = FileAccess.open(file_path, FileAccess.READ)
		
		if file == null:
			print("ERROR: Could not load question file: ", file_path)
			continue
		
		var json = JSON.new()
		var error = json.parse(content)
		
		if error != OK:
			print("ERROR: Failed to parse JSON in file: ", file_path)
			continue
		
		var data = json.get_data()
		
		if data is Array:
			question_bank.append_array(data)
	
	question_bank.shuffle()
	print("Successfully loaded ", question_bank.size(), " total questions.")
	
func get_all_questions():
	return question_bank
	
func get_random_question():
	if question_bank.is_empty():
		return null
		
	return question_bank.pick_random()
