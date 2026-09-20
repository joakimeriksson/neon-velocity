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

**Air**: the hover keeps vertical momentum. It pushes up as hard as needed but pulls down only a little
(`track_pull` on the ship), so crests and drops (`relief` in `track_defs.gd`, snapped to the straightest stretch nearby)
throw a fast ship 4-6 m into the air, over the 2.5 m walls if you steer wrong. Thrust and grip are reduced in flight,
the nose follows the flight path, hard landings cost energy, and a ship over the wall or under the road is rescued
back onto the track at a standstill after 0.8 s.

**Gaps and tunnels**: a `gap` in `relief` is a kicker ramp that ends in open air, with the road resuming further on:
clear it or fall and be rescued on the far side. The builder places each feature where a straight flight strays least
from the road and refuses a gap that doesn't fit (Undertow is too twisty for one). `tunnels` roofs a stretch with a
faceted shell, neon ribs and shoulder light lines; inside, the rain stops and the SFX bus gets reverb.

**Scoring**: position points (1000 / 700 / 500 / 350 / 200) + 25 per second under the circuit's par time
(`par_lap` × 3 in `track_defs.gd`) + 250 for a lap under 97% of par + 75 per weapon hit landed and 250 per rival eliminated. Being eliminated scores 0.

Circuits (`scripts/track_defs.gd`), each a different kind of drive in a different setting:

| Circuit | Layout | Setting |
|---|---|---|
| **Neon Descent** 3.0 km | flowing loop with one S-bend, gap jump right after the start, tunnel, drop | night, rain, the city at mid height |
| **Undertow** 2.2 km, 14 m wide | hairpins and chicanes, long tunnel; too twisty for a gap | dusk, down in a street canyon between close towers |
| **Chrome Riot** 4.0 km, 22 m wide | two 700 m straights, a sweeper with no outer wall, a wiggle into one hard stop | grey dawn, 150 m above the skyline |
| **Solar Wake** 3.4 km | figure-eight; the bridge over the start straight has no rails and a gap in it | daylight, a harbour over water |

`setting` in a circuit's definition shapes the city (height above the streets, density, tower height, water);
`open_edges` removes walls from a stretch; `features` is the select screen's caption. The select screen draws the
focused circuit's outline (`scripts/track_preview.gd`).

## Layout

