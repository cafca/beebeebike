#!/bin/sh
set -eu

SERVICE_NAME="graphhopper-placeholder"
PORT="8989"
FIXTURE_PATH="/data/berlin.osm.pbf"
DOC_ROOT="/app/www"

log() {
  printf '[%s] %s\n' "$SERVICE_NAME" "$1"
}

if [ ! -f "$FIXTURE_PATH" ]; then
  log "startup_error fixture_status=missing fixture_path=$FIXTURE_PATH message=required_berlin_extract_not_found"
  exit 1
fi

if [ ! -s "$FIXTURE_PATH" ]; then
  log "startup_error fixture_status=empty fixture_path=$FIXTURE_PATH message=berlin_extract_is_empty"
  exit 1
fi

FIXTURE_SIZE="$(wc -c < "$FIXTURE_PATH" | tr -d ' ')"
log "startup fixture_status=present fixture_path=$FIXTURE_PATH fixture_size_bytes=$FIXTURE_SIZE listening_port=$PORT"
log "serving doc_root=$DOC_ROOT health_endpoint=/ route=/"

exec busybox httpd -f -v -p "$PORT" -h "$DOC_ROOT"
