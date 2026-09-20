#!/usr/bin/env bash
# Build one Finder-browsable folder holding every take ever generated for the game.
#
# The masters live on the Spark, one folder per generation run. This pulls them
# all, converts each to AAC/m4a (Quick Look plays it on spacebar; it can't play
# OGG or these 35 MB WAVs comfortably), and sorts them into one folder per run.
# Takes that are in the game right now get an "IN GAME" prefix.
#
#   tools/music/library.sh            # build/refresh and open in Finder
#   tools/music/library.sh --no-open
#
# Incremental: a take that is already converted is skipped.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
SPARK_HOST="${SPARK_HOST:-spark}"
DEST="$HERE/previews/library"
TMP="$DEST/.wav"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }

# Spark folder -> library folder. Newest first, so Finder's name sort reads as a
# timeline. out_td is left out: that set belongs to the tower-defence game.
# The third column is the prefix of the in-game files this run produced.
RUNS="
out_afro_dnb|1 afro - fast DnB remake|
out_fire|2 big beat punk|fire
out_afro|3 afro - original slower takes|afro
out_ace15|4 ACE-Step 1.5 first test|
out|5 v4 fast DnB and synth (old model)|0
out_v3_vocals|6 v3 90s rave with vocals (old model)|
out_v2_synth|7 v2 synth EDM (old model)|
out_v1_distorted|8 v1 first set, rock-ish (old model)|
"

mkdir -p "$DEST" "$TMP"

while IFS='|' read -r src folder game_prefix; do
  [ -n "$src" ] || continue
  mkdir -p "$DEST/$folder" "$TMP/$src"
  echo "==> $folder"
  rsync -a --include='*.wav' --exclude='*' "$SPARK_HOST:music-gen/$src/" "$TMP/$src/" || {
    echo "    (could not fetch $src)"; continue; }
  for wav in "$TMP/$src"/*.wav; do
    [ -f "$wav" ] || continue
    name="$(basename "$wav" .wav)"
    label="$name"
    # In the game = this run feeds the game AND the file is installed.
    if [ -n "$game_prefix" ] && [[ "$name" == "$game_prefix"* ]] \
       && [ -f "$PROJECT/audio/music/$name.ogg" ]; then
      label="IN GAME - $name"
    fi
    # Drop a stale copy carrying the other label, so a track never shows twice.
    for other in "$DEST/$folder/$name.m4a" "$DEST/$folder/IN GAME - $name.m4a"; do
      [ "$other" = "$DEST/$folder/$label.m4a" ] || rm -f "$other"
    done
    out="$DEST/$folder/$label.m4a"
    if [ ! -f "$out" ]; then
      ffmpeg -nostdin -hide_banner -loglevel error -y -i "$wav" \
        -c:a aac -b:a 192k -movflags +faststart "$out"
    fi
    rm -f "$wav"
  done
done <<<"$RUNS"

rm -rf "$TMP"
echo
echo "$(find "$DEST" -name '*.m4a' | wc -l | tr -d ' ') takes in $DEST"
[ "${1:-}" = "--no-open" ] || open "$DEST"
