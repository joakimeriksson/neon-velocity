#!/usr/bin/env python3
"""Top-down plot of every circuit from out/track_outlines.json (written by tools/track_stats.gd).
Colour is elevation; gaps are drawn red, tunnels white; the dot is the start line, the arrow the direction."""
import json, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import numpy as np

data = json.load(open("out/track_outlines.json"))
fig, axes = plt.subplots(1, len(data), figsize=(5.2 * len(data), 5.6), facecolor="#0b0d14")
for ax, (name, d) in zip(np.atleast_1d(axes), data.items()):
    p = np.array(d["points"])
    x, z, y = p[:, 0], -p[:, 1], p[:, 2]          # -z up the page, as seen from above
    pts = np.column_stack([x, z]).reshape(-1, 1, 2)
    segs = np.concatenate([pts, np.roll(pts, -1, axis=0)], axis=1)
    lc = LineCollection(segs, cmap="viridis", linewidths=max(2.0, d["width"] / 5.0))
    lc.set_array(y)
    ax.add_collection(lc)
    n = len(p)
    for a, b in d["gaps"]:
        idx = np.arange(a, b + 1) % n
        ax.plot(x[idx], z[idx], color="#ff4b3a", lw=6)
    for a, b in d["tunnels"]:
        idx = np.arange(a, b + 1) % n
        ax.plot(x[idx], z[idx], color="white", lw=1.5)
    ax.plot(x[0], z[0], "o", color="#ff3ec8", ms=9)
    ax.annotate("", xy=(x[25], z[25]), xytext=(x[0], z[0]), arrowprops=dict(arrowstyle="->", color="#ff3ec8", lw=2))
    ax.set_title(f"{name}  {n * 2} m   elev {y.min():.0f}..{y.max():.0f}", color="white")
    ax.set_aspect("equal"); ax.autoscale(); ax.margins(0.08)
    ax.set_facecolor("#0b0d14"); ax.tick_params(colors="#667")
    for s in ax.spines.values(): s.set_color("#334")
plt.tight_layout()
out = sys.argv[1] if len(sys.argv) > 1 else "out/tracks.png"
plt.savefig(out, dpi=70)
print("wrote", out)
