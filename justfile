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
    cd mobile && flutter run -d iPhone \
      --dart-define=BEEBEEBIKE_API_BASE_URL={{IOS_DEVICE_API}} \
      --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL={{IOS_DEVICE_TILES}}

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

# Measure undo replay latency against a local Postgres (auto-starts the
# dev db container). Bench creates a throwaway DB and drops it on exit.
# Pass extra args after the recipe name, e.g.
#   just bench-undo --depths 1,5,10,20 --geometry-size large
[group('test')]
bench-undo *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    docker compose -f compose.yml -f compose.dev.yml up -d db
    until docker exec beebeebike-db pg_isready -U beebeebike >/dev/null 2>&1; do sleep 0.2; done
    cd backend && DATABASE_URL="${DATABASE_URL:-postgres://beebeebike:beebeebike@localhost:5432/beebeebike}" \
        cargo run --release --bin undo_bench -- {{ARGS}}

# Run the bench against a prod host's Postgres via the shipped backend image.
# Safe against prod: bench creates and drops its own throwaway database. Run
# from the host where compose.prod.yml lives (e.g. helena, ~/beebeebike).
[group('test')]
bench-undo-prod *ARGS:
    docker compose -f compose.prod.yml exec backend undo_bench {{ARGS}}

# vitest unit tests + mobile-style parity; run `just build-web` first if the build matters
[group('test')]
test-web:
    cd web && npm test
    cd web && npm run build:mobile-style
    git diff --exit-code mobile/assets/styles/beebeebike-style.json

# playwright chromium smoke (webServer builds + serves vite preview); requires one-time `npx playwright install chromium`
[group('test')]
test-e2e-web:
    cd web && npm run test:e2e

[group('test')]
test-mobile:
    cd mobile && flutter analyze
    cd mobile && flutter test

[group('test')]
test-ferrostar-flutter-plugin:
    cd packages/ferrostar_flutter && flutter analyze
    cd packages/ferrostar_flutter && flutter test

# flutter integration_test on iOS sim/device; empty UDID picks the first booted simulator
[group('test')]
test-e2e-ios UDID="":
    #!/usr/bin/env bash
    set -euo pipefail
    UDID="{{UDID}}"
    if [ -z "$UDID" ]; then
        UDID=$(xcrun simctl list devices booted --json | python3 -c "
    import json, sys
    devs = json.load(sys.stdin)['devices']
    for runtime, devices in devs.items():
        for d in devices:
            if d.get('state') == 'Booted':
                print(d['udid']); exit()
    ")
        if [ -z "$UDID" ]; then
            echo "No booted iOS simulator found. Boot one with 'xcrun simctl boot <UDID>' or pass UDID=<id>." >&2
            exit 1
        fi
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

# Build a release archive for TestFlight. When done, open Xcode → Window → Organizer,
# select the archive, and click Distribute App → TestFlight & App Store → Upload.
[group('build')]
ios-archive:
    cd mobile && flutter build ipa --release \
      --dart-define=BEEBEEBIKE_API_BASE_URL=https://beebeebike.com \
      --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL=https://beebeebike.com/tiles

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
