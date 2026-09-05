# Five concept racers

Installed asset mapping:

- `player.glb`: Needle — ivory/red spearhead
- `ai_0.glb`: Fork — yellow twin-prong
- `ai_1.glb`: Manta — teal/ivory delta
- `ai_2.glb`: Brute — orange heavy pods
- `ai_3.glb`: Wraith — purple/silver outriggers

The existing race loader uses these filenames automatically. No gameplay scripts
or project settings need modification. Restart the race after Godot imports the files.

Each GLB is scaled for the existing ship envelope, points along -Z, and includes
EngineL/EngineR/Headlight/Cockpit nodes. Materials are batched into 7–8 meshes per
ship. Original liveries are preserved rather than replaced by runtime team tint.

These are first-pass low-poly concept interpretations, with material colors and
coarse shapes rather than the concept art's detailed weathering and panel textures.
The game's current common collision shape remains active. Broad/short silhouettes
such as Manta occupy less of its length; tune collision later if precise contact matters.

`antigravity-reference/` contains the original concept, actual mesh previews, and
editable Python source. `antigravity-model-manifest.json` records actual bounds
and triangle counts for these game-scaled files.
