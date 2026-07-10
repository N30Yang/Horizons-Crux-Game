# =============================================================================
# VoiceInputManager.gd
# Voice-activated power system for "The Last One" (Godot 4.x, HTML5 export)
# =============================================================================
#
# SETUP (hackathon-fast):
#   1. Add this script to an autoload/singleton node named "VoiceInput"
#      (Project > Project Settings > Autoload). Or drop as a Node in your scene.
#   2. Place voice_config.json next to your project (res://voice_config.json)
#      or in user:// . Path is configurable via CONFIG_PATH below.
#   3. Export for Web. Copy voice_bridge.html content into your HTML shell,
#      OR load it as an iframe (see voice_bridge.html header for both options).
#   4. Connect the signals you care about:
#          VoiceInput.power_triggered.connect(_on_power)
#      then call VoiceInput.start_listening() (e.g. on a keypress).
#
# BROWSER ONLY: Web Speech API exists only in HTML5 exports (Chrome/Edge best).
# In the editor / native builds, voice is disabled but the DEBUG keyboard panel
# (Shift+V) and Q/W/E/R fallback still work, so you can test power logic.
#
# =============================================================================

extends Node

# --- Signals -----------------------------------------------------------------
signal power_triggered(power_key: String)   # "Q" / "W" / "E" / "R"
signal listening_started()
signal listening_stopped()
signal text_recognized(text: String)
signal recognition_failed(reason: String)

# --- Config ------------------------------------------------------------------
const CONFIG_PATH := "res://voice_config.json"
const SPEECH_TIMEOUT_MS := 10000  # overwritten by config if present

var confidence_threshold: float = 0.70   # 0.0 - 1.0
var fuzzy_max_distance: int = 2

# power_key -> { "name": String, "keywords": Array[String] }
var _powers: Dictionary = {}

# --- JS bridge state ---------------------------------------------------------
var _js_available: bool = false
var _js_callback_ref = null        # keep JS callback alive (GC guard)
var _is_listening: bool = false
var _timeout_timer: Timer = null

# --- Direct keyboard fallback (Q/W/E/R without voice) ------------------------
const FALLBACK_KEYS := {
	KEY_Q: "Q",
	KEY_W: "W",
	KEY_E: "E",
	KEY_R: "R",
}

# --- Debug typed-input panel -------------------------------------------------
var _debug_panel: Control = null
var _debug_edit: LineEdit = null


# =============================================================================
# Lifecycle
# =============================================================================
func _ready() -> void:
	_load_config()
	_setup_timeout_timer()
	_setup_js_bridge()
	set_process_input(true)
	print("[VOICE] VoiceInputManager ready. JS bridge: %s | threshold: %d%%"
		% ["yes" if _js_available else "no (keyboard only)", int(confidence_threshold * 100)])


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("[VOICE] Config not found at %s, using built-in defaults." % CONFIG_PATH)
		_load_default_powers()
		return

	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[VOICE] Config parse failed, using defaults.")
		_load_default_powers()
		return

	if parsed.has("confidence_threshold"):
		confidence_threshold = float(parsed["confidence_threshold"])
	if parsed.has("fuzzy_max_distance"):
		fuzzy_max_distance = int(parsed["fuzzy_max_distance"])

	_powers.clear()
	var pw = parsed.get("powers", {})
	for key in pw.keys():
		var entry = pw[key]
		var kws: Array = []
		for k in entry.get("keywords", []):
			kws.append(String(k).to_lower())
		_powers[String(key)] = {
			"name": entry.get("name", key),
			"keywords": kws,
		}
	print("[VOICE] Loaded %d powers from config." % _powers.size())


func _load_default_powers() -> void:
	_powers = {
		"W": {"name": "Shapeshift", "keywords": ["shapeshift", "dragon", "transform", "morph"]},
		"E": {"name": "Flight", "keywords": ["flight", "fly", "ascend", "rise", "up"]},
		"Q": {"name": "4th Wall", "keywords": ["wall", "break", "glitch", "reality"]},
		"R": {"name": "Consequences", "keywords": ["storm", "passes", "freeze", "time", "clear", "plummet", "fall"]},
	}


func _setup_timeout_timer() -> void:
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = float(SPEECH_TIMEOUT_MS) / 1000.0
	_timeout_timer.timeout.connect(_on_speech_timeout)
	add_child(_timeout_timer)


