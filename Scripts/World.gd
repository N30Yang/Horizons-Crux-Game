extends Node2D
# == sprites and shi
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
@onready var runner: AnimatedSprite2D = $Runner

# speed amd health amd damage 
@export var tornado_speed: float = 175
@export var plane_speed: float = 150
@export var bomb_speed: float = 175
@export var rocket_speed: float = 500
@export var jet_trail_offset: float = 400.0
@export var jet_y_offset: float = 0.0

@export var bomb_land_ratio: float = 0.75

@export var tornado_base_ratio: float = 0.9

@export var bomb_damage: int = 2
@export var tornado_damage: int = 1
@export var runner_speed: float = 220.0
@export var runner_damage: int = 2
@export var bomber_max_health: int = 2
@export var rocket_damage: float = 1.0

# Volume -> damage multiplier. Louder = more damage.
@export var vol_damage_min: float = 0.75  # quiet / silence
@export var vol_damage_max: float = 3.0 # max volume
@export var web_mic_gain: float = 5.0    # scales JS RMS (0..1) to bar/damage

const TREE_STAGES := [
	preload("res://Assets/NewTreeFInal10.png"),
	preload("res://Assets/NewTreeFInal9.png"),
	preload("res://Assets/NewTreeFinal8.png"),
	preload("res://Assets/NewTreeFinal7.png"),   # diffeent phases of the tree
	preload("res://Assets/NewTreeFinal6.png"),
	preload("res://Assets/NewTreeFinal5.png"),
	preload("res://Assets/NewTreeFinal4.png"),
	preload("res://Assets/NewTreeFinal3.png"),  
	preload("res://Assets/NewTreeFinal2.png"),
	preload("res://Assets/NewTreeFinal.png"),
	preload("res://Assets/NewTreeFinal.png")
	
]
const MAX_HEALTH := 10   # change for health of tree
var tree_health: int = MAX_HEALTH  

signal shapeshift(animal)

var tornado_moving: bool = false
var tornado_hit: bool = false
var tornado_deflected: bool = false
var tornado_erasing: bool = false  # frozen mid fourth-wall erase
var tornado_dir: float = 1.0  # +1 travels right, -1 travels left

var erase_active: bool = false  # only ONE pencil+eraser can exist at a time
const ERASE_COOLDOWN_MS := 1000  # min gap between finishing one erase and starting the next
var erase_ready_at: int = 0      # Time.get_ticks_msec() the next erase is allowed
# Burning person: runs in from a side, torches the tree on contact.
var runner_moving: bool = false
var runner_hit: bool = false
var _runner_burn_tween: Tween = null  # burn/flash tween; killed if runner relaunches
var runner_erasing: bool = false  # mid fourth-wall erase; block relaunch til done
var runner_dir: float = 1.0
var plane_moving: bool = false
var plane_frozen: bool = false  # held still during the fourth-wall attack
var plane_dir: float = -1.0   # +1 travels right, -1 travels left
var bomb_dropped: bool = false
var bomb_dropping: bool = false
var rockets: Array = []  # each: { "node": Sprite2D, "dmg": float }
var bomber_health: float = 0.0
var screen_middle: Vector2

@export var hitstop_time: float = 0.09
var in_hitstop: bool = false
var sil_bg: ColorRect                        # impact frames
var sil_sprites: Array[CanvasItem] = []
var sil_hide: Array[CanvasItem] = []

var mic_player: AudioStreamPlayer
var mic_bus_idx: int = -1
var voice_unlocked: bool = false    # vars for mic
var vol_fill: ColorRect
var vol_peak: float = 0.0

const HP_BAR_WIDTH := 360.0
var hp_fill: ColorRect         # hp bar vars 

const BOMBER_BAR_WIDTH := 90.0
var bomber_hp_bg: ColorRect   # hp bar vars
var bomber_hp_fill: ColorRect

var plane_hurtbox: Area2D  # bomber's hurtbox; rockets detect it via Area2D overlap

# fourth-wall power art (pencil + eraser). scale/offset are tweakable since the
# source pngs have big transparent margins n weird pivots.
@export var fx_pencil_scale: float = 0.5
@export var fx_eraser_scale: float = 0.5
@export var fx_pencil_offset: Vector2 = Vector2.ZERO
@export var fx_eraser_offset: Vector2 = Vector2.ZERO
var _pencil_tex: Texture2D
var _eraser_tex: Texture2D

