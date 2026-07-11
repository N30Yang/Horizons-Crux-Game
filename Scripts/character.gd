extends Node2D
@onready var blonde_character: AnimatedSprite2D = $BlondeCharacter
@onready var brownie_character: AnimatedSprite2D = $BrownieCharacter


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if (GameManager.selected_character_path == "Blondie"):
		print("yss")
		blonde_character.visible = true
	if (GameManager.selected_character_path == "Brownie"):
		brownie_character.visible = true
	pass
