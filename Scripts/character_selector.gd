extends Control

#set constants like
# const KNIGHT_PATH = "res"
# const IMAGE_PATH = ""


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_texture_button_pressed() -> void:
	print("hello")
	GameManager.selected_character_path = "Blondie"
	get_tree().change_scene_to_file("res://cutscene.tscn")
	pass # Replace with function body.


func _on_texture_button_2_pressed() -> void:
	GameManager.selected_character_path = "Brownie"
	get_tree().change_scene_to_file("res://cutscene.tscn")
	print("hello")
	pass # Replace with function body.
