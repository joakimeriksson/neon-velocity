#!/usr/bin/env bash
# Make Finder-playable copies of the soundtrack and open them.
#
# The game ships OGG Vorbis, which Finder/QuickTime can't preview - double
# clicking one does nothing useful. This transcodes to AAC/m4a, which Quick Look
# plays on spacebar, and names each file with its style and tempo so the folder
# is browsable.
#
#   tools/music/preview.sh          # build previews and open in Finder
#   tools/music/preview.sh --no-open
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
SRC="$PROJECT/audio/music"
DEST="$HERE/previews"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }

rm -rf "$DEST"
mkdir -p "$DEST"

# Build "<name>\t<label>" pairs from the spec so filenames carry the brief.
labels=$(python3 - "$HERE/tracks.json" <<'PY'
import json, sys, re
spec = json.load(open(sys.argv[1]))
for t in spec["tracks"]:
    tags = [x.strip() for x in t["tags"].split(",")]
    bpm = next((x for x in tags if re.match(r"^\d+\s*bpm$", x, re.I)), "")
    # First couple of tags are the genre; skip the "instrumental"/"no vocals" noise.
    style = [x for x in tags if x is not bpm and x not in ("instrumental", "no vocals")][:2]
    print(f"{t['name']}\t{', '.join(style)}{' - ' + bpm if bpm else ''}")
PY
)

shopt -s nullglob
found=0
while IFS=$'\t' read -r name label; do
  src="$SRC/$name.ogg"
  [ -f "$src" ] || continue
  found=$((found + 1))
  # Slashes would create directories; nothing else needs escaping in a filename.
  safe="${label//\//-}"
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$src" \
    -c:a aac -b:a 192k -movflags +faststart \
    "$DEST/${name} - ${safe}.m4a"
  echo "  $name - $safe"
done <<<"$labels"

if [ "$found" -eq 0 ]; then
  echo "no tracks in $SRC - run tools/music/fetch.sh first" >&2
  exit 1
fi

echo
echo "$found previews in $DEST"
if [ "${1:-}" != "--no-open" ]; then
  open "$DEST"
fi
