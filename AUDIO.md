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

## Stage 2 — real-time synth in the game (DONE: gamesynth GDExtension)

`../gamesynth` ships a Rust GDExtension; `tools/sync_gamesynth.sh` builds it and copies the
binary into `addons/gamesynth/bin/`. With it loaded:

- every ship's engine is a `JetEngineStream` (`scripts/engine_audio.gd`), fed
  `set_state(throttle, boost, speed, damage)` each frame; wall hits add damage that repairs over time.
  Preset per ship via `EngineAudio.jet_preset` (Racer / Heavy / Turbine / Scramjet); tune the ~25
  params in a `JetEnginePatch` `.tres` later.
- every SFX is a designed `SynthPatch` in `scripts/sfx_patches.gd`, played live by `SynthStream` (whoosh,
  crunchy wall strike, clank, ticks, chimes). Tune the parameter dictionaries there; the sfxr-style random
  presets were too arcade for this game. `scripts/sfx.gd` still synthesises WAV fallbacks without the extension.

The extension also builds to WebAssembly for the web export (single-threaded, `nothreads` feature).

### The mix (2026-09-20)

Measured, not guessed: `tools/mix_probe.tscn` records every bus to its own WAV during an autopilot race (headless,
real time) and with `MIX_SPLIT=1` splits the effects bus by source and tallies which events played and how loud
they arrived. Target: **music 3 LU above everything else combined**, master under 0 dBFS.

    MIX_SPLIT=1 MIX_OUT=/tmp/mix AG_AUTOPILOT=1 godot --headless --max-fps 60 --path . tools/mix_probe.tscn
    ffmpeg -i /tmp/mix/music.wav -af ebur128 -f null - 2>&1 | grep "I:" | tail -1

Where it started: music -16.4 LUFS against -9.0 for the rest (7.4 LU under), master clipping at +1.8 dBFS. The
cause was the one-shot events at -8.8 LUFS on their own: every AI ship rang every boost-pad bell (26 six-second
bells in 45 s, full level within 60 m), plus four rivals' whooshes, landings and contacts.
Now: music about -12 LUFS, engines -17, events -17.5, ambience -23; music 2.8 to 3.9 LU above the rest.
The knobs: `Music.volume_db` (+1.5), `EngineAudio.master_db` (-10.5), `Sfx.volume_db` (-14), `Sfx.others_db`
(-7, applied to every positional event that isn't the player's own), the pad bell's levels in
`engine_audio.gd:_on_boost`, rain and wind in `ambience.gd`, and a hard limiter on Master (`settings.gd`).
Settings sliders at 80 are this mix.

gamesynth one-shots never report the end to Godot (their `mix` keeps returning full buffers of silence, so
`finished` never fires); `Sfx._process` asks each playback `is_playing()` and frees the player itself.

### Music (2026-09-20)

All nine were generated on the DGX Spark with ACE-Step 1.5 (checkpoint `acestep-v15-xl-sft`, language model
`acestep-5Hz-lm-4B`, MIT licence), verified from the Spark's generation logs. `tools/music/generate.py` in this
repo is the older ACE-Step v1 script; the 1.5 script lives on the Spark as `~/music-gen/generate15.py`.

Nine tracks, picked by ear from 20 candidates with `tools/music/previews/picker/index.html` (git-ignored):
`intro_ion_drift` (ACE-Step 1.5) on the title screen, and `afrodnb1-4` (afro drum and bass) plus `fire1-4`
(big beat punk) shuffled during races. `Music.INTRO` and `Music.RACE` in `scripts/music.gd` are the two
playlists, by filename prefix; a circuit can override with `"music"` in `track_defs.gd`.
To install more: `SPARK_OUT=music-gen/<folder> tools/music/fetch.sh`, or stage renamed WAVs locally and run
`SRC_DIR=<dir> tools/music/fetch.sh` (two-pass loudness match to -14 LUFS, fades, Ogg Vorbis).

### gamesynth generators (2026-09-20)

gamesynth's `SoundGenerator` now carries nearly every sound in the game:

- **Events** (`Sfx.GENERATORS` in `scripts/sfx.gd` maps each game event to a generator and preset): `beep`
  (countdown, Go, low-energy warning), `lock_on`, `pickup`, `boost`, `airbrake`, `impact` (wall, ship contact,
  heavy landing), `rocket`, `mine_drop`, `mine_blast`, `explosion` (and its "Ship destroyed" preset), `shield_up`,
  `shield_hit`, plus the `checkpoint` model file for laps. Each play passes `power` (how hard) and `distance`
  (how far from the camera); every trigger varies a little; players free themselves on `finished`.
- **Continuous** (`scripts/ambience.gd`, player-centric): `rain` with `shelter` in tunnels, `wind` with speed and
  airtime, and the `recharge` model in the pit lane. Per ship: `scrape` while grinding a wall (`engine_audio.gd`).
  Per weapon near the player (`projectile.gd`): `rocket_flight` on rockets and missiles, `mine_armed` ticking
  faster as a ship approaches.
- Model files live in `audio/models/*.toml` (copied from `../gamesynth/models/`) and are included in the web
  export by `include_filter="*.toml"`.
- Still hand-made `SynthPatch`es (`scripts/sfx_patches.gd`): the pad bell and the finish chime. Every such
  one-shot patch needs a `master/duration`, or it never ends and its player leaks.

Stage 1 files still take priority wherever they exist, so rendered loops or samples can replace any layer.

Original Stage 2 design notes (kept for reference):

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
