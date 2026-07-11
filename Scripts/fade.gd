extends CanvasLayer
@onready var fade: CanvasLayer = $"."
@onready var color_rect: ColorRect = $ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	color_rect.color.a =0.0
	pass # Replace with function body.

func fadeout (target_alpha: float, duration: float =1.0):
	var tween= create_tween()
	tween.tween_property(color_rect,"color:a",target_alpha, duration)
	return tween
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
