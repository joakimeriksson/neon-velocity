#!/usr/bin/env python3
"""Write OUT/audition.html: every announcer voice side by side, to choose one by ear.
For each voice: its audition takes (the raw voice), then the lines as the game will play
them, if `make_voice.sh render <voice>` has been run. Plain files, opened from disk."""
import html, json, os, sys

OUT = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))

info = json.load(open(os.path.join(OUT, "audition", "voices.json")))
lines = []
for raw in open(os.path.join(HERE, "lines.txt"), encoding="utf-8"):
    raw = raw.strip()
    if raw and not raw.startswith("#"):
        lines.append(raw.split("|")[:2])
installed = ""
marker = os.path.join(HERE, "..", "..", "audio", "voice", "VOICE")
if os.path.exists(marker):
    installed = open(marker).read().strip()

parts = []
for voice, desc in info["voices"].items():
    takes = sorted(f for f in os.listdir(os.path.join(OUT, "audition")) if f.startswith(voice + "_") and f.endswith(".wav"))
    game = os.path.join(OUT, "game", voice)
    rows = ""
    if os.path.isdir(game):
        for pid, text in lines:
            if os.path.exists(os.path.join(game, pid + ".ogg")):
                rows += (f'<button class="line" data-src="game/{voice}/{pid}.ogg">{html.escape(text)}</button>')
        seq = ",".join(f"game/{voice}/{p}.ogg" for p in ["circuit_0", "3", "2", "1", "go"])
        rows = f'<button class="line seq" data-seq="{seq}">▶ Start of a race</button>' + rows
    else:
        rows = '<p class="none">Lines not rendered yet.</p>'
    auditions = "".join(
        f'<label>Audition take {t.rsplit("_", 1)[1][:-4]}<audio controls preload="none" src="audition/{t}"></audio></label>'
        for t in takes)
    tag = '<span class="tag">in the game now</span>' if voice == installed else ""
    parts.append(f"""
<section>
  <h2>{html.escape(voice)} {tag}</h2>
  <p class="desc">{html.escape(desc)}</p>
  <div class="auditions">{auditions}</div>
  <div class="lines">{rows}</div>
  <code>tools/voice/make_voice.sh install {html.escape(voice)}</code>
</section>""")

page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Announcer audition</title>
<style>
  :root {{ --bg: #0b0d14; --panel: #141826; --ink: #e8ecf6; --dim: #8b93a8; --line: #262c40; --accent: #36e0ff; --hot: #ff4fb0; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; padding: 32px 16px 64px; background: var(--bg); color: var(--ink);
         font: 15px/1.5 -apple-system, "Helvetica Neue", sans-serif; }}
  main {{ max-width: 860px; margin: 0 auto; }}
  h1 {{ font-size: 26px; letter-spacing: 0.04em; text-transform: uppercase; margin: 0 0 4px; }}
  .intro {{ color: var(--dim); margin: 0 0 28px; max-width: 62ch; }}
  section {{ background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 18px 20px; margin-bottom: 18px; }}
  h2 {{ margin: 0; font-size: 19px; text-transform: capitalize; color: var(--accent); }}
  .tag {{ font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--bg); background: var(--hot);
          border-radius: 4px; padding: 2px 7px; margin-left: 8px; vertical-align: 3px; }}
  .desc {{ color: var(--dim); margin: 2px 0 12px; }}
  .auditions {{ display: flex; flex-wrap: wrap; gap: 12px 20px; margin-bottom: 14px; }}
  label {{ display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: var(--dim); }}
  audio {{ height: 34px; width: 300px; max-width: 100%; }}
  .lines {{ display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 14px; }}
  .line {{ background: transparent; color: var(--ink); border: 1px solid var(--line); border-radius: 6px;
           padding: 5px 10px; font: inherit; font-size: 13px; cursor: pointer; }}
  .line:hover, .line:focus-visible {{ border-color: var(--accent); outline: none; }}
  .line.playing {{ border-color: var(--hot); color: var(--hot); }}
  .line.seq {{ border-color: var(--accent); color: var(--accent); }}
  .none {{ color: var(--dim); margin: 0; }}
  code {{ font: 12px ui-monospace, Menlo, monospace; color: var(--dim); user-select: all; }}
</style></head>
<body><main>
<h1>Announcer audition</h1>
<p class="intro">Each voice read the same line for the audition ("{html.escape(info["line"])}").
The buttons play the lines as the game plays them, cloned from audition take 1. To put a voice in the game, run the command under it.</p>
{"".join(parts)}
</main>
<script>
  const player = new Audio();
  let queue = [], lit = null;
  function next() {{
    if (!queue.length) {{ if (lit) lit.classList.remove("playing"); lit = null; return; }}
    player.src = queue.shift();
    player.play();
  }}
  player.addEventListener("ended", () => setTimeout(next, 450));
  document.querySelectorAll(".line").forEach(b => b.addEventListener("click", () => {{
    if (lit) lit.classList.remove("playing");
    lit = b; b.classList.add("playing");
    queue = b.dataset.seq ? b.dataset.seq.split(",") : [b.dataset.src];
    player.pause();
    next();
  }}));
</script>
</body></html>
"""
open(os.path.join(OUT, "audition.html"), "w", encoding="utf-8").write(page)
