#!/bin/bash
# The race announcer's lines (audio/voice/*.ogg), made with VoxCPM2 on the Spark.
#
#   tools/voice/make_voice.sh audition          # the voices in spark_voice.py read one line each
#   tools/voice/make_voice.sh bank <voice>      # every line of lines.txt in that voice, 3 takes each
#   tools/voice/make_voice.sh render <voice>    # Whisper picks the takes; trimmed, levelled .ogg
#   tools/voice/make_voice.sh page              # out/audition.html: listen to what has been rendered
#   tools/voice/make_voice.sh install <voice>   # put that voice in the game
#
# Everything in between lives in tools/voice/out/ (git-ignored). Options, as environment:
#   TAKE=2          bank: clone from audition take 2 of the voice instead of take 1
#   REDO=go,mines   bank: make these lines again (their takes are deleted first)
#   DRY=1           render: leave out the public-address treatment (high-pass, compressor, slap echo)
#   SPARK=host      the machine with ~/work/voxcpm-test/.venv (default: the ssh alias `spark`)
#
# The voices are designed from text descriptions, not cloned from anybody, and VoxCPM2 is
# Apache-2.0, so the lines can be committed and shipped. Needs ssh access to the Spark,
# ffmpeg and uv (mlx-whisper runs the take check on the Mac). The game treats every file as
# optional.
set -euo pipefail
cd "$(dirname "$0")/../.."
SPARK="${SPARK:-spark}"
REMOTE=work/neon-voice
PY='~/work/voxcpm-test/.venv/bin/python'
OUT=tools/voice/out
cmd="${1:-}"
voice="${2:-}"

push() {
	ssh -o BatchMode=yes "$SPARK" "mkdir -p $REMOTE"
	scp -q tools/voice/spark_voice.py tools/voice/lines.txt "$SPARK:$REMOTE/"
}

need_voice() {
	[ -n "$voice" ] || { echo "usage: $0 $cmd <voice>"; exit 1; }
}

case "$cmd" in
audition)
	push
	ssh -o BatchMode=yes "$SPARK" "cd $REMOTE && $PY spark_voice.py audition audition 2>audition.err"
	mkdir -p "$OUT"
	scp -q -r "$SPARK:$REMOTE/audition" "$OUT/"
	uv run -q tools/voice/pick_takes.py audition "$OUT/audition"
	;;
bank)
	need_voice
	push
	take="${TAKE:-1}"
	redo=""
	for id in $(echo "${REDO:-}" | tr ',' ' '); do redo="$redo bank/$voice/${id}_*.wav"; done
	# A bank cloned from another take is another voice: start it again.
	ssh -o BatchMode=yes "$SPARK" "cd $REMOTE && mkdir -p bank/$voice \
		&& { [ \"\$(cat bank/$voice/ref.txt 2>/dev/null)\" = ${voice}_$take ] || rm -f bank/$voice/*.wav; } \
		&& echo ${voice}_$take > bank/$voice/ref.txt && rm -f $redo \
		&& $PY spark_voice.py bank lines.txt audition/${voice}_$take.wav bank/$voice 2>bank_$voice.err"
	mkdir -p "$OUT/bank"
	rm -rf "$OUT/bank/$voice"
	scp -q -r "$SPARK:$REMOTE/bank/$voice" "$OUT/bank/"
	;;
render)
	need_voice
	uv run -q tools/voice/pick_takes.py bank "$OUT/bank/$voice" "$OUT/game/$voice" ${DRY:+--dry}
	;;
page)
	python3 tools/voice/page.py "$OUT"
	echo "open $OUT/audition.html"
	;;
install)
	need_voice
	[ -d "$OUT/game/$voice" ] || { echo "no rendered lines for '$voice': run bank and render first"; exit 1; }
	mkdir -p audio/voice
	rm -f audio/voice/*.wav audio/voice/*.wav.import audio/voice/*.ogg audio/voice/*.ogg.import
	cp "$OUT/game/$voice"/*.ogg audio/voice/
	echo "$voice" > audio/voice/VOICE
	godot --headless --path . --import >/dev/null 2>&1 || true
	echo "Installed $(ls audio/voice/*.ogg | wc -l | tr -d ' ') lines in the voice '$voice'."
	;;
*)
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
	;;
esac
