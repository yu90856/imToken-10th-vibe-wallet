#!/usr/bin/env bash
# 將 npm 的 @consenlabs/tcx-wasm 同步到 iOS Bundle（版本需與 package.json 一致）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/node_modules/@consenlabs/tcx-wasm"
DST="$ROOT/ios/VibeWallet/Resources/TokenCore"

if [[ ! -d "$SRC" ]]; then
  echo "Missing $SRC — run npm install in repo root first." >&2
  exit 1
fi

mkdir -p "$DST"
cp "$SRC/tcx_wasm.js" "$SRC/tcx_wasm_bg.wasm" "$DST/"
echo "Synced Token Core WASM to $DST"
