class_name SfxPatches

## Designed gamesynth patches for the game's one-shot effects, as SynthPatch parameter sets.
## Waves: 0 sine, 1 triangle, 2 saw, 3 square, 4 pulse, 5 white noise, 6 pink noise.
## Filter modes: 0 off, 1 low-pass, 2 high-pass, 3 band-pass, 4 notch.
## filter/sweep is octaves per second, pitch/slide semitones per second, base_note is MIDI.

const PATCHES := {
	# Boost pad: noise whoosh opening upward over a rising sub tone.
	"boost": {
		"osc1/wave": 5, "osc1/level": 1.0,
		"osc2/wave": 0, "osc2/level": 0.55, "osc2/semitones": -24.0,
		"pitch/slide": 18.0,
		"filter/mode": 1, "filter/cutoff_hz": 260.0, "filter/resonance": 0.55, "filter/sweep": 5.0,
		"amp_env/attack": 0.06, "amp_env/decay": 0.55, "amp_env/sustain": 0.0, "amp_env/release": 0.3,
		"fx/drive": 0.25, "master/gain": 0.8, "master/base_note": 60.0,
	},
	# Boost pad bell: big inharmonic bell (hum, prime, tierce-ish partials), slow shimmer,
	# long decay. Played at the pad, so it rings behind you as you speed away.
	"pad_bell": {
		"osc1/wave": 0, "osc1/level": 1.0,
		"osc2/wave": 0, "osc2/level": 0.6, "osc2/semitones": 15.9, "osc2/detune_cents": 6.0,
		"osc3/wave": 0, "osc3/level": 0.35, "osc3/semitones": 31.0, "osc3/detune_cents": -9.0,
		"lfo/wave": 0, "lfo/rate_hz": 2.6, "lfo/amp": 0.18,
		"filter/mode": 1, "filter/cutoff_hz": 7000.0, "filter/resonance": 0.1, "filter/sweep": -0.8,
		"amp_env/attack": 0.003, "amp_env/decay": 6.0, "amp_env/sustain": 0.0, "amp_env/release": 2.0,
		"fx/drive": 0.15, "master/gain": 0.9, "master/base_note": 57.0,
	},
	# Wall strike: noise crunch closing down fast, sub thud dropping, a square partial for metal.
	"wall_hit": {
		"osc1/wave": 5, "osc1/level": 1.0,
		"osc2/wave": 0, "osc2/level": 1.0, "osc2/semitones": -27.0,
		"osc3/wave": 3, "osc3/level": 0.3, "osc3/semitones": 19.0, "osc3/detune_cents": 12.0,
		"pitch/slide": -22.0,
		"filter/mode": 1, "filter/cutoff_hz": 7000.0, "filter/resonance": 0.35, "filter/sweep": -9.0,
		"amp_env/attack": 0.002, "amp_env/decay": 0.32, "amp_env/sustain": 0.0, "amp_env/release": 0.2,
		"fx/drive": 0.7, "master/gain": 0.9, "master/base_note": 60.0,
	},
	# Ship-to-ship: short bright metallic clank through a resonant band-pass.
	"ship_hit": {
		"osc1/wave": 3, "osc1/level": 0.7, "osc1/semitones": 12.0,
		"osc2/wave": 2, "osc2/level": 0.5, "osc2/semitones": 19.0, "osc2/detune_cents": 30.0,
		"osc3/wave": 5, "osc3/level": 0.5,
		"filter/mode": 3, "filter/cutoff_hz": 2500.0, "filter/resonance": 0.7, "filter/sweep": -6.0,
		"amp_env/attack": 0.001, "amp_env/decay": 0.14, "amp_env/sustain": 0.0, "amp_env/release": 0.1,
		"fx/drive": 0.5, "master/gain": 0.8, "master/base_note": 60.0,
	},
	"countdown_tick": {
		"osc1/wave": 0, "osc1/level": 0.8,
		"amp_env/attack": 0.002, "amp_env/decay": 0.07, "amp_env/sustain": 0.0, "amp_env/release": 0.06,
		"master/gain": 0.6, "master/base_note": 76.0,
	},
	"countdown_go": {
		"osc1/wave": 0, "osc1/level": 0.8,
		"osc2/wave": 0, "osc2/level": 0.5, "osc2/semitones": 7.0,
		"amp_env/attack": 0.002, "amp_env/decay": 0.3, "amp_env/sustain": 0.0, "amp_env/release": 0.25,
		"master/gain": 0.6, "master/base_note": 81.0,
	},
	"lap": {
		"osc1/wave": 1, "osc1/level": 0.8,
		"pitch/arp_semitones": 5.0, "pitch/arp_time": 0.14,
		"amp_env/attack": 0.003, "amp_env/decay": 0.35, "amp_env/sustain": 0.0, "amp_env/release": 0.3,
		"fx/delay_time": 0.18, "fx/delay_feedback": 0.3, "fx/delay_mix": 0.25,
		"master/gain": 0.5, "master/base_note": 81.0,
	},
	"finish": {
		"osc1/wave": 1, "osc1/level": 0.8,
		"osc2/wave": 0, "osc2/level": 0.4, "osc2/semitones": 12.0,
		"pitch/arp_semitones": 7.0, "pitch/arp_time": 0.16,
		"amp_env/attack": 0.003, "amp_env/decay": 0.5, "amp_env/sustain": 0.0, "amp_env/release": 0.5,
		"fx/delay_time": 0.22, "fx/delay_feedback": 0.35, "fx/delay_mix": 0.35,
		"master/gain": 0.55, "master/base_note": 76.0,
	},
}


## Builds a one-shot SynthStream for a named effect, or null without the extension.
static func make_stream(name: String) -> AudioStream:
	if not PATCHES.has(name) or not ClassDB.class_exists("SynthStream"):
		return null
	var patch = ClassDB.instantiate("SynthPatch")
	for key in PATCHES[name]:
		patch.set_param(key, float(PATCHES[name][key]))
	var stream = ClassDB.instantiate("SynthStream")
	stream.patch = patch
	stream.one_shot = true
	return stream
