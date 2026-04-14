#!/bin/sh
set -eu

SERVICE_NAME="tiles-placeholder"
PORT="8080"
DOC_ROOT="/app/www"

log() {
  printf '[%s] %s\n' "$SERVICE_NAME" "$1"
}

log "startup fixture_status=not_required listening_port=$PORT"
log "serving doc_root=$DOC_ROOT health_endpoint=/ route=/"

cd "$DOC_ROOT" && exec python3 -m http.server "$PORT"
