# Audio contract: game <-> gamesynth

The game (this repo, GDScript) never synthesises in real time. It plays files from `audio/`
and modulates them. Anything that produces those files — `../gamesynth`, Logic, the Spark —
just has to hit these paths and specs. Files are optional: missing ones are skipped or
replaced by the built-in synthesised placeholders.

## Stage 1 — files (works today)

All WAV: mono, 16-bit, 44100 Hz. Music may be ogg/mp3.

| Path | What | Spec |
|---|---|---|
| `audio/engine/drone.wav` | hover hum, always on | seamless loop ~1 s, reference pitch **55 Hz** |
| `audio/engine/turbine.wav` | engine note | seamless loop ~1 s, reference **220 Hz**; game pitches it 0.45× (idle) … 2.0× (top speed) … 2.5× (boost) |
| `audio/engine/exhaust_low.wav` | dark rumble, fades in with throttle | seamless noise loop ~1 s |
| `audio/engine/exhaust_high.wav` | bright hiss; throttle, boost, airbrake | seamless noise loop ~1 s |
| `audio/sfx/countdown_tick.wav` `countdown_go.wav` | start lights | one-shot |
| `audio/sfx/lap.wav` `finish.wav` | player events | one-shot |
| `audio/sfx/boost.wav` `wall_hit.wav` | any ship; positional in 3D, `wall_hit` pitched 0.8–1.2× by impact | one-shot |
| `audio/music/*.ogg` | soundtrack, shuffled + crossfaded, low-passed at low speed | full tracks (currently 7 from ACE-Step via `tools/music/`); stems come later |

Buses (`default_bus_layout.tres`): `Master` ← `Music` (low-pass driven by player speed) and `Master` ← `SFX`
(engine layers and one-shots). Music lives at -14 LUFS / -1 dBTP; aim engine loops and SFX to sit under that.

Seamless loop = whole number of cycles for tones (55 Hz → 55 cycles in exactly 1.000 s),
short crossfade at the join for noise. Peak-normalise to about -1 dBFS; the game sets levels.

How the game modulates engine loops per frame (`scripts/engine_audio.gd`):
`speed_ratio` = speed / max_speed (0..1.3 with boost), `throttle` 0..1 smoothed,
`airbrake` bool, `boost_env` decaying 1→0 after a pad, `impact_env` decaying after a wall hit.

## Stage 2 — real-time synth in the game (later)

If gamesynth becomes the engine sound itself instead of rendering loops, it gets ported to a
Rust GDExtension implementing `AudioStreamPlayback::mix()`. To make that port mechanical,
keep gamesynth's DSP core in this shape:

- A core class with `setParam(name, value)` and `process(outL: Float32Array, outR: Float32Array, n: number)`.
  No `AudioWorkletProcessor`, `AudioContext` or `postMessage` inside the core — those live in a thin wrapper.
- No allocation inside `process()`; preallocate buffers in the constructor.
- Sample rate passed into the constructor, never read from a global.
- Parameter set the game will drive every frame: `speed` (0..1.3), `throttle` (0..1),
  `airbrake` (0/1), `boost` (0..1 envelope), `impact` (0..1 envelope), plus a per-ship `variant` seed.
- Deterministic given the same params and seed, so AI ships can share code with different variants.

Same core, two wrappers: an AudioWorklet wrapper for designing in the browser, a Node CLI wrapper
(`node render.js patch.json --seconds 1 --loop --out drone.wav`) for Stage 1 files.
