#!/usr/bin/env bash
# Pull generated tracks off the Spark, master them, and drop them into the game.
#
#   tools/music/fetch.sh            # fetch, normalise, install into audio/music/
#   KEEP_WAV=1 tools/music/fetch.sh # also keep the raw WAVs in tools/music/raw/
#   SPARK_OUT=music-gen/out_fire tools/music/fetch.sh   # a different output folder on the Spark
#   SRC_DIR=/some/dir tools/music/fetch.sh              # master WAVs already on this machine
#                                                       # (rename them first to install under other names)
#
# Mastering is deliberately light: EBU R128 loudness normalisation to -14 LUFS
# with a true-peak ceiling of -1 dBTP, so tracks sit at a consistent level
# against engine SFX and don't clip, plus short fades so a crossfade never
# catches a hard edge.
set -euo pipefail

HOST="${SPARK_HOST:-spark}"
REMOTE_DIR="${SPARK_OUT:-music-gen/out}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
RAW="$HERE/raw"
DEST="$PROJECT/audio/music"

TARGET_LUFS="${TARGET_LUFS:--14}"
FADE="${FADE:-1.5}"          # seconds of fade in/out

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }

mkdir -p "$RAW" "$DEST"
if [ -n "${SRC_DIR:-}" ]; then
  echo "==> mastering local WAVs from $SRC_DIR"
  RAW="$SRC_DIR"
  KEEP_WAV=1
else
  echo "==> fetching WAVs from $HOST:$REMOTE_DIR"
  rsync -a --progress --include='*.wav' --exclude='*' "$HOST:$REMOTE_DIR/" "$RAW/"
fi

shopt -s nullglob
wavs=("$RAW"/*.wav)
if [ ${#wavs[@]} -eq 0 ]; then
  echo "no WAVs found — has the generation run finished?" >&2
  exit 1
fi

for src in "${wavs[@]}"; do
  name="$(basename "$src" .wav)"
  out="$DEST/$name.ogg"
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")
  fade_start=$(python3 -c "print(max(0, $dur - $FADE))")
  echo "==> mastering $name (${dur%.*}s)"

  # Two-pass loudnorm. A single pass only estimates the correction as it goes
  # and lands 1-2 LU off, which would leave tracks at audibly different levels.
  # Pass 1 measures, pass 2 applies the measured values for a real match.
  measured=$(ffmpeg -hide_banner -nostats -i "$src" \
    -af "loudnorm=I=${TARGET_LUFS}:TP=-1.0:LRA=11:print_format=json" \
    -f null - 2>&1 | sed -n '/^{/,/^}/p')

  read -r m_i m_tp m_lra m_thresh m_offset <<<"$(python3 -c "
import json,sys
m = json.loads(sys.stdin.read())
print(m['input_i'], m['input_tp'], m['input_lra'], m['input_thresh'], m['target_offset'])
" <<<"$measured")"

  ffmpeg -hide_banner -loglevel error -y -i "$src" \
    -af "loudnorm=I=${TARGET_LUFS}:TP=-1.0:LRA=11:measured_I=${m_i}:measured_TP=${m_tp}:measured_LRA=${m_lra}:measured_thresh=${m_thresh}:offset=${m_offset}:linear=true,afade=t=in:st=0:d=${FADE},afade=t=out:st=${fade_start}:d=${FADE}" \
    -c:a libvorbis -q:a 6 -ar 44100 \
    "$out"
done

if [ "${KEEP_WAV:-0}" != "1" ]; then
  rm -rf "$RAW"
fi

echo
echo "==> installed into $DEST"
ls -lh "$DEST"
echo
echo "Godot picks these up automatically via the Music autoload (scripts/music.gd)."
