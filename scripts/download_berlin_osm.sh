#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="download_berlin_osm"
LOG_PREFIX="[${SCRIPT_NAME}]"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_URL="https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf"
OUTPUT_DIR="${ROOT_DIR}/data/osm/berlin"
OUTPUT_PATH="${OUTPUT_DIR}/berlin.osm.pbf"
SOURCE_URL="${OSM_BERLIN_URL:-${DEFAULT_URL}}"
FORCE=0
TMP_FILE=""

log() {
  echo "${LOG_PREFIX} $*"
}

error() {
  echo "${LOG_PREFIX} ERROR: $*" >&2
}

usage() {
  cat <<EOF
Usage: ./scripts/download_berlin_osm.sh [--force] [--help]

Download the canonical Berlin OSM extract into:
  data/osm/berlin/berlin.osm.pbf

Options:
  --force   Re-download even if the destination file already exists and is non-empty.
  --help    Show this help text.

Environment:
  OSM_BERLIN_URL  Override the source URL.
EOF
}

cleanup() {
  if [[ -n "${TMP_FILE}" && -e "${TMP_FILE}" ]]; then
    rm -f "${TMP_FILE}"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

log "Preparing Berlin OSM download."
log "Source URL: ${SOURCE_URL}"
log "Destination path: ${OUTPUT_PATH}"

if ! command -v curl >/dev/null 2>&1; then
  error "Missing dependency: curl is required but was not found in PATH."
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

if [[ -s "${OUTPUT_PATH}" && "${FORCE}" -ne 1 ]]; then
  log "Destination already exists and is non-empty; skipping download. Use --force to refresh."
  exit 0
fi

if [[ -e "${OUTPUT_PATH}" && ! -s "${OUTPUT_PATH}" ]]; then
  log "Existing destination file is empty; removing it before retrying download."
  rm -f "${OUTPUT_PATH}"
fi

TMP_FILE="$(mktemp "${OUTPUT_DIR}/berlin.osm.pbf.tmp.XXXXXX")"
log "Downloading to temporary path: ${TMP_FILE}"

if ! curl --fail --location --show-error --silent --output "${TMP_FILE}" "${SOURCE_URL}"; then
  error "Download failed during HTTP transfer. Check network access, URL reachability, or server status."
  exit 1
fi

if [[ ! -s "${TMP_FILE}" ]]; then
  error "Validation failed: downloaded file is empty or missing after transfer."
  exit 1
fi

mv "${TMP_FILE}" "${OUTPUT_PATH}"
TMP_FILE=""

if [[ ! -s "${OUTPUT_PATH}" ]]; then
  error "Validation failed: destination file is empty after atomic move."
  exit 1
fi

log "Download complete. Canonical Berlin extract is ready at ${OUTPUT_PATH}."
