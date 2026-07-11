extends Node2D

@onready var timer: Timer = $Timer
@onready var tornado: AnimatedSprite2D = $Tornado
@onready var plane: Sprite2D = $Plane
@onready var bomb: Sprite2D = $Bomb
@onready var tree: Sprite2D = $Tree
@onready var jet: Sprite2D = $Jet
@onready var rocket: Sprite2D = $Rocket
@onready var background: Sprite2D = $Background
@onready var foreground: Sprite2D = $Foreground
@onready var tree_hitbox: Area2D = $Tree/Hitbox

@export var tornado_speed: float = 175
@export var plane_speed: float = 150
@export var bomb_speed: float = 175
@export var rocket_speed: float = 500
@export var jet_trail_offset: float = 400.0
@export var jet_y_offset: float = 0.0

@export var bomb_land_ratio: float = 0.75

@export var tornado_base_ratio: float = 0.9

@export var hit_range: float = 120.0

@export var bomb_damage: int = 2
@export var tornado_damage: int = 1
@export var bomber_max_health: int = 3
@export var rocket_damage: int = 1

const TREE_STAGES := [
	preload("res://Assets/Tree_DEAD.png"),
	preload("res://Assets/Tree-Breaking_4.png"),
	preload("res://Assets/Tree-Breaking_3.png"),
	preload("res://Assets/Tree-Breaking_2.png"),
	preload("res://Assets/Tree-Normal.png"),
]
const MAX_HEALTH := 8
var tree_health: int = MAX_HEALTH

var tornado_moving: bool = false
var tornado_hit: bool = false
var plane_moving: bool = false
var bomb_dropped: bool = false
var bomb_dropping: bool = false
var rocket_flying: bool = false
var bomber_health: int = 0
var screen_middle: Vector2
var plane_start_x: float
var tornado_start_x: float

@export var hitstop_time: float = 0.09
var in_hitstop: bool = false
var sil_bg: ColorRect
var sil_sprites: Array[CanvasItem] = []
var sil_hide: Array[CanvasItem] = []

var mic_player: AudioStreamPlayer
var mic_bus_idx: int = -1
var voice_unlocked: bool = false
var vol_fill: ColorRect
var vol_peak: float = 0.0

const HP_BAR_WIDTH := 360.0
var hp_fill: ColorRect

const BOMBER_BAR_WIDTH := 90.0
var bomber_hp_bg: ColorRect
var bomber_hp_fill: ColorRect

func _ready() -> void:
	Engine.time_scale = 1.0
	VoiceInput.power_triggered.connect(_on_voice_power)
	VoiceInput.recognition_failed.connect(_on_voice_mishap)
	VoiceInput.listening_stopped.connect(_restart_listen)
	tree_hitbox.area_entered.connect(_on_tree_hitbox_entered)
	screen_middle = get_viewport_rect().size / 2
	plane_start_x = plane.position.x
	tornado_start_x = tornado.position.x

	tree.position = Vector2(screen_middle.x, get_viewport_rect().size.y * bomb_land_ratio)
	update_tree()
	bomb.visible = false
	tornado.visible = false
	jet.visible = false
	rocket.visible = false
	sil_sprites = [tornado, plane, bomb, tree, jet, rocket]
	sil_hide = [background, foreground]
	_setup_juice_ui()
	_setup_mic()
	timer.start()
	tornado.play()

