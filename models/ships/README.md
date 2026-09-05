# Ship models

Drop a `.glb` in this folder and reference it by name; the game replaces the placeholder box hull
with it and attaches exhausts, lights and collision automatically.

- `player.glb` — used for the player's ship if present.
- `ai_<n>.glb` (ai_0 … ai_3) — per-AI models, else `ai.glb` for all, else the placeholder.

## Spec for the modeller

- **Format**: glTF binary (`.glb`), PBR materials embedded, textures ≤ 2048 px.
- **Scale**: metres. Target ~4.5 m long, ~2.2 m wide, ~0.8 m tall (the hover collision box is 2.4 × 0.8 × 4.6).
- **Orientation**: nose along **−Z**, up **+Y**, right **+X**. Origin at the centre of the hull, at hover height
  (the ship floats ~1.3 m above the track; the origin is the hover point, so keep the belly at about −0.35 m).
- **Polygons**: 5–20 k triangles is plenty; it's seen from behind at 9 m.
- **Named empties** (optional but recommended), read by the game:
  - `EngineL`, `EngineR` — nozzle positions and facing (+Z is out of the nozzle). Afterburners attach here.
  - `Headlight` — where the forward light sits.
  - `Cockpit` — for a future cockpit camera.
  Without them, defaults are used: engines at (±0.65, 0, 2.3).
- **Team colour**: a material named `Accent` is tinted per team at runtime. Models that ship with their own
  designed livery (e.g. a `Team paint` material) are left exactly as authored.
- **Materials**: metallic ≤ 0.4 on the hull so it reads under lamps at night (fully metallic hulls go black).
  Emissive parts are fine — engine grilles, canopy strips — the game adds glow.
- **No animation needed.** No lights, cameras or particles in the file — the game adds those.
