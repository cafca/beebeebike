set shell := ["bash", "-uc"]

IOS_DEVICE_API := env_var_or_default('BEEBEEBIKE_API_BASE_URL', 'https://beebeebike.com')
IOS_DEVICE_TILES := env_var_or_default('BEEBEEBIKE_TILE_SERVER_BASE_URL', 'https://beebeebike.com/tiles')

# Default: list all recipes grouped
default:
    @just --list

# ---------- setup ----------

[group('setup')]
setup: setup-data setup-web setup-mobile

[group('setup')]
setup-data:
    ./scripts/download_berlin_osm.sh
    ./scripts/download_berlin_tiles.sh

[group('setup')]
setup-web:
    cd web && npm ci

[group('setup')]
setup-mobile:
    cd packages/ferrostar_flutter && flutter pub get
    cd mobile && flutter pub get

# ---------- dev ----------

[group('dev')]
dev:
    docker compose -f compose.yml -f compose.dev.yml up

[group('dev')]
dev-ios-sim:
    cd mobile && flutter run -d ios

[group('dev')]
dev-ios-device DEVICE:
    #!/usr/bin/env bash
    set -euo pipefail
    LAN_IP=$(ipconfig getifaddr en0)
    cd mobile && flutter run -d {{DEVICE}} \
      --dart-define=BEEBEEBIKE_API_BASE_URL=http://${LAN_IP}:3000 \
      --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL=http://${LAN_IP}:8080

[group('dev')]
preview:
    #!/usr/bin/env bash
    set -euo pipefail
    MAIN_REPO=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')
    if [ -d "$MAIN_REPO/data" ] && [ ! -d "./data" ]; then
        cp -r "$MAIN_REPO/data" ./data
    fi
    PORT=$((RANDOM % 10000 + 20000))
    echo "Preview will be available at http://localhost:${PORT}"
    VITE_DEV_PORT=$PORT docker compose -f compose.yml -f compose.dev.yml up