var bombertime:bool = true
var tornadotime:bool = false
var firemantime:bool = false
var win: bool =false
var loss:bool =false

# --- Wave director -----------------------------------------------------------
# TUTORIAL: one enemy at a time, gated on the player DEFEATING it (teaches each
# power). Then DIRECTOR: weighted 1-per-tick spawner with a cap + interval that
# ramp with survival time. Never spawns the same type twice in a row.
enum Phase { TUTORIAL, DIRECTOR }
var phase: int = Phase.TUTORIAL
var run_time: float = 0.0            # survival seconds since director started
var last_spawn_type: String = ""     # for no-repeat variety

const TUTORIAL_ORDER := ["plane", "tornado", "runner"]
const TUTORIAL_GAP := 1.2            # beat between taught rounds
const TUTORIAL_RETRY := 0.6          # beat before re-sending an un-defeated enemy

const RAMP_SECONDS := 90.0           # time to reach peak difficulty
const CAP_MIN := 1                   # max enemies alive, start
const CAP_MAX := 3                   # max enemies alive, peak
const INTERVAL_SLOW := 3.5           # seconds between spawns, start
const INTERVAL_FAST := 1.2           # seconds between spawns, peak
const HARDEST_DURATION := 10.0       # peak-phase window length (seconds)
var _hardest_done: bool = false      # peak event only fires once

func _ready() -> void:   # prep var
	Engine.time_scale = 1.0
	VoiceInput.power_triggered.connect(_on_voice_power)
	VoiceInput.recognition_failed.connect(_on_voice_mishap)
	VoiceInput.listening_stopped.connect(_restart_listen)
	tree_hitbox.area_entered.connect(_on_tree_hitbox_entered)
	_setup_plane_hurtbox()
	_pencil_tex = load("res://Assets/image-removebg-preview.png")
	_eraser_tex = load("res://Assets/image-removebg-preview(1).png")
	screen_middle = get_viewport_rect().size / 2

	update_tree()
	bomb.visible = false
	tornado.visible = false
	jet.visible = false
	rocket.visible = false
	sil_sprites = [tornado, plane, bomb, tree, jet, rocket]
	sil_hide = [background, foreground]
	_setup_juice_ui()
	_setup_mic()
	tornado.play()
	_run_intro()  # tutorial rounds, then hands off to the director

# the big loop, runs every frame. moves everything around n checks stuff
func _process(delta: float) -> void:
	_update_volume_meter(delta)
	_update_bomber_hp_bar()
	
	if Input.is_action_just_pressed("shapeshift"):
		print("yeah")
		shapeshift.emit("shapeshift")

	if tornado_moving and not tornado_erasing:
		tornado.position.y = 460
		tornado.position.x += tornado_speed * delta * tornado_dir
		if tornado.position.x > get_viewport_rect().size.x + 300 or tornado.position.x < -300:
			tornado_moving = false
			tornado.visible = false

	if plane_moving and not plane_frozen:
		plane.position.x += plane_speed * delta * plane_dir
		jet.visible = true
		# Jet trails BEHIND the plane (opposite travel dir).
		jet.position = plane.position + Vector2(-plane_dir * jet_trail_offset, jet_y_offset)
		var past_middle := (plane_dir < 0.0 and plane.position.x <= screen_middle.x) \
			or (plane_dir > 0.0 and plane.position.x >= screen_middle.x)
		if not bomb_dropped and past_middle:
			drop_bomb()
		if plane.position.x < -150 or plane.position.x > get_viewport_rect().size.x + 150:
			plane_moving = false
			plane.visible = false
			jet.visible = false

	var vw := get_viewport_rect().size.x
	for i in range(rockets.size() - 1, -1, -1):
		var r: Sprite2D = rockets[i]["node"]
		var rdir: float = rockets[i]["dir"]
		r.position.x += rocket_speed * delta * rdir
		# Hit detection is via the rocket's Area2D overlapping plane_hurtbox
		# (_on_rocket_area). Here just cull rockets that fly off-screen.
		if r.position.x < -150 or r.position.x > vw + 150:
			r.queue_free()
			rockets.remove_at(i)

	if bomb_dropping:
		bomb.position.y += bomb_speed * delta
		var land_y := get_viewport_rect().size.y * bomb_land_ratio
		if bomb.position.y >= land_y:
			bomb.position.y = land_y
			bomb_dropping = false
			bomb.visible = false

	if runner_moving and not runner_erasing:
		runner.position.x += runner_speed * delta * runner_dir
		# Damage now fires via Runner/Hurtbox overlapping Tree/Hitbox
		# (_on_tree_hitbox_entered). Just clean up if it somehow runs past.
		runner.position.y = 500
		if runner.position.x < -200 or runner.position.x > get_viewport_rect().size.x + 200:
			runner_moving = false
			runner.visible = false

