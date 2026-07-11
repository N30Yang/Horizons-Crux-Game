extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado

@export var tornado_speed: float = 150

var should_move: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	VoiceInput.power_triggered.connect(_on_voice_power)
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	if should_move:
		tornado.position.x += tornado_speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			VoiceInput.start_listening()
			print("[GAME] Voice listening started. Speak now!")


#this makes the voice connect to the actual game 
func _on_voice_power(power_key: String) -> void:
	match power_key:
		"W":
			spawn_tornado()
		"E":
			pass # flight()
		"Q":
			pass # break_wall()
		"R":
			pass # consequences()

func spawn_tornado() -> void:
	should_move = true
	tornado.play()


func _on_timer_timeout() -> void:
	# should_move = true
	
	pass # Replace with function body.
