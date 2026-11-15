# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["mlx-whisper", "numpy", "soundfile"]
# ///
"""Choose the take of every announcer line that says the right words, and make it game-ready
(on the Mac; tools/voice/make_voice.sh calls this).

    uv run tools/voice/pick_takes.py audition DIR
        Scores the audition takes against the audition line; writes DIR/heard.json.

    uv run tools/voice/pick_takes.py bank BANK_DIR DEST_DIR [--dry]
        For each line of tools/voice/lines.txt: Whisper transcribes the takes, the one that
        says the words (and nothing more) wins, its silence is trimmed, it gets a light
        public-address treatment (--dry leaves that out), a common loudness, and is written
        to DEST_DIR/<id>.ogg. Lines where no take is right are listed, to be made again.
"""
import argparse, difflib, json, os, re, subprocess, tempfile

import numpy as np
import soundfile as sf
import mlx_whisper

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = "mlx-community/whisper-small.en-mlx"
TARGET_RMS_DB = -19.0     # loudness of the speech itself, the same for every line
PEAK = 0.7                # -3 dBFS ceiling
GATE_DB = -42.0           # below this, the start and end of a take count as silence
PA = ("highpass=f=110,acompressor=threshold=-20dB:ratio=3:attack=5:release=120:makeup=2,"
      "aecho=0.85:0.6:70|130:0.2|0.09,apad=pad_dur=0.2")
SAME = {"1": "one", "2": "two", "3": "three", "won": "one", "to": "two", "too": "two",
        "1st": "first", "2nd": "second", "3rd": "third", "4th": "fourth", "5th": "fifth"}


def norm(text):
    """Letters only, numbers as words, so 'Under tow' and 'Undertow' compare equal."""
    words = re.sub(r"[^a-z0-9 ]", " ", text.lower()).split()
    return "".join(SAME.get(w, w) for w in words)


def score(said, wanted):
    a, b = norm(said), norm(wanted)
    return difflib.SequenceMatcher(None, a, b).ratio() if a or b else 0.0


def read_lines():
    out = []
    for raw in open(os.path.join(HERE, "lines.txt"), encoding="utf-8"):
        raw = raw.strip()
        if raw and not raw.startswith("#"):
            parts = raw.split("|")
            out.append((parts[0], parts[1]))
    return out


class Ear:
    """Whisper, with what it heard kept beside the takes so a second run is quick."""

    def __init__(self, folder):
        self.folder = folder
        self.cache = os.path.join(folder, "heard.json")
        self.heard = json.load(open(self.cache)) if os.path.exists(self.cache) else {}

    def hear(self, name):
        if name not in self.heard:
            path = os.path.join(self.folder, name)
            self.heard[name] = mlx_whisper.transcribe(path, path_or_hf_repo=MODEL, language="en")["text"].strip()
        return self.heard[name]

    def save(self):
        json.dump(self.heard, open(self.cache, "w"), indent=0)


def trim(wav, sr):
    frame = int(sr * 0.01)
    n = len(wav) // frame
    level = 20 * np.log10(np.sqrt(np.mean(wav[: n * frame].reshape(n, frame) ** 2, axis=1)) + 1e-9)
    loud = np.where(level > GATE_DB)[0]
    if len(loud) == 0:
        return wav
    a = max(loud[0] * frame - int(sr * 0.02), 0)
    b = min((loud[-1] + 1) * frame + int(sr * 0.08), len(wav))
    out = wav[a:b].copy()
    fade = int(sr * 0.01)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def level(wav, sr):
    frame = int(sr * 0.02)
    n = len(wav) // frame
    rms = np.sqrt(np.mean(wav[: n * frame].reshape(n, frame) ** 2, axis=1))
    speech = rms[rms > np.percentile(rms, 40)] if n > 3 else rms
    now = 20 * np.log10(np.sqrt(np.mean(speech ** 2)) + 1e-9)
    out = wav * 10 ** ((TARGET_RMS_DB - now) / 20)
    peak = np.max(np.abs(out))
    return out * (PEAK / peak) if peak > PEAK else out


def audition(folder):
    info = json.load(open(os.path.join(folder, "voices.json")))
    ear = Ear(folder)
    for f in sorted(os.listdir(folder)):
        if f.endswith(".wav"):
            said = ear.hear(f)
            print(f"{f:16s} {score(said, info['line']):4.2f}  {said}", flush=True)
    ear.save()


def bank(folder, dest, dry):
    os.makedirs(dest, exist_ok=True)
    ear = Ear(folder)
    bad = []
    for pid, text in read_lines():
        takes = sorted(f for f in os.listdir(folder) if re.fullmatch(re.escape(pid) + r"_\d+\.wav", f))
        if not takes:
            bad.append((pid, "no takes", ""))
            continue
        best = None
        for f in takes:
            said = ear.hear(f)
            s = score(said, text)
            # Between takes that say it equally well, the shorter one (no stray noises).
            key = (round(s, 2), -sf.info(os.path.join(folder, f)).frames)
            if best is None or key > best[0]:
                best = (key, f, said, s)
        _, f, said, s = best
        wav, sr = sf.read(os.path.join(folder, f), dtype="float32")
        wav = trim(wav, sr)
        with tempfile.TemporaryDirectory() as tmp:
            a, b, c = (os.path.join(tmp, n) for n in ("a.wav", "b.wav", "c.wav"))
            sf.write(a, wav, sr)
            if not dry:
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", a, "-af", PA, b], check=True)
                wav, sr = sf.read(b, dtype="float32")
            sf.write(c, level(wav, sr), sr)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", c, "-ar", "44100", "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "5", os.path.join(dest, pid + ".ogg")], check=True)
        mark = "" if s >= 0.85 else "   <-- check"
        print(f"{pid:12s} {f:18s} {s:4.2f}  {said}{mark}", flush=True)
        if s < 0.85:
            bad.append((pid, f"{s:.2f}", said))
    ear.save()
    print(f"\n{len(bad)} lines to look at:")
    for b in bad:
        print("  ", *b)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audition")
    a.add_argument("folder")
    b = sub.add_parser("bank")
    b.add_argument("folder")
    b.add_argument("dest")
    b.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    if args.cmd == "audition":
        audition(args.folder)
    else:
        bank(args.folder, args.dest, args.dry)


if __name__ == "__main__":
    main()
