#!/usr/bin/env bash
# Build ../gamesynth (the Brusverk library; checkout and repo keep the old name) in release mode and copy the GDExtension binary into addons/gamesynth/bin.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNTH="${GAMESYNTH_DIR:-$HERE/../gamesynth}"
(cd "$SYNTH" && cargo build -p brusverk-godot --release)
mkdir -p "$HERE/addons/gamesynth/bin"
cp "$SYNTH"/target/release/libbrusverk_godot.{dylib,so} "$HERE/addons/gamesynth/bin/" 2>/dev/null || true
cp "$SYNTH"/target/release/brusverk_godot.dll "$HERE/addons/gamesynth/bin/" 2>/dev/null || true
# Web build too (needs emsdk + pinned nightly, see gamesynth/tools/build-wasm.sh); skipped if it fails.
(cd "$SYNTH" && tools/build-wasm.sh) && cp "$SYNTH/target/wasm32-unknown-emscripten/release/brusverk_godot.wasm" "$HERE/addons/gamesynth/bin/" || echo "wasm build skipped"
# The crates gamesynth is built from, with their licences, for the in-game Licences page.
(cd "$SYNTH" && cargo tree -p brusverk-godot --edges normal --prefix none --format "{p} | {l}" | sed -E 's/ \(.*\)//' | sort -u) > "$HERE/addons/gamesynth/THIRD_PARTY.txt"
ls -la "$HERE/addons/gamesynth/bin"
