extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado

@export var tornado_speed: float = 150

var tornado_direction: Vector2 = Vector2.RIGHT
var time_since_last_move: float = 0.0
var move_interval: float = 3.0
var is_moving: bool = false
var move_duration: float = 1.0
var move_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	VoiceInput.power_triggered.connect(_on_voice_power)
	timer.start()
	tornado.play()
	_reset_move_interval()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_moving:
		tornado.position += tornado_direction * tornado_speed * delta
		move_timer += delta
		if move_timer >= move_duration:
			is_moving = false
			move_timer = 0.0
	else:
		time_since_last_move += delta
		if time_since_last_move >= move_interval:
			_start_move_burst()

func _start_move_burst() -> void:
	is_moving = true
	time_since_last_move = 0.0
	_reset_move_interval()
	tornado_direction = Vector2.RIGHT.rotated(randf_range(-0.3, 0.3))

func _reset_move_interval() -> void:
	move_interval = randf_range(2.0, 6.0)
#this makes the voice connect to the actual game 

func _on_voice_power(power_key: String) -> void:
	print("this should connect to the functions like if they pressed w to shapeshift")
	#match power_key:
		#"W": shapeshift()      # replace with real power functions
		#"E": flight()
		#"Q": break_wall()
		#"R": consequences()


func _on_timer_timeout() -> void:
	pass # Replace with function body.
