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

# ---------- test ----------

[group('test')]
test: test-backend test-web test-mobile test-ferrostar-flutter-plugin

[group('test')]
test-backend:
    cd backend && cargo test

# vitest unit tests + mobile-style parity; run `just build-web` first if the build matters
[group('test')]
test-web:
    cd web && npm test
    cd web && npm run build:mobile-style
    git diff --exit-code mobile/assets/styles/beebeebike-style.json

# playwright chromium smoke (webServer builds + serves vite preview); requires one-time `npx playwright install chromium`
[group('test')]
test-e2e:
    cd web && npm run test:e2e

[group('test')]
test-mobile:
    cd mobile && flutter analyze
    cd mobile && flutter test

[group('test')]
test-ferrostar-flutter-plugin:
    cd packages/ferrostar_flutter && flutter analyze
    cd packages/ferrostar_flutter && flutter test

[group('test')]
test-ios UDID="":
    #!/usr/bin/env bash
    set -euo pipefail
    UDID="{{UDID}}"
    if [ -z "$UDID" ]; then
        UDID=$(xcrun simctl list devices available --json | python3 -c "
    import json, sys
    devs = json.load(sys.stdin)['devices']
    for runtime, devices in devs.items():
        for d in devices:
            if 'iPhone 17' in d['name'] and d['isAvailable']:
                print(d['udid']); exit()
    ")
        if [ -z "$UDID" ]; then
            echo "No available iPhone 17 simulator found" >&2
            exit 1
        fi
        xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
    fi
    cd mobile && flutter test integration_test/navigation_smoke_test.dart -d "$UDID"

# ---------- lint ----------

[group('lint')]
lint: lint-backend lint-mobile

[group('lint')]
lint-backend: lint-backend-fmt lint-backend-clippy

[group('lint')]
lint-backend-fmt:
    cd backend && cargo fmt --check

[group('lint')]
lint-backend-clippy:
    cd backend && cargo clippy --all-targets -- -D warnings

[group('lint')]
fmt:
    cd backend && cargo fmt

[group('lint')]
lint-mobile:
    cd packages/ferrostar_flutter && flutter analyze
    cd mobile && flutter analyze

# ---------- build ----------

[group('build')]
build-web:
    cd web && npm run build

[group('build')]
build-mobile-style:
    cd web && npm run build:mobile-style

[group('build')]
release:
    docker compose -f compose.prod.yml up -d --build

[group('build')]
release-ios-device DEVICE:
    cd mobile && flutter run --release -d {{DEVICE}} \
      --dart-define=BEEBEEBIKE_API_BASE_URL={{IOS_DEVICE_API}} \
      --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL={{IOS_DEVICE_TILES}}

# ---------- clean ----------

[group('clean')]
clean: clean-backend clean-web clean-mobile clean-docker

[group('clean')]
clean-backend:
    cd backend && cargo clean

[group('clean')]
clean-web:
    rm -rf web/dist web/node_modules

[group('clean')]
clean-mobile:
    cd packages/ferrostar_flutter && flutter clean
    cd mobile && flutter clean

[group('clean')]
clean-docker:
    docker compose -f compose.yml -f compose.dev.yml down -v
    docker compose -f compose.prod.yml down -v
