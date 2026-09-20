# Neon Velocity

Wipeout-style anti-gravity racer in Godot 4.7 (Forward+), set in a rain-soaked neon megacity.

Run: `godot --path .` (or open the folder in the editor).

Flow: title (attract-mode race behind it) → circuit select → 3-lap race against 4 AI →
results with score → high-score table (top 10 per circuit, initials entry, saved in `user://highscores.json`).

**Controls** — keyboard: W/S thrust/brake, A/D steer, Q/E airbrakes, R respawn, Esc pause.
PlayStation controller (DualShock 4 / DualSense over USB or Bluetooth): R2 thrust, L2 brake, ✕ also thrusts,
left stick steer, L1/R1 airbrakes, △ respawn, Options pause, ✕ confirm / ○ back in menus, D-pad or stick to navigate.
Rumble on wall hits and boost pads.

**Combat**: magenta item pads either side of the racing line give one pickup (ROCKET, homing MISSILE, MINES,
SHIELD, TURBO; leaders roll more defensive items, the back of the field more catch-up ones). Fire with
Space / Ctrl / Square, or absorb the item for energy with F / Circle. Projectiles ride the track, so rockets follow the
road round corners. Walls, collisions and weapons drain the energy bar; the green pit lane before the start line
recharges it; at zero the ship explodes and is eliminated. The AI fires, mines, shields and pits too.

**Scoring**: position points (1000 / 700 / 500 / 350 / 200) + 25 per second under the circuit's par time
(`par_lap` × 3 in `track_defs.gd`) + 250 for a lap under 97% of par + 75 per weapon hit landed and 250 per rival eliminated. Being eliminated scores 0.

Circuits (`scripts/track_defs.gd`): **Neon Descent** (flowing, 2.6 km), **Undertow** (narrow and
technical, 1.9 km), **Chrome Riot** (wide and fast, 3.5 km). The city around them is procedural.

## Layout

- `scripts/track_defs.gd` — the circuits: control points, width, banking, neon colour, boost pad positions.
- `scripts/track_builder.gd` — builds a closed banked track from a definition: floor, walls, neon edge strips, start line, boost pads, trimesh collider, starting grid.
- `scripts/city_builder.gd` + `shaders/` — Blade Runner megacity around the track: ~1300 towers in one MultiMesh with a procedural lit-window/grime facade shader, neon billboards, sodium street lights, sweeping searchlights, wet ground, rain following the camera.
- `models/ships/*.glb` — the ship models (player + four AI), designed externally; see `models/ships/README.md` for the drop-in spec. `scripts/ship.gd` swaps them in for the placeholder hull and attaches exhausts to their `EngineL`/`EngineR` empties.
- `scripts/title.gd` — title + circuit select over an attract-mode race; `scripts/highscore_screen.gd` + `scripts/highscores.gd` — initials entry and persisted tables; `scripts/results.gd`, `scripts/pause_menu.gd` — overlays; `scripts/ui_theme.gd` — shared neon UI helpers.
- `scripts/game.gd` — autoload: scene flow, scoring, `attract` mode, controller name (`AG_TRACK=<n>` env picks a circuit for headless runs).
- `scripts/ship.gd` — hover controller: raycast hover spring, thrust/drag, lateral grip, airbrakes, boost, wall scrape. Reads inputs a driver child writes. All tuning exported.
- `scripts/player_driver.gd` — keyboard/gamepad → ship.
- `scripts/engine_audio.gd` — per-ship engine sound on a positional player with Doppler. Uses the gamesynth `JetEngineStream` (procedural turbine driven by throttle/boost/speed/damage) when the extension is present, else synthesised loops.
- `scripts/sfx.gd` — one-shots: a WAV in `audio/sfx/` wins, else a gamesynth `SynthStream` preset, else silence.
- `addons/gamesynth/` — the [gamesynth](../gamesynth) GDExtension (Rust). Binary is gitignored; rebuild and copy it with `tools/sync_gamesynth.sh`.
- `scripts/ai_driver.gd` — follows the centre line (with a lane offset), airbrakes into corners; `skill` scales top speed.
- `scripts/race.gd` — spawns the grid (4 AI + player), countdown, laps, positions, finish, results, pause, rumble; also the combat referee (pickups, launches, pit recharge, eliminations).
- `scripts/items.gd`, `scripts/projectile.gd`, `scripts/explosion.gd` — pickups and their position-weighted roll; rockets, missiles and mines in track coordinates (`TrackBuilder.get_point`); one-shot blast effect.
- `scripts/chase_camera.gd`, `scripts/hud.gd` — camera that rolls with the banking; speed / position / lap / best lap / countdown.
- `scripts/music.gd` — autoload; shuffles and crossfades any ogg/wav/mp3 in `audio/music/`, and low-passes the mix at low speed (`Music.attach_ship`).
- `tools/music/` — soundtrack generation with ACE-Step on the DGX Spark, plus mastering. See `tools/music/README.md`.

