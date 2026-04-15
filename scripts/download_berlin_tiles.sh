#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="download_berlin_tiles"
LOG_PREFIX="[${SCRIPT_NAME}]"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/data/tiles"
OUTPUT_PATH="${OUTPUT_DIR}/berlin.versatiles"
FORCE=0

log() { echo "${LOG_PREFIX} $*"; }
error() { echo "${LOG_PREFIX} ERROR: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    --help|-h)
      echo "Usage: ./scripts/download_berlin_tiles.sh [--force]"
      echo "Downloads Berlin vector tiles in VersaTiles format."
      exit 0 ;;
    *) error "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

if [[ -s "${OUTPUT_PATH}" && "${FORCE}" -ne 1 ]]; then
  log "Tiles already exist at ${OUTPUT_PATH}; skipping. Use --force to re-download."
  exit 0
fi

mkdir -p "${OUTPUT_DIR}"

if ! command -v versatiles >/dev/null 2>&1; then
  log "versatiles CLI not found. Using Docker to extract Berlin tiles..."
  docker run --rm -v "${OUTPUT_DIR}:/output" versatiles/versatiles:latest \
    convert \
    --bbox "13.0,52.3,13.8,52.7" \
    "https://download.versatiles.org/osm.versatiles" \
    "/output/berlin.versatiles"
else
  versatiles convert \
    --bbox "13.0,52.3,13.8,52.7" \
    "https://download.versatiles.org/osm.versatiles" \
    "${OUTPUT_PATH}"
fi

log "Berlin tiles ready at ${OUTPUT_PATH}"
