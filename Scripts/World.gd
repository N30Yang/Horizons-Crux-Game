extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado

@export var tornado_speed: float = 150

var should_move: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
#	VoiceInput.power_triggered.connect(_on_voice_power)
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	if should_move:
		tornado.position.x += tornado_speed * delta


#this makes the voice connect to the actual game 
func _on_voice_power(power_key: String) -> void:
	print("this should connect to the functions like if they pressed w to shapeshift")
	#match power_key:
		#"W": shapeshift()      # replace with real power functions
		#"E": flight()
		#"Q": break_wall()
		#"R": consequences()


func _on_timer_timeout() -> void:
	should_move = true