# plane yeets the bomb straight down
func drop_bomb() -> void:
	bomb_dropped = true

	bomb.global_position = plane.global_position + Vector2(0, plane.get_rect().size.y * plane.scale.y * 0.5)
	bomb.visible = true
	bomb_dropping = true

# first tap/click wakes up the mic. W key shoots too (backup for no mic)
func _input(event: InputEvent) -> void:
	var key_press: bool = event is InputEventKey and event.pressed
	var mouse_press: bool = event is InputEventMouseButton and event.pressed
	if (key_press or mouse_press) and not voice_unlocked:
		voice_unlocked = true
		VoiceInput.start_listening()
		print("[GAME] Voice unlocked - always listening now.")
	if key_press and event.keycode == KEY_W:
		fire_rocket()

# mic kicks itself back on so its basically always listening
func _restart_listen() -> void:
	if not voice_unlocked:
		return
	await get_tree().create_timer(0.05).timeout
	VoiceInput.start_listening()

# voice heard a word -> do the matching power
func _on_voice_power(power_key: String) -> void:
	match power_key:
		"W":
			fire_rocket()
		"E":
			deflect_tornado()#technically erase but now superceded by shapeshift
		"Q":
			erase_power()


# No cooldown: every call spawns a new rocket. Rapid, clear speech = rapid fire.
func fire_rocket() -> void:
	if not plane_moving:
		return
	var mult := lerpf(vol_damage_min, vol_damage_max, clampf(vol_peak, 0.0, 1.0))
	var dmg := rocket_damage * mult
	var r: Sprite2D = rocket.duplicate()
	r.visible = true
	r.position = jet.position
	# Area2D hitbox so the rocket hits the bomber via collision, not position.
	var hb := Area2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 6)
	cs.shape = sh
	hb.add_child(cs)
	r.add_child(hb)
	hb.area_entered.connect(_on_rocket_area.bind(r))
	add_child(r)
	rockets.append({ "node": r, "dmg": dmg, "dir": plane_dir })
	print("[GAME] Rocket fired. vol %d%% -> dmg x%.2f = %.2f" % [int(vol_peak * 100.0), mult, dmg])


# Rocket's hitbox overlapped something. Only the bomber's hurtbox counts.
func _on_rocket_area(area: Area2D, rnode: Sprite2D) -> void:
	if area != plane_hurtbox or not plane_moving:
		return
	for i in range(rockets.size()):
		if rockets[i]["node"] == rnode:
			hit_bomber(rockets[i]["dmg"])
			rnode.queue_free()
			rockets.remove_at(i)
			return


# Grab the plane/drone's hurtbox Area2D so rockets can hit it.
# The scene provides one (Plane/Area2D holds the CollisionShape2D). Prefer that;
# fall back to a legacy "Hurtbox" node or wrap a bare CollisionShape2D.
func _setup_plane_hurtbox() -> void:
	# Existing Area2D from the scene (drone swap nests the shape under it).
	plane_hurtbox = plane.get_node_or_null("Hurtbox") as Area2D
	if plane_hurtbox == null:
		plane_hurtbox = plane.get_node_or_null("Area2D") as Area2D
	if plane_hurtbox != null:
		return
	# Legacy fallback: no Area2D in the scene, wrap a bare CollisionShape2D.
	plane_hurtbox = Area2D.new()
	plane_hurtbox.name = "Hurtbox"
	var old_cs := plane.get_node_or_null("CollisionShape2D")
	if old_cs != null:
		plane.remove_child(old_cs)
		plane_hurtbox.add_child(old_cs)
	plane.add_child(plane_hurtbox)


# Reverse an active tornado so it blows back off-screen without hitting the tree.
func deflect_tornado() -> void:
	if not tornado_moving or tornado_hit or tornado_deflected:
		return
	tornado_deflected = true
	tornado_dir = -tornado_dir  # reverse: send it back the way it came
	tornado.scale.x = absf(tornado.scale.x) * tornado_dir  # flip facing
	_shine_tornado()
	print("[GAME] Tornado deflected!")


