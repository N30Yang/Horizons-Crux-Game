extends Node2D

@onready var timer: Timer= $Timer
@onready var tornado: AnimatedSprite2D=$Tornado
#make boolean here


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#VoiceInput.power_triggered.connect(_on_voice_power)
	timer.start()
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#on boolean up the top is true play the tornado moving to the left in delta time
	pass

#this makes the voice connect to the actual game 
func _on_voice_power(power_key: String) -> void:
	print("this should connect to the functions like if they pressed w to shapeshift")
	#match power_key:
		#"W": shapeshift()      # replace with real power functions
		#"E": flight()
		#"Q": break_wall()
		#"R": consequences()


func _on_timer_timeout() -> void:
	tornado.play("default")
	tornado.position = Vector2(tornado.position.y,tornado.position.y)
	#move this to process and set to delta time
	# set boolean named up top to true here
	pass # Replace with function body.
