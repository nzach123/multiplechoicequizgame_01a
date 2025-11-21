extends Control

signal acknowledged

@onready var explanation_label = $Panel/VBoxContainer/ExplanationLabel
@onready var acknowledge_button = $Panel/VBoxContainer/AcknowledgeButton

func _ready():
	acknowledge_button.pressed.connect(_on_acknowledge_pressed)

func set_explanation(text: String):
	explanation_label.text = text

func _on_acknowledge_pressed():
	acknowledged.emit()
