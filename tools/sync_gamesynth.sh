#!/usr/bin/env bash
# Build ../gamesynth in release mode and copy the GDExtension binary into addons/gamesynth/bin.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNTH="${GAMESYNTH_DIR:-$HERE/../gamesynth}"
(cd "$SYNTH" && cargo build -p gamesynth-godot --release)
mkdir -p "$HERE/addons/gamesynth/bin"
cp "$SYNTH"/target/release/libgamesynth_godot.{dylib,so} "$HERE/addons/gamesynth/bin/" 2>/dev/null || true
cp "$SYNTH"/target/release/gamesynth_godot.dll "$HERE/addons/gamesynth/bin/" 2>/dev/null || true
ls -la "$HERE/addons/gamesynth/bin"
