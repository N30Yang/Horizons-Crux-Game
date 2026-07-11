extends CharacterBody2D
@onready var blonde_character: AnimatedSprite2D = $BlondeCharacter
@onready var brownie_character: AnimatedSprite2D = $BrownieCharacter
@onready var sprite: AnimatedSprite2D = $BlondeCharacter

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const BIRD_VELOCITY = -5000.0
var direction1: Vector2 = Vector2.ZERO

# --- Voice-driven movement state --------------------------------------------
# Voice is discrete, movement is continuous. A recognized "left"/"right" drives
# the character for VOICE_MOVE_DURATION seconds unless "stop" cancels it.
const VOICE_MOVE_DURATION := 1.2
var voice_direction: float = 0.0 # -1 left, +1 right, 0 none
var voice_move_timer: float = 0.0
var voice_jump_queued: bool = false

# Config power_key -> animal value (see voice_config.json).
const ANIMAL_POWERS := {
	"BEAR": "bear",
	"CAPYBARA": "capybara",
	"BLOBFISH": "blobfish",
	"BIRD": "bird",
	"HUMAN": "human",
	"LION": "lion"
}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Same wiring as World.gd: voice_config keywords -> power_triggered(key).
	VoiceInput.power_triggered.connect(_on_voice_power)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (GameManager.selected_character_path == "Blondie"):
		sprite = $BlondeCharacter
		blonde_character.visible = true
	if (GameManager.selected_character_path == "Brownie"):
		sprite = $BrownieCharacter
		brownie_character.visible = true
		
func _on_node_2d_2_shapeshift(animal: Variant) -> void:
	shapeshift_random()


# Pick a random animal. Used by the shapeshift signal and the "shapeshift"
# voice word.
func shapeshift_random() -> void:
	var animals := ["bear", "capybara", "blobfish", "bird", "human","lion" ]
	GameManager.currentanimal = animals[randi() % animals.size()]
	print("[SHAPESHIFT] random -> ", GameManager.currentanimal)


# Switch to a named animal directly.
func set_animal(animal: String) -> void:
	GameManager.currentanimal = animal
	print("[SHAPESHIFT] named -> ", GameManager.currentanimal)


# voice_config keyword matched -> power key. Same signal World.gd listens to.
func _on_voice_power(power_key: String) -> void:
	match power_key:
		"MOVE_LEFT":
			voice_direction = -1.0
			voice_move_timer = VOICE_MOVE_DURATION
		"MOVE_RIGHT":
			voice_direction = 1.0
			voice_move_timer = VOICE_MOVE_DURATION
		"STOP":
			voice_direction = 0.0
			voice_move_timer = 0.0
		"JUMP":
			voice_jump_queued = true
		"SHAPESHIFT":
			shapeshift_random()
		_:
			# Named animal -> switch to it; anything else (W/E/Q) ignored here.
			if ANIMAL_POWERS.has(power_key):
				set_animal(ANIMAL_POWERS[power_key])
func _physics_process(delta: float) -> void:
	if (not is_on_floor()):
		velocity += get_gravity() * delta

	# Count down the voice-move window.
	if voice_move_timer > 0.0:
		voice_move_timer -= delta
		if voice_move_timer <= 0.0:
			voice_direction = 0.0

	# Jump from keyboard OR a queued voice "jump".
	var jump_pressed := Input.is_action_just_pressed("jump") or voice_jump_queued
	voice_jump_queued = false
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle jump.
	if jump_pressed and is_on_floor() and GameManager.currentanimal == "bird":
		velocity.y = BIRD_VELOCITY
	
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	# Keyboard takes priority; fall back to the active voice direction.
	var direction := Input.get_axis("left", "right")
	if direction == 0.0 and voice_move_timer > 0.0:
		direction = voice_direction
	direction1 = Input.get_vector("left", "right", "up", "down")
	if direction1.x == 0.0 and direction != 0.0:
		direction1.x = direction
	if direction:
		velocity.x = direction * SPEED
		
		if (GameManager.currentanimal == "human"):
			sprite.play("default")
		if (GameManager.currentanimal == "bear"):
			sprite.play("bear")
		if (GameManager.currentanimal == "capybara"):
			sprite.play("capybara")
		if (GameManager.currentanimal == "blobfish"):
			sprite.play("blobfish")
		if (GameManager.currentanimal == "bird"):
			sprite.play("bird")
		if (GameManager.currentanimal == "lion"):
			sprite.play("lion")
		
		
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		
		if (GameManager.currentanimal == "human"):
			sprite.play("still")
		if (GameManager.currentanimal == "bear"):
			sprite.play("bear")
		if (GameManager.currentanimal == "capybara"):
			sprite.play("capybara")
		if (GameManager.currentanimal == "blobfish"):
			sprite.play("blobfish")
		if (GameManager.currentanimal == "bird"):
			sprite.play("bird")
		if (GameManager.currentanimal == "lion"):
			sprite.play("lionstill")
		
		
	move_and_slide()
	update_facing_direction()
	
func update_facing_direction():
	if direction1.x > 0:
		sprite.flip_h = false
		
	elif direction1.x < 0:
		sprite.flip_h = true

pass # Replace with function body.
