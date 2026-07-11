// vosk-bridge.js — offline local speech recognition for the Godot web export.
//
// Loads before the Godot engine (via <head> include) and claims the voice
// bridge (__voiceBridgeInstalled = true) so VoiceInputManager.gd's injected
// Web-Speech-API bridge early-returns and this Vosk engine takes over instead.
//
// Exposes the SAME API Godot already calls:
//   window.startVoiceRecognition()  -> boot mic + recognizer (idempotent)
//   window.stopVoiceRecognition()   -> no-op (Vosk stays always-on)
//   window.godotVoiceCallback(json) -> set by Godot; we push results to it
//   window.__voiceLevel             -> 0..1 RMS, for the mic bar + damage
//
// Requires (served next to the exported .html, same origin):
//   vosk.js                              (vosk-browser dist, defines global Vosk)
//   vosk-model-small-en-us-0.15.tar.gz   (acoustic model archive)
// And a server sending COOP/COEP headers (see serve.py) for SharedArrayBuffer.

(function () {
	"use strict";
	if (window.__voiceBridgeInstalled) return;
	window.__voiceBridgeInstalled = true; // <- blocks Godot's WSA bridge
	window.__voiceEngine = "vosk";
	window.__voiceLevel = 0.0;

	// Grammar: recognizer only ever emits THESE words. Small closed set =
	// low latency + high accuracy. Keep in sync with voice_config.json keywords.
	// "[unk]" lets Vosk reject anything else instead of forcing a bad match.
	// Real English words only (must exist in Vosk's dictionary). Vosk maps
	// whatever you say to the CLOSEST word here, so a big set = tolerant of
	// similar pronunciation. Godot maps each word -> W (shoot) or E (deflect).
	var GRAMMAR = [
		// --- shoot / attack (-> W) ---
		"shoot", "shoots", "shot", "shots", "fire", "fired", "blast", "attack",
		"strike", "launch", "bang", "boom", "gun", "hit", "boot", "chute",
		// --- deflect / defend (-> E) ---
		"deflect", "block", "shield", "guard", "defend", "protect", "parry",
		"repel", "push", "stop", "wall", "wind", "away", "back", "blow", "bounce",
		// --- fourth wall / erase (-> Q) ---
		"erase", "erases", "destroy", "destroys", "obliterate", "delete", "scribble", "kill", "remove",
		"[unk]"
	];
	var MODEL_URL = "vosk-model-small-en-us-0.15.tar.gz";

	function sendToGodot(obj) {
		var json = JSON.stringify(obj);
		if (typeof window.godotVoiceCallback === "function") {
			try { window.godotVoiceCallback(json); }
			catch (e) { console.warn("[vosk-bridge] callback threw:", e); }
		} else {
			console.log("[vosk-bridge] (no Godot callback yet):", json);
		}
	}

	var model = null;
	var recognizer = null;
	var audioContext = null;
	var processor = null;
	var source = null;
	var booting = false;
	var firedCounts = {}; // word -> times fired THIS utterance (count-based rapid fire)
	var lastFired = {};   // word -> last fire timestamp (ms), for debounce

	var FIRE_CONFIDENCE = 0.9; // sent to Godot (was 1.0, -0.1)
	var MIN_GAP_MS = 160;      // min gap between two fires of the SAME word -> less trigger-happy
	var VOLUME_DAMP = 0.5;     // scale raw mic RMS down (was "too loud")

	// Fire each new word occurrence as the partial transcript grows, but debounce
	// per word so partial flicker can't double-fire. Deliberate repeats slower
	// than MIN_GAP_MS still fire ("shoot ... shoot").
	function fireWords(text) {
		var words = (text || "").toLowerCase().split(/[^a-z]+/).filter(Boolean);
		var seen = {};
		for (var i = 0; i < words.length; i++) seen[words[i]] = (seen[words[i]] || 0) + 1;
		var now = (performance && performance.now) ? performance.now() : Date.now();
		for (var w in seen) {
			var already = firedCounts[w] || 0;
			if (seen[w] > already) {
				firedCounts[w] = seen[w];
				if (now - (lastFired[w] || 0) >= MIN_GAP_MS) {
					lastFired[w] = now;
					sendToGodot({ type: "result", text: w, confidence: FIRE_CONFIDENCE });
				}
			}
		}
	}

	function boot() {
		if (booting || recognizer) return;
		booting = true;
		if (typeof Vosk === "undefined") {
			console.error("[vosk-bridge] Vosk global missing — is vosk.js loaded?");
			sendToGodot({ type: "error", reason: "vosk_missing" });
			booting = false;
			return;
		}

		Vosk.createModel(MODEL_URL).then(function (m) {
			model = m;
			var AC = window.AudioContext || window.webkitAudioContext;
			audioContext = window.__voiceAC || new AC();
			window.__voiceAC = audioContext;

			// Recognizer runs at the AudioContext's native rate; Vosk resamples
			// to the model's 16 kHz internally.
			recognizer = new model.KaldiRecognizer(audioContext.sampleRate, JSON.stringify(GRAMMAR));
			recognizer.setWords(true);

			// Partial = streaming, fires words with ~100ms latency (fast path).
			recognizer.on("partialresult", function (msg) {
				fireWords(msg.result && msg.result.partial);
			});
			// Final = utterance ended: catch any word only present in the final,
			// then reset so the next utterance re-fires the same words.
			recognizer.on("result", function (msg) {
				fireWords(msg.result && msg.result.text);
				firedCounts = {};
			});

			return navigator.mediaDevices.getUserMedia({ audio: true, video: false });
		}).then(function (stream) {
			if (!stream) return;
			source = audioContext.createMediaStreamSource(stream);
			processor = audioContext.createScriptProcessor(2048, 1, 1); // smaller = lower latency
			processor.onaudioprocess = function (ev) {
				var buf = ev.inputBuffer;
				if (recognizer) {
					try { recognizer.acceptWaveform(buf); }
					catch (err) { console.warn("[vosk-bridge] acceptWaveform:", err); }
				}
				// RMS volume for the mic bar + damage scaling.
				var d = buf.getChannelData(0);
				var s = 0.0;
				for (var i = 0; i < d.length; i++) s += d[i] * d[i];
				window.__voiceLevel = Math.sqrt(s / d.length) * VOLUME_DAMP; // damped: less sensitive
			};
			source.connect(processor);
			processor.connect(audioContext.destination);
			window.__voskReady = true;
			console.log("[vosk-bridge] recognizer live @", audioContext.sampleRate, "Hz");
		}).catch(function (err) {
			console.error("[vosk-bridge] init failed:", err);
			sendToGodot({ type: "error", reason: "vosk_init" });
			booting = false;
		});
	}

	// ---- Godot-facing API ---------------------------------------------------
	window.startVoiceRecognition = function () {
		if (window.__voiceAC && window.__voiceAC.state === "suspended") {
			try { window.__voiceAC.resume(); } catch (e) {}
		}
		boot(); // idempotent; continuous listening after first call
	};
	window.stopVoiceRecognition = function () { /* Vosk stays always-on */ };
	window.godotVoiceReady = window.godotVoiceReady || function () {};

	console.log("[vosk-bridge] loaded, engine =", window.__voiceEngine);
})();
