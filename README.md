# Neon Velocity

Wipeout-style anti-gravity racer in Godot 4.7 (Forward+), set in a rain-soaked neon megacity.

Run: `godot --path .` (or open the folder in the editor).

Flow: title (attract-mode race behind it) → circuit select (speed class, a single race or the
championship) → a camera sweep over the grid → 3-lap race against 4 AI → results with score →
high-score table (top 10 per circuit and class, initials entry, saved in `user://highscores.json`).

**Controls** — keyboard: W/S thrust/brake, A/D steer, Q/E airbrakes, R respawn, Esc pause.
PlayStation controller (DualShock 4 / DualSense over USB or Bluetooth): R2 thrust, L2 brake, ✕ also thrusts,
left stick steer, L1/R1 airbrakes, △ respawn, Options pause, ✕ confirm / ○ back in menus, D-pad or stick to navigate.
Rumble on wall hits and boost pads. Double-tap an airbrake to side-shift that way.

**Speed classes** (`Game.CLASSES`): Pulse, Surge (the standard) and Hyper. A class rescales time, not the
handling: every speed by `k`, every acceleration by `k²`, every rate by `k` (`Ship.apply_speed_class`,
`AIDriver.apply_speed_class`), so racing lines, jump arcs and braking points stay where they are and
everything just arrives sooner. Par times scale with it, and each class keeps its own tables
(`Game.table_key`; the standard class uses the plain circuit name, which is what older saves hold).

**Championship**: all four circuits in order in the chosen class, 10 / 7 / 5 / 3 / 1 points per finish
(none for an eliminated ship), standings on every results screen, and a Championship table at the end
scored as the race scores added up plus a bonus for the title. Level on points, the better result in
the latest round decides.

**Racecraft**: thrust in the last 0.4 s before the lights go green gives a boost start (the AI gets one
some of the time). Sitting 12 to 50 m behind another ship in its lane is a slipstream: up to 30% more
thrust and 7% more top speed, shown on the HUD and heard in the wind. A side-shift is a 15 m/s sideways
hop with a short cooldown. After the flag the ship flies itself on while the camera swings out to its
rear quarter and the field's times come in.

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
| **Chrome Riot** 4.0 km, 22 m wide | two 700 m straights, a sweeper with no outer wall, a wiggle into one hard stop | sunrise, a journey: waterfront city and grandstands, mountain tunnel, rail-less cliff road over a fjord, pine forest with a ravine jump, docks, lake causeway |
| **Solar Wake** 3.4 km | figure-eight; the bridge over the start straight has no rails and a gap in it | daylight, a harbour over water |

`setting` in a circuit's definition shapes the city (height above the streets, density, tower height, water);
`open_edges` removes walls from a stretch; `features` is the select screen's caption. The select screen draws the
focused circuit's outline (`scripts/track_preview.gd`), coloured by zone on landscape circuits.

A circuit with a `landscape` entry (Chrome Riot) gets real terrain instead of the endless city. `zones` splits the
lap into kinds (`city`, `mountain`, `cliff`, `forest`, `docks`, `causeway`, presets in `Landscape.KINDS`), each with
a profile per side of the road (flat shoulder width, drop or rise, wall, fade into the natural terrain) that blends
over ~40 frames into the next. Around that: a lake on the inside of the lap, hills and a ring of snow-capped
mountains outside, authored `peaks` and `basins`, and a ravine carved under every gap. The ground is clamped below
the banked road surface everywhere, so no terrain can poke through the track. The city only builds towers in city
zones, on the terrain; `scripts/scenery.gd` adds the forest, rocks and sea stacks, the arch, docks (containers,
cranes, tanks, smoking chimneys), grandstands with a crowd at the start line, boards, boats and a lighthouse. Fog
colour, density and valley mist follow the zone the player is in, and so do the crowd, shore and wind beds
(`ambience.gd`). Environment presets can override glow and the road's roughness and metallic for daylight
(`SUNRISE`), since the web renderer has no screen-space reflections and a shiny road glares.

## Layout

