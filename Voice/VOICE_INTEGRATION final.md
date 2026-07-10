## Files

Ship these (project root, `res://`):

| File | Purpose |
|------|---------|
| `VoiceInputManager.gd` | Core: mic control, fuzzy matching, emits power signals. Runs as an autoload. |
| `voice_config.json` | Keyword → power map + thresholds. Edit to tune keywords. |
| `voice_bridge.html` | Web Speech API glue. Merged into the Web export HTML shell. |


---

## Quick start (5 steps)

### 1. Add files
Copy `VoiceInputManager.gd`, `voice_config.json`, `voice_bridge.html` to project root.

### 2. Register autoload
add `VoiceInputManager.gd`, to autoload
name it **`VoiceInput`**, enable. 

### 3. Connect signals in your gameplay script
```gdscript
func _ready() -> void:
    VoiceInput.power_triggered.connect(_on_voice_power)

func _on_voice_power(power_key: String) -> void:
    match power_key:
        "W": shapeshift()      # replace with real power functions
        "E": flight()
        "Q": break_wall()
        "R": consequences()
```

### 4. Start listening
on game start
```gdscript
func _game_start(#whatever) :
	start_listening()
	# everything else

```
(Or call `start_listening()` on game start for always-listening.)

### 5. Export for Web + serve
USE WEB EXPORT, DOESN'T WORK IN EDITOR.

---

## Public API (`VoiceInput`)

### Signals
| Signal | Fires when |
|--------|-----------|
| `power_triggered(power_key: String)` | A word matched a power. `power_key` = `"Q"`/`"W"`/`"E"`/`"R"`. **This is the one you consume.** |
| `listening_started()` | Mic opened. Use for a "Listening…" UI. |
| `listening_stopped()` | Mic closed (finished, stopped, or timed out). |
| `text_recognized(text: String)` | Raw recognized text, before matching. Debug/UI. |
| `recognition_failed(reason: String)` | No match / timeout / mic denied / unsupported. |

### Functions
| Function | Effect |
|----------|--------|
| `start_listening()` | Begin recognition. |
| `stop_listening()` | End recognition early. |
| `set_confidence_threshold(value: float)` | 0.0–1.0. Default 0.70. Lower = more permissive. |

---

## Powers & keywords

Defined in `voice_config.json`. Fuzzy matched (up to 2 characters off).

| Key | Power | Keywords |
|-----|-------|----------|
| W | Shapeshift | shapeshift, dragon, transform, morph |
| E | Flight | flight, fly, ascend, rise, up |
| Q | 4th Wall | wall, break, glitch, reality |
| R | Consequences | storm, passes, freeze, time, clear, plummet, fall |

To change keywords, edit `voice_config.json` — no code change. Restart to reload.

**Multi-command:** a spoken chain fires each word in order.
`"fall break dragon"` → **R, Q, W** in sequence.

---

## How matching works

1. Recognized speech is split into words.
2. Each word is compared to every keyword via **Levenshtein distance**.
3. Distance (distance is how far off the word is (characters)) ≤ 2 counts as a match; confidence = `1 − distance / max_length`.
4. If best confidence higher than threshold (default 70%), `power_triggered` works

Example: `"dragn"` → `"dragon"`, distance 1, length 6 → **83%** → fires W.

---

## Fallbacks (always available)

- **Direct keys:** `Q` / `W` / `E` / `R` emit `power_triggered`
- **Debug typed input:** press **Shift+V** for a text box. Type a phrase, Enter,
  and it's treated as speech. Great for testing matching without a mic.

---

## Web export

1. **Project > Export > Add > Web**.
2. Set a **Custom HTML Shell** that contains the `voice_bridge.html` code.
   The `<style>`, the `#voice-overlay` markup, and the `<script>` block from
   `voice_bridge.html` must live in the **same page** as the game (not an
   iframe — `JavaScriptBridge` talks to the top window).
   > Ask the Voice dept for a pre-merged `web_shell.html` if you don't have one.
3. If Godot's export enables threads, the server must send COOP/COEP headers,
   or disable threads in the export options. `python3 -m http.server` alone
   won't send those headers.
4. Export → produces `index.html` + assets.

# try locally: (running html doesn't work)
```bash
cd export_folder
python3 -m http.server 8080
# open http://localhost:8080
```

---

## Troubleshooting
Idk bro just ask me ig