## Dev

Record a clip without a player (AI drives the player ship). Pass the race scene explicitly, the main scene is the title.
Use the AVI writer (real-time speed; PNG is ~30x slower) and keep the window uncovered: macOS stops
an occluded window from drawing and the writer just repeats the last frame. `--always-on-top` helps.

    AG_TRACK=1 AG_AUTOPILOT=1 godot --path . --always-on-top --write-movie out/clip.avi --fixed-fps 30 --quit-after 900 scenes/main.tscn
    ffmpeg -i out/clip.avi -c:v libx264 -crf 19 -pix_fmt yuv420p -c:a aac out/clip.mp4

Godot's closing "N frames" line should equal --quit-after; fewer means frames were dropped while occluded.

Simulate a full race headless, as fast as possible, printing lap times:

    AG_TRACK=0 AG_AUTOPILOT=1 godot --headless --path . --fixed-fps 60 --quit-after 5400 scenes/main.tscn

Check that no circuit folds back on itself, and that both walls actually stop a ship:

    godot --headless --path . -s tools/check_tracks.gd
    godot --headless --path . -s tools/check_walls.gd

`AG_ENERGY=40` starts every ship at that energy (pit stops, low-energy warnings).
`AG_COMBAT_LOG=1` prints every pickup use, hit, pit entry and elimination with race time, for balancing in a headless sim.
`AG_NO_MUSIC=1` silences the soundtrack so engine and SFX can be judged alone; `AG_NO_EXHAUST=1` hides the
afterburners. `tools/flame_test.tscn` is a side-view rig for tuning the exhaust:

    godot --path . --write-movie out/flame.avi --fixed-fps 30 --quit-after 90 tools/flame_test.tscn

New audio/art files need an import pass before a headless run can `load()` them:

    godot --headless --path . --import

## Audio

Buses are `Master` -> `Music` (low-pass, driven by ship speed) and `Master` -> `SFX`
(engine audio), defined in `default_bus_layout.tres`.

Regenerate the soundtrack:

    ssh spark 'cd music-gen && .venv/bin/python generate.py --out out'
    tools/music/fetch.sh

## Web build

Exports with the `Web` preset in `export_presets.cfg` (single-threaded, so it runs on any static host,
GitHub Pages included). The web platform uses the Compatibility renderer, so volumetric fog, SSR and FSR
are absent there; `project.godot` carries `.web` overrides for the settings that only exist in Forward+.
The gamesynth extension is included as WebAssembly (`addons/gamesynth/bin/gamesynth_godot.wasm`, tracked in git so CI can
use it; rebuild with `tools/sync_gamesynth.sh`, which needs emsdk 4.0.20 and a pinned Rust nightly, see gamesynth/tools/build-wasm.sh).
Synth players use streamed playback because web builds play audio as browser samples by default.
All music tracks are included in the web build.

    godot --headless --path . --export-release "Web" build/web/index.html
    python3 tools/serve_web.py 8060      # then open http://127.0.0.1:8060/index.html

Export templates for 4.7.2 must be installed first (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`).

## License

Code is MIT licensed (see `LICENSE`). The ship models, logo and soundtrack were generated with AI
tools for this project; they are included so the game runs as-is, but treat them as project assets
rather than a reusable asset pack.
