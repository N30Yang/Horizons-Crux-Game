extends CharacterBody2D
@onready var blonde_character: AnimatedSprite2D = $BlondeCharacter
@onready var brownie_character: AnimatedSprite2D = $BrownieCharacter
@onready var sprite: AnimatedSprite2D = $BlondeCharacter

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const BIRD_VELOCITY = -5000.0
var direction1:Vector2=Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	
	
	if (GameManager.selected_character_path == "Blondie"):
		print("yss")
		sprite = $BlondeCharacter
		blonde_character.visible = true
	if (GameManager.selected_character_path == "Brownie"):
		sprite=$BrownieCharacter
		brownie_character.visible = true
		
func _on_node_2d_2_shapeshift(animal: Variant) -> void:
	
	var rand_int = randi_range(1,5)

	if (rand_int == 1):
		GameManager.currentanimal = "bear"
	if (rand_int == 2):
		GameManager.currentanimal= "capybara"
	if (rand_int == 3):
		GameManager.currentanimal = "blobfish"
	if (rand_int == 4):
		GameManager.currentanimal="bird"
	if (rand_int == 5):
		GameManager.currentanimal = "human"
	print(GameManager.currentanimal)
	#could be capybara, blobfish, bird, or bear
	
	
	
	pass
func _physics_process(delta: float) -> void:
	
	if (not is_on_floor() ):
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and GameManager.currentanimal == "bird" :
		velocity.y= BIRD_VELOCITY
	
		
	if Input.is_action_just_pressed("jump") and is_on_floor() :
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	direction1 = Input.get_vector("left", "right","up","down")
	if direction :
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
		
		
		
			
			
			
	move_and_slide()
	update_facing_direction()
	
func update_facing_direction()  :
	if direction1.x > 0 :
		sprite.flip_h=false
		
	elif direction1.x <0:
		sprite.flip_h=true
		print ("flip")

pass # Replace with function body.
