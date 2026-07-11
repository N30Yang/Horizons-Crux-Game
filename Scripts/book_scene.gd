extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	await fade.fade(1.0,1.5).finished
	print("Level Complete")
	
	pass # Replace with function body.
