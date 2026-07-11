extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado
@onready var plane: Sprite2D = $Plane
@onready var bomb: Sprite2D = $Bomb
@onready var tree: Sprite2D = $Tree

@export var tornado_speed: float = 175
@export var plane_speed: float = 150
@export var bomb_speed: float = 175

@export var bomb_land_ratio: float = 0.75

@export var tornado_base_ratio: float = 0.9

@export var hit_range: float = 120.0

const TREE_STAGES := [
	preload("res://Assets/Tree_DEAD.png"),       # 0 - dead
	preload("res://Assets/Tree-Breaking_4.png"), # 1
	preload("res://Assets/Tree-Breaking_3.png"), # 2
	preload("res://Assets/Tree-Breaking_2.png"), # 3
	preload("res://Assets/Tree-Normal.png"),     # 4 - fine
]
const MAX_HEALTH := 4
var tree_health: int = MAX_HEALTH

var tornado_moving: bool = false
var tornado_hit: bool = false
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

	tree.position = Vector2(screen_middle.x, get_viewport_rect().size.y * bomb_land_ratio)
	update_tree()
	bomb.visible = false
	tornado.visible = false
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	if tornado_moving:
		tornado.position.x += tornado_speed * delta

		if not tornado_hit and abs(tornado.position.x - tree.position.x) <= hit_range:
			tornado_hit = true
			damage_tree()
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

			if abs(bomb.position.x - tree.position.x) <= hit_range:
				damage_tree()

func drop_bomb() -> void:
	bomb_dropped = true

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


func damage_tree() -> void:
	if tree_health <= 0:
		return
	tree_health -= 1
	update_tree()
	if tree_health <= 0:
		print("[GAME] The tree has died.")

func update_tree() -> void:
	tree.texture = TREE_STAGES[tree_health]

func _on_timer_timeout() -> void:

	var roll := randf()
	if not plane_moving and roll < 0.7:
		launch_plane()
	if not tornado_moving and randf() < 0.7:
		launch_tornado()
	if not plane_moving and not tornado_moving:
		if randf() < 0.5:
			launch_plane()
		else:
			launch_tornado()
	timer.wait_time = randf_range(1.5, 6.0)

func launch_plane() -> void:
	plane.position.x = plane_start_x
	plane.visible = true
	bomb.visible = false
	bomb_dropped = false
	bomb_dropping = false
	plane_moving = true

func launch_tornado() -> void:
	tornado.position.x = tornado_start_x
	var base_y := get_viewport_rect().size.y * tornado_base_ratio
	var tex := tornado.sprite_frames.get_frame_texture(tornado.animation, tornado.frame)
	var half_h := tex.get_height() * tornado.scale.y * 0.5
	tornado.position.y = base_y - half_h
	tornado.visible = true
	tornado.play()
	tornado_moving = true
	tornado_hit = false