# Bright flash + scale pop on the tornado when deflected.
func _shine_tornado() -> void:
	var base_scale := tornado.scale
	tornado.modulate = Color(6.0, 6.0, 6.0, 1.0)  # over-bright -> clamps white
	var tw := create_tween()
	tw.tween_property(tornado, "modulate", Color.WHITE, 0.45)
	var tw2 := create_tween()
	tw2.tween_property(tornado, "scale", base_scale * 1.18, 0.08)
	tw2.tween_property(tornado, "scale", base_scale, 0.22)

# rocket smacked the plane, chip its hp
func hit_bomber(dmg: float) -> void:
	bomber_health -= dmg
	hit_stop()
	if bomber_health <= 0:
		shoot_down_bomber()
	else:
		print("[GAME] Bomber hit! health: %.1f" % bomber_health)

# wipe every rocket currently flying
func _clear_rockets() -> void:
	for entry in rockets:
		entry["node"].queue_free()
	rockets.clear()

# plane's ded, hide it n clean up
func shoot_down_bomber() -> void:
	plane_moving = false
	plane.visible = false
	jet.visible = false
	bomb_dropping = false
	bomb.visible = false
	_clear_rockets()
	print("[GAME] Bomber shot down!")

# ow, tree takes a hit. dies at 0
func damage_tree(amount: int = 1) -> void:
	if phase == Phase.TUTORIAL:
		return  # tutorial is damage-free; enemies still resolve, just no tree HP loss
	if tree_health <= 0:
		return
	tree_health -= amount
	tree_health = maxi(tree_health, 0)
	update_tree()
	hit_stop()
	if tree_health <= 0:
		print("[GAME] The tree has died.")

# swap tree pic to match how beat up it is + refresh the bar
func update_tree() -> void:
	tree.texture = TREE_STAGES[ceili(tree_health)]
	update_health_bar()

# resize + recolor the tree hp bar (green = healthy, red = dying)
func update_health_bar() -> void:
	if hp_fill == null:
		return
	var frac := clampf(float(tree_health) / float(MAX_HEALTH), 0.0, 1.0)
	hp_fill.size.x = HP_BAR_WIDTH * frac
	hp_fill.color = Color(1.0, 0.3, 0.3).lerp(Color(0.3, 1.0, 0.4), frac)

# lil hp bar that floats over the plane while its alive
func _update_bomber_hp_bar() -> void:
	if bomber_hp_fill == null:
		return
	@warning_ignore("shadowed_variable_base_class")
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

# somethin touched the tree -> figure out what it was n deal dmg
func _on_tree_hitbox_entered(area: Area2D) -> void:
	var src := area.get_parent()
	if src == bomb and bomb_dropping:
		bomb_dropping = false
		bomb.visible = false
		damage_tree(bomb_damage)
	elif src == tornado and tornado_moving and not tornado_hit:
		tornado_hit = true
		damage_tree(tornado_damage)
	elif src == runner and runner_moving and not runner_hit:
		_burn_tree()

# --- Tutorial: teach each enemy one at a time, gated on defeating it ----------
func _run_intro() -> void:
	await get_tree().create_timer(1.0).timeout  # brief breather before round 1
	for kind in TUTORIAL_ORDER:
		if tree_health <= 0:
			return
		await _tutorial_round(kind)
		await get_tree().create_timer(TUTORIAL_GAP).timeout
	_start_director()

# Send one enemy; keep re-sending until the player actually DEFEATS it (an
# escape or a tree-hit doesn't count, so the power gets learned).
func _tutorial_round(kind: String) -> void:
	while tree_health > 0:
		_spawn_kind(kind)
		while _kind_active(kind):
			await get_tree().process_frame
		if _kind_defeated(kind):
			return
		await get_tree().create_timer(TUTORIAL_RETRY).timeout

# --- Director: weighted 1-per-tick spawner with ramping cap + interval --------
func _start_director() -> void:
	phase = Phase.DIRECTOR
	run_time = 0.0
	timer.wait_time = INTERVAL_SLOW
	timer.start()

# Peak difficulty reached (90s). Runs a stub each second for 10s.
func _hardest_phase() -> void:
	var t := 0.0
	while t < HARDEST_DURATION and tree_health > 0:
		_hardest_tick()
		await get_tree().create_timer(1.0).timeout
		t += 1.0