- `scripts/track_defs.gd` — the circuits: control points, width, banking, neon colour, boost pad positions.
- `scripts/track_builder.gd` — builds a closed banked track from a definition: floor, walls, neon edge strips, start line, boost pads, trimesh collider, starting grid.
- `scripts/city_builder.gd` + `shaders/` — Blade Runner megacity around the track: ~1300 towers in one MultiMesh with a procedural lit-window/grime facade shader, neon billboards, sodium street lights, sweeping searchlights, wet ground, rain following the camera.
- `models/ships/*.glb` — the ship models (player + four AI), designed externally; see `models/ships/README.md` for the drop-in spec. `scripts/ship.gd` swaps them in for the placeholder hull and attaches exhausts to their `EngineL`/`EngineR` empties.
- `scripts/title.gd` — title + circuit select over an attract-mode race; `scripts/highscore_screen.gd` + `scripts/highscores.gd` — initials entry and persisted tables; `scripts/results.gd`, `scripts/pause_menu.gd` — overlays; `scripts/ui_theme.gd` — shared neon UI helpers.
- `scripts/settings.gd` — autoload: volumes (master, music, effects, engines; engines get their own bus), fullscreen, 3D resolution, rumble, camera shake, controls help; saved in `user://settings.cfg`. `scripts/settings_menu.gd` and `scripts/credits_menu.gd` are overlays (`overlay_menu.gd`) opened from circuit select, settings also from the pause menu; `scripts/setting_row.gd` is the neon slider / choice row. Credits text lives in `CreditsMenu.CREDITS`. Credits opens `scripts/licences_menu.gd`, which assembles the licence page at runtime: the game's licence, Godot's licence text and its bundled components (`Engine.get_copyright_info()`), the Rust crates in gamesynth (`addons/gamesynth/THIRD_PARTY.txt`, regenerated by `tools/sync_gamesynth.sh`) and the font's OFL text.
- `scripts/game.gd` — autoload: scene flow, scoring, `attract` mode, controller name (`AG_TRACK=<n>` env picks a circuit for headless runs).
- `scripts/ship.gd` — hover controller: raycast hover spring, thrust/drag, lateral grip, airbrakes, boost, wall scrape. Reads inputs a driver child writes. All tuning exported.
- `scripts/player_driver.gd` — keyboard/gamepad → ship.
- `scripts/engine_audio.gd` — per-ship engine sound on a positional player with Doppler. Uses the gamesynth `JetEngineStream` (procedural turbine driven by throttle/boost/speed/damage) when the extension is present, else synthesised loops.
- `scripts/sfx.gd` — one-shots: a WAV in `audio/sfx/` wins, else a gamesynth event generator shaped by power and distance, else a hand-made patch, else a built-in WAV. `scripts/ambience.gd` — rain, wind and the pit-lane recharge hum. See `AUDIO.md`.
- `addons/gamesynth/` — the [gamesynth](../gamesynth) GDExtension (Rust). Binary is gitignored; rebuild and copy it with `tools/sync_gamesynth.sh`.
- `scripts/ai_driver.gd` — follows the centre line (with a lane offset), airbrakes into corners; `skill` scales top speed.
- `scripts/race.gd` — spawns the grid (4 AI + player), countdown, laps, positions, finish, results, pause, rumble; also the combat referee (pickups, launches, pit recharge, eliminations).
- `scripts/items.gd`, `scripts/projectile.gd`, `scripts/explosion.gd` — pickups and their position-weighted roll; rockets, missiles and mines in track coordinates (`TrackBuilder.get_point`); one-shot blast effect.
- `scripts/chase_camera.gd` — camera that rolls with the banking, speed-independent follow.
- `scripts/hud.gd` + `scripts/hud_canvas.gd` — the HUD. `hud.gd` holds state, timers and warning sounds; `hud_canvas.gd` draws everything as neon glass tubes in `_draw()` (energy tube under the ship that sputters when low and blinks out when hit, item icons, fixed-cell lap digits, pit prompt with chevrons, hit vignette). Type is Saira Condensed (`assets/fonts/`, OFL), also the project-wide UI font.
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

`tools/perf_probe.tscn` races on autopilot, restarting on the next circuit after each race, and logs frame rate,
frame times, object / node / resource counts, memory and live sound players every 10 s. Rising counts mean a leak;
flat counts with a falling frame rate mean the GPU is throttling. Headless is enough for the counts:

    AG_AUTOPILOT=1 AG_NO_MUSIC=1 godot --headless --path . --fixed-fps 60 --quit-after 36000 tools/perf_probe.tscn

`tools/track_stats.gd` prints each circuit's shape (share of left and right turning, direction changes, tightest
radius, longest straight) and writes outlines for `python3 tools/plot_tracks.py`, a top-down plot.

Check that no circuit folds back on itself (a bridge is fine), and that both walls actually stop a ship:

    godot --headless --path . -s tools/check_tracks.gd
    godot --headless --path . -s tools/check_walls.gd

`AG_ENERGY=40` starts every ship at that energy (pit stops, low-energy warnings).
`AG_COMBAT_LOG=1` prints every pickup use, hit, pit entry, jump (airtime, height, touchdown speed), rescue and elimination with race time, for balancing in a headless sim.
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

Smoke test without a visible browser (boots it, starts a race, saves the console and two screenshots).
`--mute-audio` matters: otherwise the invisible browser plays the game through your speakers.

    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --mute-audio \
        --remote-debugging-port=9222 --use-angle=swiftshader --enable-unsafe-swiftshader about:blank &
    node tools/web_smoke.mjs http://127.0.0.1:8060/index.html out/web_smoke

Export templates for 4.7.2 must be installed first (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`).

## License

Code is MIT licensed (see `LICENSE`). The ship models, logo and soundtrack were generated with AI
tools for this project; they are included so the game runs as-is, but treat them as project assets
rather than a reusable asset pack.
