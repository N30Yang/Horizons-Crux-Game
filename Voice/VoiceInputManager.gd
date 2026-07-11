#   1. Add this script to an autoload/singleton node named "VoiceInput"
#      (Project > Project Settings > Autoload). Or drop as a Node in your scene.
#   2. Place voice_config.json next to your project (res://voice_config.json)
#      or in user:// . Path is configurable via CONFIG_PATH below.
#   3. Export for Web. The HTML shell must load vosk.js + vosk-bridge.js
#      (see GameApplications/); that offline Vosk engine does the recognition.
#   4. Connect the signals you care about:
#          VoiceInput.power_triggered.connect(_on_power)
#      then call VoiceInput.start_listening() (e.g. on a keypress).
#

extends Node

signal power_triggered(power_key: String)
signal listening_started
signal listening_stopped
signal recognition_failed(reason: String)
signal text_recognized(text: String)

# --- Config ------------------------------------------------------------------
const CONFIG_PATH := "res://Voice/voice_config.json"
const SPEECH_TIMEOUT_MS := 10000 # overwritten by config if present

var confidence_threshold: float = 0.55 # 0.0 - 1.0
var fuzzy_max_distance: int = 3

# power_key -> { "name": String, "keywords": Array[String] }
var _powers: Dictionary = {}

# --- JS bridge state ---------------------------------------------------------
var _js_available: bool = false
var _js_callback_ref = null # keep JS callback alive (GC guard)
var _is_listening: bool = false
var _timeout_timer: Timer = null

# --- Direct keyboard fallback (Q/W/E/R without voice) ------------------------
const FALLBACK_KEYS := {
	KEY_Q: "Q",
	KEY_W: "W",
	KEY_E: "E",
	KEY_R: "R",
}


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
		"W": {"name": "Shoot", "keywords": ["shoot", "shoots", "shot", "shots", "fire", "fired", "blast", "attack", "strike", "launch", "bang", "boom", "gun", "hit", "boot", "chute"]},
		"E": {"name": "Deflect", "keywords": ["deflect", "block", "shield", "guard", "defend", "protect", "parry", "repel", "push", "wall", "wind", "away", "back", "blow", "bounce"]},
		"Q": {"name": "Fourth Wall", "keywords": ["erase", "erases", "destroy", "destroys", "obliterate", "delete", "scribble", "kill", "remove"]},
		"MOVE_LEFT": {"name": "Move Left", "keywords": ["left", "west"]},
		"MOVE_RIGHT": {"name": "Move Right", "keywords": ["right", "east"]},
		"JUMP": {"name": "Jump", "keywords": ["jump", "hop", "leap"]},
		"STOP": {"name": "Stop", "keywords": ["stop", "halt", "stay"]},
		"BEAR": {"name": "Bear", "keywords": ["bear", "bare"]},
		"CAPYBARA": {"name": "Capybara", "keywords": ["capybara", "capy"]},
		"BLOBFISH": {"name": "Blobfish", "keywords": ["blobfish", "blob"]},
		"BIRD": {"name": "Bird", "keywords": ["bird", "birdie"]},
		"HUMAN": {"name": "Human", "keywords": ["human", "person"]},
		"SHAPESHIFT": {"name": "Shapeshift Random", "keywords": ["shapeshift", "shift", "transform", "morph", "change"]},
	}


func _setup_timeout_timer() -> void:
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = float(SPEECH_TIMEOUT_MS) / 1000.0
	_timeout_timer.timeout.connect(_on_speech_timeout)
	add_child(_timeout_timer)


# =============================================================================
# JavaScript bridge. Recognition itself lives in GameApplications/vosk-bridge.js
# (offline Vosk), loaded by the HTML shell. Here we only wire Godot's result
# callback into it: vosk-bridge.js pushes results to window.godotVoiceCallback
# and Godot calls window.startVoiceRecognition() to boot the mic + recognizer.
# =============================================================================
func _setup_js_bridge() -> void:
	if not Engine.has_singleton("JavaScriptBridge") and not _has_js():
		_js_available = false
		return
	_js_available = true

	_js_callback_ref = JavaScriptBridge.create_callback(_on_js_result)
	var window = JavaScriptBridge.get_interface("window")
	if window != null:
		window.godotVoiceCallback = _js_callback_ref
		JavaScriptBridge.eval("if (window.godotVoiceReady) window.godotVoiceReady();", true)



func _has_js() -> bool:
	# JavaScriptBridge only exists on the Web platform.
	return OS.has_feature("web")


# RMS mic level 0..1 from the JS AnalyserNode. Returns -1.0 when unavailable
# (non-web / no JS bridge) so callers can fall back to AudioServer.
func get_mic_level() -> float:
	if not _js_available:
		return -1.0
	var v = JavaScriptBridge.eval("(window.__voiceLevel || 0)", true)
	if v == null:
		return 0.0
	return float(v)


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
		# No JS bridge (native/editor): rely on keyboard. Still emit started so UI pulses.
		push_warning("[VOICE] No JS bridge (Vosk runs on web export only). Use Q/W/E/R keys.")


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
		"unsupported": msg = "Voice engine unavailable. Use keyboard."
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
		power_triggered.emit(result["power"])
	else:
		var pct := int(round(blended * 100.0))
		print("[VOICE] Recognized: \"%s\" | Best: \"%s\" @ %d%% | below threshold, no trigger."
			% [text, result.get("keyword", "-"), pct])
		_fail("no_match")


# Public so tests can call it directly.
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
	# Substring containment: "shooting"/"reshoot" ~ "shoot". Catches endings,
	# plurals, run-together words that Levenshtein alone rejects.
	if keyword.length() >= 3 and candidate.length() >= 3:
		if candidate.contains(keyword) or keyword.contains(candidate):
			return 0.92
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
# Input: Q/W/E/R keyboard fallback (no mic).
# =============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if FALLBACK_KEYS.has(event.keycode):
			var pk: String = FALLBACK_KEYS[event.keycode]
			print("[VOICE] Keyboard fallback -> Power: %s" % pk)
			power_triggered.emit(pk)
