# AG Racer

Wipeout-style anti-gravity racer prototype in Godot 4.7 (Forward+).

Run: `godot --path .` (or open the folder in the editor).
W/S thrust/brake, A/D steer, Q/E airbrakes, R respawn (restart after finishing), Esc quit.
Gamepad: right trigger thrust, left trigger brake, left stick steer, shoulders airbrake.

## Layout

- `scripts/track_builder.gd` — closed banked track generated from `CONTROL_POINTS` (~2.3 km lap): floor, walls, neon edge strips, start line, boost pads, trimesh collider, starting grid. `@tool`: edit the points and hit *Rebuild* in the inspector.
- `scripts/ship.gd` — hover controller: raycast hover spring, thrust/drag, lateral grip, airbrakes, boost, wall scrape. Reads inputs a driver child writes. All tuning exported.
- `scripts/player_driver.gd` — keyboard/gamepad → ship.
- `scripts/engine_audio.gd` — per-ship layered engine sound (drone, turbine, exhaust, airbrake hiss, boost, impacts) on positional players with Doppler. Loops are synthesised at startup; replace with samples later.
- `scripts/ai_driver.gd` — follows the centre line (with a lane offset), airbrakes into corners; `skill` scales top speed.
- `scripts/race.gd` — spawns the grid (4 AI + player), countdown, laps, positions, finish.
- `scripts/chase_camera.gd`, `scripts/hud.gd` — camera that rolls with the banking; speed / position / lap / best lap / countdown.
- `scripts/music.gd` — autoload; shuffles and crossfades any ogg/wav/mp3 in `audio/music/`, and low-passes the mix at low speed (`Music.attach_ship`).
- `tools/music/` — soundtrack generation with ACE-Step on the DGX Spark, plus mastering. See `tools/music/README.md`.

## Dev

Record a clip without a player (AI drives the player ship):

    AG_AUTOPILOT=1 godot --path . --write-movie out/f.png --fixed-fps 30 --quit-after 300

Simulate a full race headless, as fast as possible, printing lap times:

    AG_AUTOPILOT=1 godot --headless --path . --fixed-fps 60 --quit-after 5400

New audio/art files need an import pass before a headless run can `load()` them:

    godot --headless --path . --import

## Audio

Buses are `Master` -> `Music` (low-pass, driven by ship speed) and `Master` -> `SFX`
(engine audio), defined in `default_bus_layout.tres`.

Regenerate the soundtrack:

    ssh spark 'cd music-gen && .venv/bin/python generate.py --out out'
    tools/music/fetch.sh