# =============================================================================
# JavaScript bridge (Web Speech API lives in voice_bridge.html / JS)
# =============================================================================
func _setup_js_bridge() -> void:
	if not Engine.has_singleton("JavaScriptBridge") and not _has_js():
		_js_available = false
		return
	_js_available = true

	# JS pushes results back by calling window.godotVoiceResult(jsonString).
	# We register a Godot-side callback and hand it to the page.
	_js_callback_ref = JavaScriptBridge.create_callback(_on_js_result)
	var window = JavaScriptBridge.get_interface("window")
	if window != null:
		window.godotVoiceCallback = _js_callback_ref
		# Tell the bridge we're wired up. bridge polls for this if it loads first.
		JavaScriptBridge.eval("if (window.godotVoiceReady) window.godotVoiceReady();", true)


func _has_js() -> bool:
	# JavaScriptBridge only exists on the Web platform.
	return OS.has_feature("web")


# Called from JS: godotVoiceCallback([ jsonString ])
func _on_js_result(args: Array) -> void:
	if args.is_empty():
		return
	var payload = JSON.parse_string(String(args[0]))
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var kind = payload.get("type", "")
	match kind:
		"result":
			_handle_recognized_text(String(payload.get("text", "")), float(payload.get("confidence", 1.0)))
		"error":
			_fail(String(payload.get("reason", "unknown")))
		"nomatch":
			_fail("no_match")
		"end":
			_stop_internal()
		_:
			pass


# =============================================================================
# Public API
# =============================================================================
func start_listening() -> void:
	if _is_listening:
		return
	_is_listening = true
	emit_signal("listening_started")
	print("[VOICE] Listening started.")

	if _js_available:
		JavaScriptBridge.eval("if (window.startVoiceRecognition) window.startVoiceRecognition();", true)
		_timeout_timer.start()
	else:
		# No browser speech: rely on keyboard. Still emit started so UI pulses.
		push_warning("[VOICE] No Web Speech API. Use Shift+V debug panel or Q/W/E/R keys.")


func stop_listening() -> void:
	if not _is_listening:
		return
	if _js_available:
		JavaScriptBridge.eval("if (window.stopVoiceRecognition) window.stopVoiceRecognition();", true)
	_stop_internal()


func set_confidence_threshold(value: float) -> void:
	confidence_threshold = clampf(value, 0.0, 1.0)
	print("[VOICE] Confidence threshold set to %d%%." % int(confidence_threshold * 100))


func _stop_internal() -> void:
	if not _is_listening:
		return
	_is_listening = false
	_timeout_timer.stop()
	emit_signal("listening_stopped")
	print("[VOICE] Listening stopped.")


func _on_speech_timeout() -> void:
	if not _is_listening:
		return
	if _js_available:
		JavaScriptBridge.eval("if (window.stopVoiceRecognition) window.stopVoiceRecognition();", true)
	_fail("timeout")
	_stop_internal()


func _fail(reason: String) -> void:
	emit_signal("recognition_failed", reason)
	var msg := reason
	match reason:
		"timeout": msg = "No speech detected (10s timeout)."
		"not-allowed", "permission": msg = "Microphone denied. Use keyboard (Q/W/E/R)."
		"unsupported": msg = "Browser has no Web Speech API. Use keyboard."
		"no_match": msg = "Heard you, but no power matched."
	push_warning("[VOICE] Recognition failed: %s" % msg)


# =============================================================================
# Recognition -> fuzzy match -> power
# =============================================================================
func _handle_recognized_text(text: String, speech_conf: float) -> void:
	_timeout_timer.stop()
	text = text.strip_edges().to_lower()
	if text.is_empty():
		_fail("no_match")
		return

	emit_signal("text_recognized", text)

	var result := match_text(text)
	# Blend fuzzy match confidence with browser speech confidence (if given).
	var blended: float = result["confidence"]
	if speech_conf > 0.0 and speech_conf < 1.0:
		blended = (result["confidence"] * 0.7) + (speech_conf * 0.3)

	if result["power"] != "" and blended >= confidence_threshold:
		var pct := int(round(blended * 100.0))
		print("[VOICE] Recognized: \"%s\" | Matched: \"%s\" @ %d%% | Power: %s"
			% [text, result["keyword"], pct, result["power"]])
		emit_signal("power_triggered", result["power"])
	else:
		var pct := int(round(blended * 100.0))
		print("[VOICE] Recognized: \"%s\" | Best: \"%s\" @ %d%% | below threshold, no trigger."
			% [text, result.get("keyword", "-"), pct])
		_fail("no_match")


