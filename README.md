# AG Racer

Wipeout-style anti-gravity racer prototype in Godot 4.7 (Forward+).

Run: `godot --path .` (or open the folder in the editor). Pick a circuit with 1/2/3.
W/S thrust/brake, A/D steer, Q/E airbrakes, R respawn (restart after finishing), Esc back to menu.

Circuits (`scripts/track_defs.gd`): **Neon Descent** (flowing, 2.6 km), **Undertow** (narrow and
technical, 1.9 km), **Chrome Riot** (wide and fast, 3.5 km). The city around them is procedural.
Gamepad: right trigger thrust, left trigger brake, left stick steer, shoulders airbrake.

## Layout

- `scripts/track_defs.gd` — the circuits: control points, width, banking, neon colour, boost pad positions.
- `scripts/track_builder.gd` — builds a closed banked track from a definition: floor, walls, neon edge strips, start line, boost pads, trimesh collider, starting grid.
- `scripts/city_builder.gd` + `shaders/` — Blade Runner megacity around the track: ~1300 towers in one MultiMesh with a procedural lit-window/grime facade shader, neon billboards, sodium street lights, sweeping searchlights, wet ground, rain following the camera.
- `scripts/menu.gd`, `scripts/game.gd` — circuit select and cross-scene state (`AG_TRACK=<n>` env picks a circuit for headless runs).
- `scripts/ship.gd` — hover controller: raycast hover spring, thrust/drag, lateral grip, airbrakes, boost, wall scrape. Reads inputs a driver child writes. All tuning exported.
- `scripts/player_driver.gd` — keyboard/gamepad → ship.
- `scripts/engine_audio.gd` — per-ship layered engine sound (drone, turbine, exhaust, airbrake hiss, boost, impacts) on positional players with Doppler. Loops are synthesised at startup; replace with samples later.
- `scripts/ai_driver.gd` — follows the centre line (with a lane offset), airbrakes into corners; `skill` scales top speed.
- `scripts/race.gd` — spawns the grid (4 AI + player), countdown, laps, positions, finish.
- `scripts/chase_camera.gd`, `scripts/hud.gd` — camera that rolls with the banking; speed / position / lap / best lap / countdown.
- `scripts/music.gd` — autoload; shuffles and crossfades any ogg/wav/mp3 in `audio/music/`, and low-passes the mix at low speed (`Music.attach_ship`).
- `tools/music/` — soundtrack generation with ACE-Step on the DGX Spark, plus mastering. See `tools/music/README.md`.

## Dev

Record a clip without a player (AI drives the player ship). Pass the race scene explicitly, the main scene is the menu.
Use the AVI writer (real-time speed; PNG is ~30x slower) and keep the window uncovered: macOS stops
an occluded window from drawing and the writer just repeats the last frame. `--always-on-top` helps.

    AG_TRACK=1 AG_AUTOPILOT=1 godot --path . --always-on-top --write-movie out/clip.avi --fixed-fps 30 --quit-after 900 scenes/main.tscn
    ffmpeg -i out/clip.avi -c:v libx264 -crf 19 -pix_fmt yuv420p -c:a aac out/clip.mp4

Godot's closing "N frames" line should equal --quit-after; fewer means frames were dropped while occluded.

Simulate a full race headless, as fast as possible, printing lap times:

    AG_TRACK=0 AG_AUTOPILOT=1 godot --headless --path . --fixed-fps 60 --quit-after 5400 scenes/main.tscn

Check that no circuit folds back on itself:

    godot --headless --path . -s tools/check_tracks.gd

New audio/art files need an import pass before a headless run can `load()` them:

    godot --headless --path . --import

## Audio

Buses are `Master` -> `Music` (low-pass, driven by ship speed) and `Master` -> `SFX`
(engine audio), defined in `default_bus_layout.tres`.

Regenerate the soundtrack:

    ssh spark 'cd music-gen && .venv/bin/python generate.py --out out'
    tools/music/fetch.sh
