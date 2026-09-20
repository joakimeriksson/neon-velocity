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
		"filter/mode": 1, "filter/cutoff_hz": 220.0, "filter/resonance": 0.65, "filter/sweep": 4.5,
		"amp_env/attack": 0.05, "amp_env/decay": 0.75, "amp_env/sustain": 0.0, "amp_env/release": 0.4,
		"fx/drive": 0.25, "master/gain": 0.95, "master/base_note": 60.0,
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
	# Wall strike, layer 1: heavy metal crunch. Low square + clashing detuned saw + noise,
	# pitch sagging, hard drive, a fast amplitude rattle.
	"wall_hit": {
		"osc1/wave": 3, "osc1/level": 0.9, "osc1/semitones": -12.0,
		"osc2/wave": 2, "osc2/level": 0.7, "osc2/semitones": -4.7, "osc2/detune_cents": 18.0,
		"osc3/wave": 5, "osc3/level": 0.9,
		"pitch/slide": -7.0,
		"lfo/wave": 3, "lfo/rate_hz": 11.0, "lfo/amp": 0.3,
		"filter/mode": 1, "filter/cutoff_hz": 5000.0, "filter/resonance": 0.5, "filter/sweep": -5.0,
		"amp_env/attack": 0.001, "amp_env/decay": 0.5, "amp_env/sustain": 0.0, "amp_env/release": 0.35,
		"fx/drive": 0.9, "master/gain": 1.0, "master/base_note": 55.0,
	},
	# Wall strike, layer 2: the clang that rings on at the point of impact.
	"wall_clang": {
		"osc1/wave": 0, "osc1/level": 1.0,
		"osc2/wave": 0, "osc2/level": 0.7, "osc2/semitones": 8.7, "osc2/detune_cents": 14.0,
		"osc3/wave": 3, "osc3/level": 0.3, "osc3/semitones": 19.6, "osc3/detune_cents": -11.0,
		"lfo/wave": 0, "lfo/rate_hz": 14.0, "lfo/amp": 0.3,
		"filter/mode": 1, "filter/cutoff_hz": 6500.0, "filter/resonance": 0.2, "filter/sweep": -2.0,
		"amp_env/attack": 0.002, "amp_env/decay": 1.2, "amp_env/sustain": 0.0, "amp_env/release": 0.6,
		"fx/drive": 0.45, "master/gain": 0.85, "master/base_note": 64.0,
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
	# Rocket launch: hard noise burst with a falling saw, the "fwoosh-crack" of a tube firing.
	"rocket_fire": {
		"osc1/wave": 5, "osc1/level": 1.0,
		"osc2/wave": 2, "osc2/level": 0.6, "osc2/semitones": -12.0,
		"pitch/slide": -30.0,
		"filter/mode": 1, "filter/cutoff_hz": 6000.0, "filter/resonance": 0.3, "filter/sweep": -5.0,
		"amp_env/attack": 0.002, "amp_env/decay": 0.45, "amp_env/sustain": 0.0, "amp_env/release": 0.3,
		"fx/drive": 0.6, "master/gain": 0.9, "master/base_note": 60.0,
	},
	# Missile: same launch with a rising seeker whine on top.
	"missile_fire": {
		"osc1/wave": 5, "osc1/level": 0.9,
		"osc2/wave": 4, "osc2/level": 0.5, "osc2/semitones": 12.0, "osc2/pulse_width": 0.3,
		"pitch/slide": 22.0,
		"filter/mode": 1, "filter/cutoff_hz": 3500.0, "filter/resonance": 0.5, "filter/sweep": 2.0,
		"amp_env/attack": 0.004, "amp_env/decay": 0.6, "amp_env/sustain": 0.0, "amp_env/release": 0.3,
		"fx/drive": 0.5, "master/gain": 0.85, "master/base_note": 64.0,
	},
	# Mines: three clunks via the delay line.
	"mine_drop": {
		"osc1/wave": 3, "osc1/level": 0.8, "osc1/semitones": -12.0,
		"osc2/wave": 5, "osc2/level": 0.4,
		"filter/mode": 1, "filter/cutoff_hz": 1200.0, "filter/resonance": 0.4, "filter/sweep": -6.0,
		"amp_env/attack": 0.001, "amp_env/decay": 0.09, "amp_env/sustain": 0.0, "amp_env/release": 0.06,
		"fx/delay_time": 0.11, "fx/delay_feedback": 0.45, "fx/delay_mix": 0.6,
		"fx/drive": 0.4, "master/gain": 0.8, "master/base_note": 50.0,
	},
	# Explosion: wide noise slamming shut over a sub drop, heavily driven, long tail.
	"explosion": {
		"osc1/wave": 5, "osc1/level": 1.0,
		"osc2/wave": 0, "osc2/level": 1.0, "osc2/semitones": -24.0,
		"osc3/wave": 6, "osc3/level": 0.8,
		"pitch/slide": -14.0,
		"filter/mode": 1, "filter/cutoff_hz": 5000.0, "filter/resonance": 0.2, "filter/sweep": -3.5,
		"amp_env/attack": 0.001, "amp_env/decay": 1.1, "amp_env/sustain": 0.0, "amp_env/release": 0.6,
		"fx/drive": 0.95, "master/gain": 1.0, "master/base_note": 57.0,
	},
	# Shield up: two detuned sines gliding up into a shimmer.
	"shield_on": {
		"osc1/wave": 0, "osc1/level": 0.8,
		"osc2/wave": 0, "osc2/level": 0.6, "osc2/semitones": 7.0, "osc2/detune_cents": 12.0,
		"pitch/slide": 14.0,
		"lfo/wave": 0, "lfo/rate_hz": 9.0, "lfo/amp": 0.3,
		"amp_env/attack": 0.03, "amp_env/decay": 0.7, "amp_env/sustain": 0.0, "amp_env/release": 0.4,
		"fx/delay_time": 0.09, "fx/delay_feedback": 0.4, "fx/delay_mix": 0.3,
		"master/gain": 0.6, "master/base_note": 67.0,
	},
	# A shot soaked up by a shield: glassy ping.
	"shield_block": {
		"osc1/wave": 0, "osc1/level": 0.9,
		"osc2/wave": 1, "osc2/level": 0.5, "osc2/semitones": 19.0,
		"amp_env/attack": 0.001, "amp_env/decay": 0.35, "amp_env/sustain": 0.0, "amp_env/release": 0.3,
		"fx/delay_time": 0.07, "fx/delay_feedback": 0.35, "fx/delay_mix": 0.3,
		"master/gain": 0.6, "master/base_note": 84.0,
	},
	# Item collected: quick rising two-note chirp, square-ish but soft.
	"pickup": {
		"osc1/wave": 1, "osc1/level": 0.8,
		"osc2/wave": 0, "osc2/level": 0.4, "osc2/semitones": 12.0,
		"pitch/arp_semitones": 7.0, "pitch/arp_time": 0.07,
		"amp_env/attack": 0.002, "amp_env/decay": 0.16, "amp_env/sustain": 0.0, "amp_env/release": 0.12,
		"master/gain": 0.55, "master/base_note": 79.0,
	},
	# Pit lane charge tick; the HUD raises its pitch as the bar fills.
	"recharge": {
		"osc1/wave": 0, "osc1/level": 0.8,
		"osc2/wave": 1, "osc2/level": 0.3, "osc2/semitones": 12.0,
		"amp_env/attack": 0.003, "amp_env/decay": 0.1, "amp_env/sustain": 0.0, "amp_env/release": 0.08,
		"master/gain": 0.5, "master/base_note": 72.0,
	},
	# Low energy warning: flat double pulse.
	"energy_low": {
		"osc1/wave": 4, "osc1/level": 0.7, "osc1/pulse_width": 0.25,
		"filter/mode": 1, "filter/cutoff_hz": 1800.0, "filter/resonance": 0.3,
		"amp_env/attack": 0.002, "amp_env/decay": 0.08, "amp_env/sustain": 0.0, "amp_env/release": 0.05,
		"fx/delay_time": 0.14, "fx/delay_feedback": 0.1, "fx/delay_mix": 0.7,
		"master/gain": 0.5, "master/base_note": 69.0,
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
	var params: Dictionary = PATCHES[name]
	for key in params:
		patch.set_param(key, float(params[key]))
	# Every patch here decays to silence (sustain 0). Without a note length the synth holds the
	# note at zero volume for ever: the voice never ends, the player never emits `finished`, and
	# players pile up by the hundred. So give each one a length: attack plus decay, then release.
	if not params.has("master/duration"):
		patch.set_param("master/duration", float(params.get("amp_env/attack", 0.005)) + float(params.get("amp_env/decay", 0.1)))
	var stream = ClassDB.instantiate("SynthStream")
	stream.patch = patch
	stream.one_shot = true
	return stream