# TODO: hardest-phase event. Fill in later.
func _hardest_tick() -> void:
	pass

func _on_timer_timeout() -> void:
	if phase != Phase.DIRECTOR:
		return
	if tree_health <= 0:
		timer.stop()
		return

	run_time += timer.wait_time
	var d := clampf(run_time / RAMP_SECONDS, 0.0, 1.0)  # 0 start -> 1 peak
	var cap := CAP_MIN + int(round(float(CAP_MAX - CAP_MIN) * d))

	# Peak reached (>= RAMP_SECONDS): fire the hardest-phase event once.
	if d >= 1.0 and not _hardest_done:
		_hardest_done = true
		_hardest_phase()

	if _alive_count() < cap:
		var kind := _pick_enemy()
		if kind != "":
			_spawn_kind(kind)
			last_spawn_type = kind

	# Spawns get closer together as difficulty ramps; small jitter avoids rhythm.
	timer.wait_time = maxf(0.5, lerpf(INTERVAL_SLOW, INTERVAL_FAST, d) + randf_range(-0.3, 0.3))

# Weighted (equal) pick among types that aren't alive and aren't the last one.
func _pick_enemy() -> String:
	var pool: Array = _spawnable_types(true)
	if pool.is_empty():
		pool = _spawnable_types(false)  # relax no-repeat if that's all that's left
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

# Types not currently on the field. When avoid_repeat, also drop the last spawn.
func _spawnable_types(avoid_repeat: bool) -> Array:
	var out: Array = []
	if not plane_moving and not (avoid_repeat and last_spawn_type == "plane"):
		out.append("plane")
	if not tornado_moving and not (avoid_repeat and last_spawn_type == "tornado"):
		out.append("tornado")
	if not runner_moving and not runner_erasing and not (avoid_repeat and last_spawn_type == "runner"):
		out.append("runner")
	return out

func _alive_count() -> int:
	return (1 if plane_moving else 0) + (1 if tornado_moving else 0) + (1 if runner_moving else 0)

func _spawn_kind(kind: String) -> void:
	match kind:
		"plane": launch_plane()
		"tornado": launch_tornado()
		"runner": launch_runner()

# Enemy still on the field (not yet resolved)?
func _kind_active(kind: String) -> bool:
	match kind:
		"plane": return plane_moving
		"tornado": return tornado_moving
		"runner": return runner_moving or runner_erasing
	return false

# Was it DEFEATED (vs escaping / hitting the tree)?
func _kind_defeated(kind: String) -> bool:
	match kind:
		"plane": return bomber_health <= 0.0   # shot down (else it flew off)
		"tornado": return not tornado_hit      # deflected or erased, didn't hit tree
		"runner": return not runner_hit        # erased, didn't burn tree
	return true



func launch_runner() -> void:
	# Kill any lingering burn/flash tween from a previous runner, or it clobbers
	# this fresh one (forces flashing + hides it -> invisible runner).
	if _runner_burn_tween != null and _runner_burn_tween.is_valid():
		_runner_burn_tween.kill()
	_runner_burn_tween = null
	var vw := get_viewport_rect().size.x
	var from_left := randf() < 0.5
	runner_dir = 1.0 if from_left else -1.0
	runner.position.x = -60.0 if from_left else vw + 60.0
	runner.position.y = get_viewport_rect().size.y * bomb_land_ratio
	runner.modulate = Color.WHITE
	runner.visible = true
	# Separate frames per direction: 0-1-2 run right, 4-5-6 run left.
	runner.play("run_right" if runner_dir > 0.0 else "run_left")
	runner_moving = true
	runner_hit = false

