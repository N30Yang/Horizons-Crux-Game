extends Camera2D

var start_zoom: Vector2
var target_zoom: Vector2
var interp_time := 0.0
var interp_duration := 0.3
var zoom_center: Vector2


func start_zoom_transition(new_zoom: Vector2, center_point: Vector2):
	start_zoom = zoom
	target_zoom = new_zoom
	interp_time = 0.0
	zoom_center = center_point

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	zoom = Vector2(1,1)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	zoom-= Vector2(0.01,0.01) * delta

# Adjust camera position to keep zoom center fixed