func _process(delta: float) -> void:
	_update_volume_meter(delta)
	_update_bomber_hp_bar()

	if tornado_moving:
		tornado.position.x += tornado_speed * delta
		if tornado.position.x > get_viewport_rect().size.x + 100:
			tornado_moving = false
			tornado.visible = false

	if plane_moving:
		plane.position.x -= plane_speed * delta
		jet.visible = true
		jet.position = plane.position + Vector2(jet_trail_offset, jet_y_offset)
		if not bomb_dropped and plane.position.x <= screen_middle.x:
			drop_bomb()
		if plane.position.x < -100:
			plane_moving = false
			plane.visible = false
			jet.visible = false

	if rocket_flying:
		rocket.position.x -= rocket_speed * delta
		if rocket.position.x <= plane.position.x:
			hit_bomber()
		elif rocket.position.x < -100:
			rocket_flying = false
			rocket.visible = false

	if bomb_dropping:
		bomb.position.y += bomb_speed * delta
		var land_y := get_viewport_rect().size.y * bomb_land_ratio
		if bomb.position.y >= land_y:
			bomb.position.y = land_y
			bomb_dropping = false
			bomb.visible = false

func drop_bomb() -> void:
	bomb_dropped = true

	bomb.global_position = plane.global_position + Vector2(0, plane.get_rect().size.y * plane.scale.y * 0.5)
	bomb.visible = true
	bomb_dropping = true

func _input(event: InputEvent) -> void:
	var key_press: bool = event is InputEventKey and event.pressed
	var mouse_press: bool = event is InputEventMouseButton and event.pressed
	if (key_press or mouse_press) and not voice_unlocked:
		voice_unlocked = true
		VoiceInput.start_listening()
		print("[GAME] Voice unlocked - always listening now.")
	if key_press and event.keycode == KEY_W:
		fire_rocket()

func _restart_listen() -> void:
	if not voice_unlocked:
		return
	await get_tree().create_timer(0.2).timeout
	VoiceInput.start_listening()

func _on_voice_power(power_key: String) -> void:
	match power_key:
		"W":
			fire_rocket()
		"E":
			pass
		"Q":
			pass
		"R":
			pass


func fire_rocket() -> void:
	if not plane_moving or rocket_flying:
		return
	rocket.position = jet.position
	rocket.visible = true
	rocket_flying = true

func hit_bomber() -> void:
	rocket_flying = false
	rocket.visible = false
	bomber_health -= rocket_damage
	hit_stop()
	if bomber_health <= 0:
		shoot_down_bomber()
	else:
		print("[GAME] Bomber hit! health: %d" % bomber_health)

func shoot_down_bomber() -> void:
	plane_moving = false
	plane.visible = false
	jet.visible = false
	bomb_dropping = false
	bomb.visible = false
	print("[GAME] Bomber shot down!")

func damage_tree(amount: int = 1) -> void:
	if tree_health <= 0:
		return
	tree_health -= amount
	tree_health = maxi(tree_health, 0)
	update_tree()
	hit_stop()
	if tree_health <= 0:
		print("[GAME] The tree has died.")

func update_tree() -> void:
	tree.texture = TREE_STAGES[ceili(tree_health / 2.0)]
	update_health_bar()

func update_health_bar() -> void:
	if hp_fill == null:
		return
	var frac := clampf(float(tree_health) / float(MAX_HEALTH), 0.0, 1.0)
	hp_fill.size.x = HP_BAR_WIDTH * frac
	hp_fill.color = Color(1.0, 0.3, 0.3).lerp(Color(0.3, 1.0, 0.4), frac)

func _update_bomber_hp_bar() -> void:
	if bomber_hp_fill == null:
		return
	var show := plane_moving and plane.visible
	bomber_hp_bg.visible = show
	bomber_hp_fill.visible = show
	if not show:
		return
	var top_left := plane.position + Vector2(-BOMBER_BAR_WIDTH * 0.5, 55)
	bomber_hp_bg.position = top_left + Vector2(-2, -2)
	bomber_hp_fill.position = top_left
	var frac := clampf(float(bomber_health) / float(bomber_max_health), 0.0, 1.0)
	bomber_hp_fill.size.x = BOMBER_BAR_WIDTH * frac

func _on_tree_hitbox_entered(area: Area2D) -> void:
	var src := area.get_parent()
	if src == bomb and bomb_dropping:
		bomb_dropping = false
		bomb.visible = false
		damage_tree(bomb_damage)
	elif src == tornado and tornado_moving and not tornado_hit:
		tornado_hit = true
		damage_tree(tornado_damage)

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
	bomber_health = bomber_max_health

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


