extends Control

# Exported dictionary for category labels
@export var category_names: Dictionary = {
	"1110": "BASIC SAFETY",
	"1120": "PROTOCOL ALPHA",
	"1130": "CONTAINMENT",
	"1140": "CRITICAL RESPONSE"
}

@onready var buttons_container = $VBoxContainer/MarginContainer/VBoxContainer
@onready var sfx_click = $AudioManager/SFX_Click

# Helper variable to track available question files
var available_courses = []

func _ready():
	# Scan for available question files
	scan_courses()
	create_menu_buttons()

func scan_courses():
	var dir = DirAccess.open("res://assets/questions/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".json"):
				var course_id = file_name.replace(".json", "")
				available_courses.append(course_id)
			file_name = dir.get_next()
		available_courses.sort() # Ensure consistent order

func create_menu_buttons():
	# Clear existing placeholder buttons if any (though we'll build the scene empty)
	for child in buttons_container.get_children():
		child.queue_free()
	
	for course_id in available_courses:
		var btn = Button.new()
		var title_style = load("res://resources/themes/title_theme.tres")
		var display_name = course_id
		if category_names.has(course_id):
			display_name = course_id + " - " + category_names[course_id]
		
		btn.text = display_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_stylebox_override("normal", title_style)
		btn.add_theme_font_size_override("font_size", 45)
		# Add some visual flair/theme if needed, or rely on default Theme
		# We'll rely on the theme assigned to the parent or project default
		
		btn.pressed.connect(_on_category_selected.bind(course_id))
		buttons_container.add_child(btn)

func _on_category_selected(course_id):
	sfx_click.play()
	# Wait for sound or just go
	# We'll use a small timer or just switch immediately. 
	# A helper for sound would be nice but we'll keep it simple.
	
	if GameManager.load_course_data(course_id):
		get_tree().change_scene_to_file("res://scenes/quiz_scene.tscn")
	else:
		print("Failed to load course: " + course_id)
