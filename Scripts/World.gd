extends Node2D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	VoiceInput.power_triggered.connect(_on_voice_power)
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

#this makes the voice connect to the actual game 
func _on_voice_power(power_key: String) -> void:
	print("this should connect to the functions like if they pressed w to shapeshift")
	#match power_key:
		#"W": shapeshift()      # replace with real power functions
		#"E": flight()
		#"Q": break_wall()
		#"R": consequences()
