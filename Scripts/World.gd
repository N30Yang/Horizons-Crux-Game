extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado
@onready var plane: Sprite2D = $Plane
@onready var bomb: Sprite2D = $Bomb

@export var tornado_speed: float = 175
@export var plane_speed: float = 150
@export var bomb_speed: float = 300

var should_move: bool = false

var plane_moving: bool = false
var bomb_dropped: bool = false
var bomb_dropping: bool = false
var screen_middle: Vector2
var plane_start_x: float

func _ready() -> void:
	VoiceInput.power_triggered.connect(_on_voice_power)
	screen_middle = get_viewport_rect().size / 2
	plane_start_x = plane.position.x
	bomb.visible = false
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	if should_move:
		tornado.position.x += tornado_speed * delta

	if plane_moving:
		plane.position.x -= plane_speed * delta
		if not bomb_dropped and plane.position.x <= screen_middle.x:
			drop_bomb()
		if plane.position.x < -100:
			plane_moving = false

	if bomb_dropping:
		bomb.position.y += bomb_speed * delta
		if bomb.position.y >= screen_middle.y:
			bomb.position.y = screen_middle.y
			bomb_dropping = false

func drop_bomb() -> void:
	bomb_dropped = true
	bomb.global_position = plane.global_position
	bomb.visible = true
	bomb_dropping = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			VoiceInput.start_listening()
			print("[GAME] Voice listening started. Speak now!")

func _on_voice_power(power_key: String) -> void:
	match power_key:
		"W":
			pass # flight()
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
	if not plane_moving:
		launch_plane()
	timer.wait_time = randf_range(3.0, 8.0)

func launch_plane() -> void:
	plane.position.x = plane_start_x
	bomb.visible = false
	bomb_dropped = false
	bomb_dropping = false
	plane_moving = true