- `scripts/track_defs.gd` — the circuits: control points, width, banking, neon colour, boost pad positions.
- `scripts/track_builder.gd` — builds a closed banked track from a definition: floor, walls, neon edge strips, start line, boost pads, trimesh collider, starting grid, and the start gantry with its five light pods (`set_start_lights`). The road (`shaders/road.gdshader`) is panelled, painted and puddled procedurally; the barriers (`shaders/wall.gdshader`) carry a light tube with pulses running the way the lap goes, and amber chevrons march along the outside wall of a tight corner (`TrackBuilder.corner`, stored in the wall's vertex colour); pads and the start line share `shaders/track_marking.gdshader`.
- `scripts/landscape.gd` — terrain for landscape circuits: zones, distance field to the track, heights, heightmap collider (layer 2), water, streams, bridge piers, the mountain over the tunnel. `scripts/scenery.gd` — what stands on it. Shaders: `terrain`, `water`, `tree`, `container`, `crowd`.
- `scripts/city_builder.gd` + `shaders/` — Blade Runner megacity around the track: ~1300 towers in one MultiMesh with a procedural lit-window/grime facade shader (windows soften with distance; some towers carry corner neon, a lit crown or a blinking aircraft beacon), neon billboards, sodium street lights, sweeping searchlights, lanes of air traffic above and below the circuit (`shaders/traffic.gdshader`, one MultiMesh moved in the vertex shader), wet ground, rain following the camera.
- `shaders/sky.gdshader` — the sky: gradient, sun or moon disc from the scene's directional light, a cloud deck, stars. Set per time of day by the `clouds`, `cloud_lit`, `cloud_dark`, `stars`, `disc_*` keys of an env preset in `track_defs.gd`. It has no `TIME`, so the radiance map is built once.
- `scripts/post_fx.gd` + `shaders/post_fx.gdshader` — the speed pass between the 3D view and the HUD: radial streaking from the vanishing point with speed, colour fringes on a boost, a torn frame on a weapon hit, a vignette. "Speed effects" in the settings turns it off.
- `scripts/ribbon_trail.gd` — the light trails behind every engine and rocket (a world-space ribbon rebuilt each frame); `scripts/fx.gd` — shared small effects: hover glow on the road, shock rings (boosts, pickups), wall sparks. `shaders/shield.gdshader` is the shield bubble.
- `models/ships/*.glb` — the ship models (player + four AI), designed externally; see `models/ships/README.md` for the drop-in spec. `scripts/ship.gd` swaps them in for the placeholder hull and attaches exhausts to their `EngineL`/`EngineR` empties.
- `scripts/title.gd` — title + circuit select over an attract-mode race; `scripts/highscore_screen.gd` + `scripts/highscores.gd` — initials entry and persisted tables; `scripts/results.gd`, `scripts/pause_menu.gd` — overlays; `scripts/ui_theme.gd` — shared neon UI helpers.
- `scripts/settings.gd` — autoload: volumes (master, music, effects, engines; engines get their own bus), fullscreen, 3D resolution, rumble, camera shake, controls help; saved in `user://settings.cfg`. `scripts/settings_menu.gd` and `scripts/credits_menu.gd` are overlays (`overlay_menu.gd`) opened from circuit select, settings also from the pause menu; `scripts/setting_row.gd` is the neon slider / choice row. Credits text lives in `CreditsMenu.CREDITS`. Credits opens `scripts/licences_menu.gd`, which assembles the licence page at runtime: the game's licence, Godot's licence text and its bundled components (`Engine.get_copyright_info()`), the Rust crates in gamesynth (`addons/gamesynth/THIRD_PARTY.txt`, regenerated by `tools/sync_gamesynth.sh`) and the font's OFL text.
- `scripts/game.gd` — autoload: scene flow, scoring, speed classes, the championship, `attract` mode, controller name (`AG_TRACK=<n>` env picks a circuit for headless runs).
- `scripts/ship.gd` — hover controller: raycast hover spring, thrust/drag, lateral grip, airbrakes, boost, wall scrape. Reads inputs a driver child writes. All tuning exported.
- `scripts/player_driver.gd` — keyboard/gamepad → ship.
- `scripts/engine_audio.gd` — per-ship engine sound on a positional player with Doppler. Uses the gamesynth `JetEngineStream` (procedural turbine driven by throttle/boost/speed/damage) when the extension is present, else synthesised loops.
- `scripts/sfx.gd` — one-shots: a WAV in `audio/sfx/` wins, else a gamesynth event generator shaped by power and distance, else a hand-made patch, else a built-in WAV. `scripts/ambience.gd` — rain, wind and the pit-lane recharge hum. See `AUDIO.md`.
- `addons/gamesynth/` — the [gamesynth](../gamesynth) GDExtension (Rust). Binary is gitignored; rebuild and copy it with `tools/sync_gamesynth.sh`.
- `scripts/ai_driver.gd` — follows the centre line (with a lane offset), airbrakes into corners; `skill` scales top speed.
- `scripts/race.gd` — spawns the grid (4 AI + player), countdown, laps, positions, finish, results, pause, rumble; also the combat referee (pickups, launches, pit recharge, eliminations).
- `scripts/items.gd`, `scripts/projectile.gd`, `scripts/explosion.gd` — pickups and their position-weighted roll; rockets, missiles and mines in track coordinates (`TrackBuilder.get_point`); one-shot blast effect.
- `scripts/chase_camera.gd` — camera that rolls with the banking, speed-independent follow; also the sweep over the grid before the countdown (`play_intro`) and the rear-quarter view after the flag (`orbit`).
- `scripts/voice.gd` — autoload: the announcer. Plays `audio/voice/<line>.ogg` one line at a time on its own `Voice` bus and dips the music under it. The lines are made with VoxCPM2 on the Spark by `tools/voice/make_voice.sh` and are optional (see `audio/voice/README.md`).
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

`tools/mix_probe.tscn` records each audio bus separately during an autopilot race so the mix can be measured in
LUFS (see "The mix" in `AUDIO.md`); `AG_NO_AMBIENCE=1` turns the rain, wind and recharge beds off.

`tools/perf_probe.tscn` races on autopilot, restarting on the next circuit after each race, and logs frame rate,
frame times, object / node / resource counts, memory and live sound players every 10 s. Rising counts mean a leak;
flat counts with a falling frame rate mean the GPU is throttling. Headless is enough for the counts:

    AG_AUTOPILOT=1 AG_NO_MUSIC=1 godot --headless --path . --fixed-fps 60 --quit-after 36000 tools/perf_probe.tscn

`tools/track_stats.gd` prints each circuit's shape (share of left and right turning, direction changes, tightest
radius, longest straight) and writes outlines for `python3 tools/plot_tracks.py`, a top-down plot.

