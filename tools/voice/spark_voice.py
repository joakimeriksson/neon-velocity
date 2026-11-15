#!/usr/bin/env python3
"""The race announcer's voice, made with VoxCPM2 on the Spark (tools/voice/make_voice.sh
copies this file over and runs it there; ~/work/voxcpm-test/.venv has the model).

    spark_voice.py audition OUT_DIR [--takes 2] [--only voice,voice]
        Voice design: each voice in VOICES is a description, read over one audition line.
        Writes OUT_DIR/<voice>_<take>.wav and OUT_DIR/voices.json.

    spark_voice.py bank LINES.txt REF.wav OUT_DIR [--takes 3] [--only id,id]
        Every line of LINES.txt cloned from one audition take, so the whole set is one voice;
        the line's style goes in parentheses before the text. Writes OUT_DIR/<id>_<take>.wav.
        Existing files are kept: delete a take to have it made again.
"""
import argparse, json, os, time

import numpy as np
import soundfile as sf
from voxcpm import VoxCPM

VOICES = {
    "control": "A calm, cool female race control voice, precise and confident, futuristic public address system, British accent",
    "deep": "A deep, resonant male announcer, slow and authoritative, cinematic trailer voice",
    "hype": "An energetic male motor racing commentator, punchy and excited, powerful voice",
    "veteran": "A gravelly older male circuit announcer, dry, warm and authoritative, British accent",
    "bright": "A bright, confident young female sports announcer, energetic and clear, American accent",
    "system": "A smooth, neutral female ship computer voice, even and unhurried, slightly synthetic",
}

AUDITION_LINE = "Welcome to Neon Descent. Three. Two. One. Go! Final lap. New lap record. First place!"

STYLES = {
    "count": "firm, clipped and steady, counting down to the start of a race",
    "go": "a loud, excited shout",
    "call": "clear, confident and short, a public address announcement",
    "alert": "urgent and tense, a warning",
    "hype": "excited and triumphant, loud",
    "title": "big and dramatic, introducing a racing circuit",
}


def read_lines(path):
    out = []
    for raw in open(path, encoding="utf-8"):
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        parts = raw.split("|")
        out.append((parts[0], parts[1], parts[2] if len(parts) > 2 else "call"))
    return out


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audition")
    a.add_argument("out")
    a.add_argument("--takes", type=int, default=2)
    a.add_argument("--only", default="")
    b = sub.add_parser("bank")
    b.add_argument("lines")
    b.add_argument("ref")
    b.add_argument("out")
    b.add_argument("--takes", type=int, default=3)
    b.add_argument("--only", default="")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    only = set(args.only.split(",")) if args.only else None
    if args.cmd == "audition":
        jobs = [(name, f"({desc}){AUDITION_LINE}", {}) for name, desc in VOICES.items()]
        json.dump({"line": AUDITION_LINE, "voices": VOICES}, open(os.path.join(args.out, "voices.json"), "w"), indent=1)
    else:
        clone = dict(reference_wav_path=args.ref)
        jobs = [(pid, f"({STYLES[style]}){text}", clone) for pid, text, style in read_lines(args.lines)]
    jobs = [j for j in jobs if only is None or j[0] in only]

    model = VoxCPM.from_pretrained("openbmb/VoxCPM2", load_denoiser=False)
    sr = model.tts_model.sample_rate
    start = time.time()
    done = 0
    for name, text, extra in jobs:
        for take in range(1, args.takes + 1):
            path = os.path.join(args.out, f"{name}_{take}.wav")
            if os.path.exists(path):
                continue
            wav = model.generate(text=text, cfg_value=2.0, inference_timesteps=10, **extra)
            wav = np.asarray(wav, dtype=np.float32).reshape(-1)
            sf.write(path, wav, sr)
            done += 1
            print(f"{name}_{take}\t{len(wav) / sr:.2f}s\t{time.time() - start:.0f}s elapsed", flush=True)
    print(f"done: {done} files in {time.time() - start:.0f} s")


if __name__ == "__main__":
    main()