# FOURTH WALL power ("erase"/"destroy"/"obliterate"). erase the runner if hes
# around, otherwise scribble the bomber n take half its hp.
func erase_power() -> void:
	# only one pencil+eraser at a time, or it gets messy/broken
	if erase_active:
		return
	# 1s cooldown between erases
	if Time.get_ticks_msec() < erase_ready_at:
		return
	# priority: runner -> tornado -> bomber. freeze the target so the timer
	# cant relaunch/clobber it, hide it (or dmg the plane) when the fx ends.
	if runner_moving and not runner_hit:
		erase_active = true
		runner_erasing = true
		runner_hit = true  # block tree-collision dmg while frozen
		_fourth_wall_fx(runner, true, 31, 2.3, 1.4)
		print("[GAME] Fourth wall: runner erased!")
	elif tornado_moving and not tornado_hit:
		erase_active = true
		tornado_erasing = true
		tornado_hit = true
		_fourth_wall_fx(tornado, true, 31, 2.3, 1.4)
		print("[GAME] Fourth wall: tornado erased!")
	#elif plane_moving:
		#erase_active = true
		#plane_frozen = true  # freeze the bomber for the whole ~5s attack
		#_fourth_wall_fx(plane, false, 75, 3.4, 1.6)
		#print("[GAME] Fourth wall: bomber scribbled for half hp!")
	else:
		print("[GAME] Fourth wall: nothin to erase.")

# pencil scribbles over the target drawing the line as it goes, then an eraser
# spirals in n everything (mark + target) fades out. no white square.
# erase_target = true fully rubs the thing out (runner); false = just fx (plane).
func _fourth_wall_fx(target: Node2D, erase_target: bool, steps: int, draw_time: float, erase_time: float) -> void:
	var pos: Vector2 = target.global_position
	var box := Vector2(150.0, 190.0)  # rough cover area, tweak to taste

	# random segments splattered all over the target = messy scribble
	var pts: Array[Vector2] = []
	for i in steps:
		var x := pos.x + randf_range(-box.x * 0.5, box.x * 0.5)
		var y := pos.y + randf_range(-box.y * 0.5, box.y * 0.5)
		pts.append(Vector2(x, y))

	# the pencil line, drawn on progressively
	var scrib := Line2D.new()
	scrib.width = 10.0
	scrib.default_color = Color(0.08, 0.08, 0.1)
	scrib.z_index = 60
	add_child(scrib)

	var pencil := Sprite2D.new()
	pencil.texture = _pencil_tex
	pencil.scale = Vector2(fx_pencil_scale, fx_pencil_scale)
	# put the pencil TIP (bottom-left of the art) at the node origin so it sits
	# on the point being drawn. bbox tip ~ (65,363), img center (250,250).
	pencil.offset = Vector2(185, -113)
	pencil.z_index = 62
	add_child(pencil)
	pencil.global_position = pts[0] + fx_pencil_offset

	var eraser := Sprite2D.new()
	eraser.texture = _eraser_tex
	eraser.scale = Vector2(fx_eraser_scale, fx_eraser_scale)
	# center the eraser art on its origin (art bbox center ~ (114,296))
	eraser.offset = Vector2(136, -46)
	eraser.z_index = 63
	eraser.visible = false
	add_child(eraser)

	var tw := create_tween()
	# 1) pencil follows the squiggle, line grows to match its tip
	tw.tween_method(_pencil_draw.bind(scrib, pencil, pts), 0.0, 1.0, draw_time)
	# 2) hand off to the eraser
	tw.tween_callback(func() -> void:
		pencil.queue_free()
		eraser.visible = true
		eraser.global_position = pos + fx_eraser_offset)
	# 3) eraser spirals inward while the mark (+ target) fade to nothing
	tw.tween_method(_eraser_spiral.bind(eraser, pos, box), 0.0, 1.0, erase_time)
	tw.parallel().tween_property(scrib, "modulate:a", 0.0, erase_time)
	if erase_target:
		tw.parallel().tween_property(target, "modulate:a", 0.0, erase_time)
	tw.tween_callback(func() -> void:
		scrib.queue_free()
		eraser.queue_free()
		if target == runner:
			runner.visible = false
			runner.modulate = Color.WHITE
			runner_moving = false
			runner_hit = false
			runner_erasing = false
		elif target == tornado:
			tornado.visible = false
			tornado.modulate = Color.WHITE
			tornado_moving = false
			tornado_hit = false
			tornado_erasing = false
		elif target == plane:
			# bomber attack over: unfreeze n land the half-hp hit
			plane_frozen = false
			hit_bomber(bomber_max_health * 0.5)
		erase_active = false
		erase_ready_at = Time.get_ticks_msec() + ERASE_COOLDOWN_MS)

# reveal the squiggle up to the pencil's current spot
func _pencil_draw(t: float, scrib: Line2D, pencil: Sprite2D, pts: Array) -> void:
	var n := pts.size()
	var k := clampi(int(ceil(t * n)), 1, n)
	scrib.points = PackedVector2Array(pts.slice(0, k))
	pencil.global_position = pts[k - 1] + fx_pencil_offset

