#!/usr/bin/env bash
set -euo pipefail

# UniFFI Swift bindings generation script for Ortschaft.
#
# Prerequisites:
# - Rust toolchain with Cargo installed
# - Rust toolchain with Cargo installed.
#
# This script uses the workspace-local `uniffi-bindgen` binary target from
# the `or-ffi` crate, so no separate global install is required.
#
# This script is idempotent and safe to run multiple times. It will:
# - Build the `or-ffi` crate (including UniFFI Rust scaffolding).
# - Generate Swift bindings from `or-ffi/src/or_ffi.udl`.
# - Write the Swift module into `bindings/swift/OrtschaftCore/`.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OR_FFI_CRATE="${ROOT_DIR}/or-ffi"
UDL_PATH="${OR_FFI_CRATE}/src/or_ffi.udl"
OUT_DIR="${ROOT_DIR}/bindings/swift/OrtschaftCore"
MODULE_NAME="OrtschaftCore"

mkdir -p "${OUT_DIR}"

echo "[gen-uniffi] Building or-ffi crate (this will also run UniFFI Rust scaffolding)..."
(
  cd "${OR_FFI_CRATE}"
  if ! cargo build --quiet; then
    echo "[gen-uniffi] ERROR: 'cargo build' failed for or-ffi. See the Rust compiler output above for details." >&2
    exit 1
  fi
)

echo "[gen-uniffi] Generating Swift bindings from '${UDL_PATH}' into '${OUT_DIR}' (module ${MODULE_NAME})..."
if ! cargo run --quiet -p or-ffi --bin uniffi-bindgen -- generate "${UDL_PATH}" \
  --language swift \
  --out-dir "${OUT_DIR}"; then
  echo "[gen-uniffi] ERROR: 'uniffi-bindgen generate' failed. Check that the UDL file is valid and UniFFI is up to date." >&2
  exit 1
fi

echo "[gen-uniffi] Done. Generated files in '${OUT_DIR}':"
ls -1 "${OUT_DIR}" || true