# Public so debug panel / tests can call it directly.
# Returns { "power": String, "keyword": String, "confidence": float(0-1) }
func match_text(text: String) -> Dictionary:
	text = text.strip_edges().to_lower()
	var words := text.split(" ", false)

	var best := {"power": "", "keyword": "", "confidence": 0.0}

	for power_key in _powers.keys():
		for keyword in _powers[power_key]["keywords"]:
			# Check each spoken word AND the whole phrase against the keyword.
			var candidates: Array = words.duplicate()
			candidates.append(text)
			for cand in candidates:
				var conf := _fuzzy_confidence(String(cand), String(keyword))
				if conf > best["confidence"]:
					best = {"power": power_key, "keyword": keyword, "confidence": conf}

	return best


# Confidence 0-1 based on Levenshtein distance vs keyword length.
# distance 0 -> 1.0 ; distance == len -> 0.0 ; > fuzzy_max_distance -> 0.0
func _fuzzy_confidence(candidate: String, keyword: String) -> float:
	if candidate == keyword:
		return 1.0
	var dist := _levenshtein(candidate, keyword)
	if dist > fuzzy_max_distance:
		return 0.0
	var max_len: int = maxi(candidate.length(), keyword.length())
	if max_len == 0:
		return 0.0
	return clampf(1.0 - (float(dist) / float(max_len)), 0.0, 1.0)


# Classic iterative Levenshtein distance (two-row DP).
func _levenshtein(a: String, b: String) -> int:
	var la := a.length()
	var lb := b.length()
	if la == 0:
		return lb
	if lb == 0:
		return la

	var prev: Array = []
	prev.resize(lb + 1)
	for j in range(lb + 1):
		prev[j] = j

	var curr: Array = []
	curr.resize(lb + 1)

	for i in range(1, la + 1):
		curr[0] = i
		var ca := a.unicode_at(i - 1)
		for j in range(1, lb + 1):
			var cost := 0 if ca == b.unicode_at(j - 1) else 1
			curr[j] = mini(mini(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
		# swap rows
		for j in range(lb + 1):
			prev[j] = curr[j]

	return prev[lb]


# =============================================================================
# Input: fallback keys + debug panel toggle
# =============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Shift+V -> toggle debug typed-input panel.
		if event.keycode == KEY_V and event.shift_pressed:
			_toggle_debug_panel()
			get_viewport().set_input_as_handled()
			return

		# Direct Q/W/E/R fallback (only when NOT typing in debug panel).
		if _debug_panel == null or not _debug_panel.visible:
			if FALLBACK_KEYS.has(event.keycode):
				var pk: String = FALLBACK_KEYS[event.keycode]
				print("[VOICE] Keyboard fallback -> Power: %s" % pk)
				emit_signal("power_triggered", pk)


# =============================================================================
# Debug typed-input panel (Shift+V). Type phrase, Enter -> treat as speech.
# =============================================================================
func _toggle_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = not _debug_panel.visible
		if _debug_panel.visible:
			_debug_edit.grab_focus()
		return
	_build_debug_panel()


func _build_debug_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_debug_panel = PanelContainer.new()
	_debug_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_debug_panel.position = Vector2(0, 20)
	layer.add_child(_debug_panel)

	var vbox := VBoxContainer.new()
	_debug_panel.add_child(vbox)

	var label := Label.new()
	label.text = "[DEBUG VOICE]  type phrase, Enter to fire. Shift+V to close."
	vbox.add_child(label)

	_debug_edit = LineEdit.new()
	_debug_edit.custom_minimum_size = Vector2(360, 0)
	_debug_edit.placeholder_text = "e.g. dragn"
	_debug_edit.text_submitted.connect(_on_debug_submitted)
	vbox.add_child(_debug_edit)

	_debug_edit.grab_focus()


func _on_debug_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	print("[VOICE] (debug) simulating speech: \"%s\"" % text)
	_handle_recognized_text(text, 1.0)
	_debug_edit.clear()
