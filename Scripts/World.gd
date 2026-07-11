extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado
@onready var plane: Sprite2D = $Plane
@onready var bomb: Sprite2D = $Bomb

@export var tornado_speed: float = 175
@export var plane_speed: float = 150
@export var bomb_speed: float = 175
# fraction of screen height where bomb lands (0.75 = bottom quadrant)
@export var bomb_land_ratio: float = 0.75
# fraction of screen height where tornado base sits (0.9 = bottom quadrant)
@export var tornado_base_ratio: float = 0.9

var tornado_moving: bool = false
var plane_moving: bool = false
var bomb_dropped: bool = false
var bomb_dropping: bool = false
var screen_middle: Vector2
var plane_start_x: float
var tornado_start_x: float

func _ready() -> void:
	VoiceInput.power_triggered.connect(_on_voice_power)
	screen_middle = get_viewport_rect().size / 2
	plane_start_x = plane.position.x
	tornado_start_x = tornado.position.x
	bomb.visible = false
	tornado.visible = false
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	if tornado_moving:
		tornado.position.x += tornado_speed * delta
		if tornado.position.x > get_viewport_rect().size.x + 100:
			tornado_moving = false
			tornado.visible = false

	if plane_moving:
		plane.position.x -= plane_speed * delta
		if not bomb_dropped and plane.position.x <= screen_middle.x:
			drop_bomb()
		if plane.position.x < -100:
			plane_moving = false
			plane.visible = false

	if bomb_dropping:
		bomb.position.y += bomb_speed * delta
		var land_y := get_viewport_rect().size.y * bomb_land_ratio
		if bomb.position.y >= land_y:
			bomb.position.y = land_y
			bomb_dropping = false
			bomb.visible = false

func drop_bomb() -> void:
	bomb_dropped = true
	# fall from bottom of plane
	bomb.global_position = plane.global_position + Vector2(0, plane.get_rect().size.y * plane.scale.y * 0.5)
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


func _on_timer_timeout() -> void:
	if not plane_moving:
		launch_plane()
	if not tornado_moving:
		launch_tornado()
	timer.wait_time = randf_range(3.0, 8.0)

func launch_plane() -> void:
	plane.position.x = plane_start_x
	plane.visible = true
	bomb.visible = false
	bomb_dropped = false
	bomb_dropping = false
	plane_moving = true

func launch_tornado() -> void:
	tornado.position.x = tornado_start_x
	# base (bottom of sprite) sits in bottom quadrant
	var base_y := get_viewport_rect().size.y * tornado_base_ratio
	var tex := tornado.sprite_frames.get_frame_texture(tornado.animation, tornado.frame)
	var half_h := tex.get_height() * tornado.scale.y * 0.5
	tornado.position.y = base_y - half_h
	tornado.visible = true
	tornado.play()
	tornado_moving = true