func hit_stop(duration: float = -1.0) -> void:
	if in_hitstop:
		return
	if duration < 0.0:
		duration = hitstop_time
	in_hitstop = true
	_set_silhouette(true)
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	in_hitstop = false
	_set_silhouette(false)


func _set_silhouette(on: bool) -> void:
	if sil_bg:
		sil_bg.visible = on
	for s in sil_sprites:
		if s:
			s.modulate = Color.BLACK if on else Color.WHITE
	for h in sil_hide:
		if h:
			h.visible = not on


func _setup_juice_ui() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)

	sil_bg = ColorRect.new()
	sil_bg.color = Color.WHITE
	sil_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sil_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sil_bg.visible = false
	bg_layer.add_child(sil_bg)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var vol_bg := ColorRect.new()
	vol_bg.color = Color(0, 0, 0, 0.5)
	vol_bg.size = Vector2(220, 26)
	vol_bg.position = Vector2(20, get_viewport_rect().size.y - 46)
	layer.add_child(vol_bg)

	vol_fill = ColorRect.new()
	vol_fill.color = Color(0.3, 1.0, 0.4)
	vol_fill.size = Vector2(0, 22)
	vol_fill.position = vol_bg.position + Vector2(2, 2)
	layer.add_child(vol_fill)

	var vol_label := Label.new()
	vol_label.text = "MIC"
	vol_label.position = vol_bg.position + Vector2(0, -22)
	vol_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(vol_label)

	var hp_x := (get_viewport_rect().size.x - HP_BAR_WIDTH) * 0.5
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.size = Vector2(HP_BAR_WIDTH + 8, 34)
	hp_bg.position = Vector2(hp_x - 4, 20)
	layer.add_child(hp_bg)

	hp_fill = ColorRect.new()
	hp_fill.size = Vector2(HP_BAR_WIDTH, 26)
	hp_fill.position = Vector2(hp_x, 24)
	layer.add_child(hp_fill)

	var hp_label := Label.new()
	hp_label.text = "TREE"
	hp_label.position = Vector2(hp_x, -2)
	hp_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(hp_label)

	update_health_bar()

	bomber_hp_bg = ColorRect.new()
	bomber_hp_bg.color = Color(0, 0, 0, 0.5)
	bomber_hp_bg.size = Vector2(BOMBER_BAR_WIDTH + 4, 14)
	bomber_hp_bg.visible = false
	layer.add_child(bomber_hp_bg)

	bomber_hp_fill = ColorRect.new()
	bomber_hp_fill.color = Color(1.0, 0.4, 0.3)
	bomber_hp_fill.size = Vector2(BOMBER_BAR_WIDTH, 10)
	bomber_hp_fill.visible = false
	layer.add_child(bomber_hp_fill)


func _setup_mic() -> void:
	AudioServer.add_bus()
	mic_bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(mic_bus_idx, "MicMeter")
	AudioServer.set_bus_mute(mic_bus_idx, true)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "MicMeter"
	add_child(mic_player)
	mic_player.play()


func _update_volume_meter(delta: float) -> void:
	if vol_fill == null:
		return
	var level := 0.0
	if mic_bus_idx >= 0:
		var db := AudioServer.get_bus_peak_volume_left_db(mic_bus_idx, 0)
		level = clampf(inverse_lerp(-60.0, 0.0, db), 0.0, 1.0)
	vol_peak = lerpf(vol_peak, level, clampf(delta * 15.0, 0.0, 1.0))
	vol_fill.size.x = 216.0 * vol_peak
	vol_fill.color = Color(0.3, 1.0, 0.4).lerp(Color(1.0, 0.3, 0.3), vol_peak)


func _on_voice_mishap(reason: String) -> void:
	if reason == "no_match":
		print("[GAME] voice mishap detected: %s" % reason)
