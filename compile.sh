#!/usr/bin/env bash
# Build pca9685.wasm using WASI-SDK (same flags velxio's backend uses).
# Set WASI_SDK to your install path and VELXIO_SDK to the velxio repo's backend/sdk dir.
set -euo pipefail
WASI_SDK="${WASI_SDK:-/opt/wasi-sdk}"
VELXIO_SDK="${VELXIO_SDK:-./velxio/backend/sdk}"
"$WASI_SDK/bin/clang" \
  --target=wasm32-unknown-wasip1 -O2 -nostartfiles \
  -Wl,--import-memory -Wl,--export-table -Wl,--no-entry \
  -Wl,--export=chip_setup -Wl,--allow-undefined \
  -I "$VELXIO_SDK" \
  pca9685.c -o dist/pca9685.wasm
echo "built dist/pca9685.wasm"
