# Soundtrack generation

The AG Racer soundtrack is generated with [ACE-Step](https://github.com/ace-step/ACE-Step)
(Apache-2.0, 3.5B) running on the DGX Spark, then mastered and installed into
`audio/music/`, where the `Music` autoload picks it up automatically.

Roughly 40 seconds of GPU time per 3-minute track.

## One-time setup on the Spark

Already done on `gx10-e3fc` (host alias `spark` in `~/.ssh/config`), under
`~/music-gen/`. To rebuild it elsewhere:

```bash
python3 -m venv .venv
.venv/bin/pip install torch torchaudio torchvision --index-url https://download.pytorch.org/whl/cu130
git clone --depth 1 https://github.com/ace-step/ACE-Step.git
.venv/bin/pip install -c constraints.txt \
  "transformers==4.50.0" "diffusers>=0.33.0" spacy \
  "librosa==0.11.0" "soundfile==0.13.1" "py3langid==0.3.0" "pypinyin==0.53.0" \
  numpy scipy loguru tqdm accelerate peft hangul-romanize num2words
.venv/bin/pip install --no-deps -e ACE-Step
```

`constraints.txt` pins `torch==2.14.0+cu130` / `torchaudio==2.11.0+cu130` so a
transitive dependency can't swap in a CPU or wrong-CUDA build.

Three deviations from ACE-Step's `requirements.txt`, all forced by this machine:

- **`cutlet` / `fugashi` omitted.** Their `mojimoji` dependency has no aarch64
  wheel and fails to build. They're only used for Japanese lyric romanisation,
  which is imported lazily and never reached for instrumental tracks.
- **`py3langid` pinned to 0.3.0.** 0.4.0 removed
  `LanguageIdentifier.from_pickled_model`, which ACE-Step calls at load time.
- **`torchaudio.save` is monkeypatched** in `generate.py` to use `soundfile`.
  torchaudio >= 2.9 routes every save through TorchCodec, which needs FFmpeg
  shared libraries; there's no passwordless sudo on the Spark to install them.
  ACE-Step already requests the `soundfile` backend — the shim just honours it.

## Generating

`tracks.json` is the spec: one entry per track, with the prompt tags, seed and
duration. Editing tags is how you change the music; the seed makes a take
reproducible, so bump it to roll a different take of the same brief.

```bash
scp tools/music/generate.py tools/music/tracks.json spark:~/music-gen/
ssh spark 'cd music-gen && .venv/bin/python generate.py --out out'
```

Useful flags:

```bash
--only 03_null_vector      # one track (repeatable)
--duration 20              # short audition before committing to a full take
--infer-step 30            # faster, rougher
--force                    # regenerate over an existing file
```

Without `--force`, existing outputs are skipped, so an interrupted run resumes.

## Installing into the game

```bash
tools/music/fetch.sh
```

Pulls the WAVs, normalises each to −14 LUFS with a −1 dBTP ceiling (so tracks
sit consistently against engine SFX and don't clip), applies 1.5 s fades so a
crossfade never catches a hard edge, encodes to OGG Vorbis q6 at 44.1 kHz, and
writes them to `audio/music/`.

Overridable: `TARGET_LUFS`, `FADE`, `KEEP_WAV=1`, `SPARK_HOST`, `SPARK_OUT`.

## Playback

`scripts/music.gd` is an autoload (`Music`). It shuffles everything in
`audio/music/` and crossfades between tracks, starting the next one
`crossfade_time` before the current ends so they actually overlap.

`Music.attach_ship(ship)` — called from `race.gd` — drives a low-pass filter on
the `Music` bus from ship speed, so the mix is muffled on the grid and opens up
at top speed. Turn it off with `Music.speed_response = false`.
