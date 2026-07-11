extends Node2D
@onready var fade: CanvasLayer = $Fade
@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.start()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	
	await fade.fade(1.0,1.5).finished
	print("Level Complete")
	await fade.fade(0.0,0.1)
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
	
	pass # Replace with function body.
	
	# for main scene instantiate fade scene and then add this code into the main
