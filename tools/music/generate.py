#!/usr/bin/env python3
"""Generate the AG Racer soundtrack with ACE-Step on the DGX Spark.

Reads tracks.json (same directory unless --spec says otherwise) and writes one
WAV per track into --out. Tracks that already exist are skipped, so a failed or
interrupted run can just be re-run.

    python generate.py --out ~/music-gen/out
    python generate.py --only 03_null_vector --duration 20   # quick audition
"""

import argparse
import json
import os
import time
from pathlib import Path

# ACE-Step is a text-to-music model; "[inst]" is its instrumental marker.
INSTRUMENTAL = "[inst]"


def patch_torchaudio_save() -> None:
    """Write audio with soundfile instead of TorchCodec.

    torchaudio >= 2.9 routes every save() through TorchCodec, which needs
    FFmpeg shared libraries the Spark doesn't have (and we can't apt-install
    without sudo). ACE-Step already asks for the "soundfile" backend, so honour
    that directly - libsndfile writes WAV with no FFmpeg involved.
    """
    import soundfile as sf
    import torchaudio

    def save(uri, src, sample_rate, **_ignored):
        data = src.detach().cpu().float()
        if data.ndim == 1:
            data = data.unsqueeze(0)
        # torchaudio is (channels, samples); soundfile wants (samples, channels).
        sf.write(str(uri), data.T.numpy(), int(sample_rate))

    torchaudio.save = save


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default=str(Path(__file__).with_name("tracks.json")))
    ap.add_argument("--out", default="out")
    ap.add_argument("--only", action="append", help="generate just this track (repeatable)")
    ap.add_argument("--duration", type=float, help="override every track's duration (for auditions)")
    ap.add_argument("--infer-step", type=int, help="override sampling steps (lower = faster/rougher)")
    ap.add_argument("--force", action="store_true", help="regenerate even if the file exists")
    args = ap.parse_args()

    spec = json.loads(Path(args.spec).read_text())
    defaults = spec.get("defaults", {})
    tracks = spec["tracks"]
    if args.only:
        wanted = set(args.only)
        tracks = [t for t in tracks if t["name"] in wanted]
        missing = wanted - {t["name"] for t in tracks}
        if missing:
            raise SystemExit(f"no such track(s) in spec: {', '.join(sorted(missing))}")
    if not tracks:
        raise SystemExit("nothing to generate")

    out_dir = Path(os.path.expanduser(args.out))
    out_dir.mkdir(parents=True, exist_ok=True)

    patch_torchaudio_save()
    from acestep.pipeline_ace_step import ACEStepPipeline

    print(f"loading ACE-Step (first run downloads ~10 GB of weights)...", flush=True)
    t0 = time.time()
    pipeline = ACEStepPipeline(dtype="bfloat16", torch_compile=False)
    print(f"pipeline ready in {time.time() - t0:.0f}s", flush=True)

    for track in tracks:
        dest = out_dir / f"{track['name']}.wav"
        if dest.exists() and not args.force:
            print(f"skip   {dest.name} (exists)", flush=True)
            continue

        duration = args.duration or track.get("duration", defaults.get("duration", 180))
        steps = args.infer_step or track.get("infer_step", defaults.get("infer_step", 60))
        print(f"\n=== {track['name']}  {duration:.0f}s  seed={track['seed']}  steps={steps}", flush=True)
        print(f"    {track['tags']}", flush=True)

        t0 = time.time()
        pipeline(
            format="wav",
            audio_duration=float(duration),
            prompt=track["tags"],
            lyrics=INSTRUMENTAL,
            infer_step=steps,
            guidance_scale=track.get("guidance_scale", defaults.get("guidance_scale", 15.0)),
            scheduler_type=track.get("scheduler_type", defaults.get("scheduler_type", "euler")),
            cfg_type=track.get("cfg_type", defaults.get("cfg_type", "apg")),
            omega_scale=track.get("omega_scale", defaults.get("omega_scale", 10.0)),
            manual_seeds=[int(track["seed"])],
            save_path=str(dest),
        )
        took = time.time() - t0
        size = dest.stat().st_size / 1e6 if dest.exists() else 0.0
        print(f"    -> {dest} ({size:.1f} MB) in {took:.0f}s "
              f"({duration / max(took, 1e-6):.2f}x realtime)", flush=True)

    print("\nall done", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
