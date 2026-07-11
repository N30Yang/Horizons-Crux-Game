extends Node2D

@onready var fade: CanvasLayer = $Fade
@onready var timer: Timer = $Timer

var transitioning := false

func _ready() -> void:
	timer.start()

func _input(event):
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed:
		skip()

func skip():
	if transitioning:
		return

	transitioning = true
	timer.stop()

	await fade.fade(1.0, 1.5).finished
	print("Level Complete")
	await fade.fade(0.0, 0.1).finished
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func _on_timer_timeout() -> void:
	await skip()