Check that no circuit folds back on itself (a bridge is fine), and that both walls actually stop a ship:

    godot --headless --path . -s tools/check_tracks.gd
    godot --headless --path . -s tools/check_walls.gd

On landscape circuits, check that the terrain stays at least 1 m below the road across its full width and below
the wall tops, that no scenery (rocks, trees, the arch, boards: none of it collides) reaches into the space the
ships drive through, and render a set of viewpoints around the lap (overview plus 12 views, HUD hidden) to look at:

    godot --headless --path . -s tools/check_landscape.gd
    godot --headless --path . -s tools/check_scenery.gd
    AG_TRACK=2 godot --path . --write-movie out/views.avi --fixed-fps 10 --quit-after 200 tools/landscape_views.tscn

`AG_LANDSCAPE_LOG=1` prints the terrain grid size, build times and scenery counts.

`AG_CLASS=<0..2>` picks the speed class, `AG_LAPS=<n>` the race length, `AG_CHAMP=1` makes a directly loaded
race round one of a championship, `AG_INTRO=1` plays the grid sweep even on autopilot, and `AG_SELECT=1` opens
the title on the circuit select page. `tools/flow_probe.tscn` plays a whole championship on autopilot and prints
each round's standings and the final table entry:

    AG_AUTOPILOT=1 AG_NO_MUSIC=1 AG_LAPS=1 godot --headless --path . --fixed-fps 60 tools/flow_probe.tscn

`AG_ENERGY=40` starts every ship at that energy (pit stops, low-energy warnings).
`AG_COMBAT_LOG=1` prints every pickup use, hit, pit entry, jump (airtime, height, touchdown speed), rescue and elimination with race time, for balancing in a headless sim.
`AG_NO_MUSIC=1` silences the soundtrack so engine and SFX can be judged alone; `AG_NO_EXHAUST=1` hides the
afterburners. `tools/flame_test.tscn` is a side-view rig for tuning the exhaust:

    godot --path . --write-movie out/flame.avi --fixed-fps 30 --quit-after 90 tools/flame_test.tscn

New audio/art files need an import pass before a headless run can `load()` them:

    godot --headless --path . --import

## Audio

Buses are `Master` -> `Music` (low-pass, driven by ship speed and closed down behind the pause menu),
`Master` -> `SFX`, and `Engines` and `Voice` (the announcer), which `Settings` adds at startup so each
has its own slider.

Regenerate the soundtrack:

    ssh spark 'cd music-gen && .venv/bin/python generate.py --out out'
    tools/music/fetch.sh

## Web build

Exports with the `Web` preset in `export_presets.cfg` (single-threaded, so it runs on any static host,
GitHub Pages included). The web platform uses the Compatibility renderer, so volumetric fog, SSR and FSR
are absent there; `project.godot` carries `.web` overrides for the settings that only exist in Forward+.
The gamesynth extension is included as WebAssembly (`addons/gamesynth/bin/brusverk_godot.wasm`, tracked in git so CI can
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

A third argument picks the circuit (`3` for Chrome Riot). The gamesynth "command queue full" warnings in the
console come from the headless browser not playing audio, not from the game.

Export templates for 4.7.2 must be installed first (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`).

## License

Code is MIT licensed (see `LICENSE`). The ship models, logo and soundtrack were generated with AI
tools for this project; they are included so the game runs as-is, but treat them as project assets
rather than a reusable asset pack.