# eraser loops inward toward the center as it rubs
func _eraser_spiral(t: float, eraser: Sprite2D, center: Vector2, box: Vector2) -> void:
	var angle := t * TAU * 3.0
	var radius := lerpf(box.x * 0.55, 0.0, t)
	eraser.global_position = center + Vector2(cos(angle), sin(angle)) * radius + fx_eraser_offset

# Reached the tree: flash red/white, torch it, then vanish.
func _burn_tree() -> void:
	runner_hit = true
	runner_moving = false
	damage_tree(runner_damage)
	# Frame 3 = blowing up, held (no loop).
	runner.play("boom")

	var tw := create_tween()
	_runner_burn_tween = tw
	for n in 10:
		tw.tween_property(runner, "modulate", Color.RED, 0.06)
		tw.tween_property(runner, "modulate", Color.WHITE, 0.06)
	tw.tween_callback(func(): runner.visible = false)

# send a bomber in from a random side
func launch_plane() -> void:
	var vw := get_viewport_rect().size.x
	var from_left := randf() < 0.5
	plane_dir = 1.0 if from_left else -1.0
	plane.position.x = -100.0 if from_left else vw + 100.0
	# Face travel direction (sprite art faces left at +scale.x).
	plane.scale.x = absf(plane.scale.x) * -plane_dir
	jet.scale.x = absf(jet.scale.x) * -plane_dir
	plane.visible = true
	bomb.visible = false
	bomb_dropped = false
	bomb_dropping = false
	plane_moving = true
	bomber_health = bomber_max_health

# spin a tornado in from a random side, sit it on the ground
func launch_tornado() -> void:
	var vw := get_viewport_rect().size.x
	var from_left := randf() < 0.5
	tornado_dir = 1.0 if from_left else -1.0
	tornado.position.x = -200.0 if from_left else vw + 200.0
	var base_y := get_viewport_rect().size.y * tornado_base_ratio
	var tex := tornado.sprite_frames.get_frame_texture(tornado.animation, tornado.frame)
	var half_h := tex.get_height() * tornado.scale.y * 0.5
	tornado.position.y = base_y - half_h
	tornado.scale.x = absf(tornado.scale.x) * tornado_dir
	tornado.visible = true
	tornado.play()
	tornado_moving = true
	tornado_hit = false
	tornado_deflected = false


# freeze time for a split sec on impact, makes hits feel chunky
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


# black-out all the sprites for that impact-frame look
func _set_silhouette(on: bool) -> void:
	if sil_bg:
		sil_bg.visible = on
	for s in sil_sprites:
		if s:
			s.modulate = Color.BLACK if on else Color.WHITE
	for h in sil_hide:
		if h:
			h.visible = not on


# builds all the UI (mic meter, tree hp, bomber hp) in code
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
	# On web the JS bridge (Vosk / analyser) provides the mic level, and Godot's
	# AudioStreamMicrophone can't play in the single-threaded web build. Skip it.
	if OS.has_feature("web"):
		return
	AudioServer.add_bus()
	mic_bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(mic_bus_idx, "MicMeter")
	AudioServer.set_bus_mute(mic_bus_idx, true)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "MicMeter"
	add_child(mic_player)
	mic_player.play()


# reads how loud u are n animates the mic bar (also feeds rocket dmg)
func _update_volume_meter(delta: float) -> void:
	if vol_fill == null:
		return
	var level := 0.0
	var web_level := VoiceInput.get_mic_level()  # -1 if not on web
	if web_level >= 0.0:
		level = clampf(web_level * web_mic_gain, 0.0, 1.0)
	elif mic_bus_idx >= 0:
		var db := AudioServer.get_bus_peak_volume_left_db(mic_bus_idx, 0)
		level = clampf(inverse_lerp(-60.0, 0.0, db), 0.0, 1.0)
	vol_peak = lerpf(vol_peak, level, clampf(delta * 15.0, 0.0, 1.0))
	vol_fill.size.x = 216.0 * vol_peak
	vol_fill.color = Color(0.3, 1.0, 0.4).lerp(Color(1.0, 0.3, 0.3), vol_peak)


# voice heard somethin but no power matched, just log it
func _on_voice_mishap(reason: String) -> void:
	if reason == "no_match":
		print("[GAME] voice mishap detected: %s" % reason)
