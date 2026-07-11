extends Control

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	print("hello")
	get_tree().change_scene_to_file("res://Scenes/CharacterSelector.tscn")
	pass # Replace with function body.


func _on_menu_button_pressed() -> void:
	print("hello")
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	print("hello")
	pass # Replace with function body.
