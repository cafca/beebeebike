# Centralized command runner with `just`

Date: 2026-04-20

## Purpose

Common dev/CI/release commands for beebeebike currently live in three places: `CLAUDE.md` code blocks, GitHub Actions workflows, and `web/package.json` scripts. `README.md` Quickstart duplicates a subset. When a command changes, drift is easy.

Introduce a single root `justfile` as the canonical source. CI, docs, and the human workflow all call the same recipes. Raw commands remain only where CI-specific setup would slow local dev if folded into a recipe.

## Non-goals

- Replacing `npm run build:mobile-style` in `web/package.json` — keep it; `just build-mobile-style` wraps it
- Per-component sub-justfiles (`mod backend`, `mod web`) — single root file for now; revisit if recipe count exceeds ~40
- Covering DB admin (psql shell, migration state) — out of scope per brainstorming
- A `just ci` meta-recipe mirroring every CI step — CI composes recipes directly

## Conventions

Top of `justfile`:

```just
set shell := ["bash", "-uc"]

IOS_DEVICE_API := env_var_or_default('BEEBEEBIKE_API_BASE_URL', 'https://beebeebike.com')
IOS_DEVICE_TILES := env_var_or_default('BEEBEEBIKE_TILE_SERVER_BASE_URL', 'https://beebeebike.com/tiles')

default:
    @just --list
```

- Single `justfile` at repo root
- Default recipe (`just` with no args) lists all recipes, grouped
- Groups via `[group('setup')]` etc. on each recipe
- Recipes use inline `cd <subdir> && <cmd>`
- Aggregate recipes run their constituents in sequence; failures short-circuit
- Random port: `$((RANDOM % 10000 + 20000))` inside recipe body (portable; `shuf` is not standard on macOS)
- LAN IP for device testing: `$(ipconfig getifaddr en0)` inside recipe body (macOS-only — primary dev host)
- Main-repo path discovery (for `preview`): `$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')` — first entry is the main working tree

## Recipe catalog

### setup

- `setup` — aggregate: `setup-data`, `setup-web`, `setup-mobile`
- `setup-data` — run `scripts/download_berlin_osm.sh` and `scripts/download_berlin_tiles.sh`
- `setup-web` — `cd web && npm ci`
- `setup-mobile` — `flutter pub get` in `packages/ferrostar_flutter` and `mobile`

### dev

- `dev` — `docker compose -f compose.yml -f compose.dev.yml up`
- `dev-ios-sim` — `cd mobile && flutter run -d ios` (sim shares host network; defaults target `127.0.0.1:3000` / `127.0.0.1:8080`)
- `dev-ios-device DEVICE` — `cd mobile && flutter run -d {{DEVICE}}` with dart-defines pointing at `http://$(ipconfig getifaddr en0):3000` / `:8080`; requires dev docker stack running on host
- `preview` — worktree preview: copy `data/` from main repo path, pick random port 20000–30000, run `VITE_DEV_PORT=$PORT docker compose -f compose.yml -f compose.dev.yml up`; echoes the URL before starting

### test

- `test` — aggregate: `test-backend`, `test-web`, `test-mobile`, `test-ferrostar-flutter-plugin`
- `test-backend` — `cd backend && cargo test`
- `test-web` — `cd web && npm run build && npm run build:mobile-style && git diff --exit-code mobile/assets/styles/beebeebike-style.json` (matches CI's test-frontend job)
- `test-mobile` — `cd mobile && flutter analyze && flutter test` (app only)
- `test-ferrostar-flutter-plugin` — same in `packages/ferrostar_flutter`
- `test-ios UDID=""` — iOS sim integration smoke. If `UDID` empty, auto-detect first available `iPhone 17` via `xcrun simctl list --json` and boot it. Then `cd mobile && flutter test integration_test/navigation_smoke_test.dart -d $UDID`. Does NOT run `flutter config --enable-swift-package-manager` or `flutter build ios --no-codesign --simulator` — those are slow, CI does them as raw steps.

### lint

- `lint` — aggregate: `lint-backend`, `lint-mobile`
- `lint-backend` — aggregate: `lint-backend-fmt`, `lint-backend-clippy`
- `lint-backend-fmt` — `cd backend && cargo fmt --check`
- `lint-backend-clippy` — `cd backend && cargo clippy --all-targets -- -D warnings`
- `fmt` — `cd backend && cargo fmt` (mutating; not part of `lint`)
- `lint-mobile` — `flutter analyze` in `packages/ferrostar_flutter` and `mobile`

### build

- `build-web` — `cd web && npm run build`
- `build-mobile-style` — `cd web && npm run build:mobile-style`
- `release` — `docker compose -f compose.prod.yml up -d --build`
- `release-ios-device DEVICE` — `cd mobile && flutter run --release -d {{DEVICE}} --dart-define=BEEBEEBIKE_API_BASE_URL={{IOS_DEVICE_API}} --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL={{IOS_DEVICE_TILES}}`

### clean

- `clean` — aggregate: all `clean-*`
- `clean-backend` — `cd backend && cargo clean`
- `clean-web` — `rm -rf web/dist web/node_modules`
- `clean-mobile` — `flutter clean` in `packages/ferrostar_flutter` and `mobile`
- `clean-docker` — `docker compose -f compose.yml -f compose.dev.yml down -v` and `docker compose -f compose.prod.yml down -v`

## CI integration

### `.github/workflows/ci.yml`

Each job adds `extractions/setup-just@v3` after checkout, then:

- `lint` job: two steps — `just lint-backend-fmt` and `just lint-backend-clippy` — so the GitHub Actions UI shows each failure type distinctly
- `test-backend` job: `just test-backend` with `TEST_DATABASE_URL` env from services block
- `test-frontend` job: `just test-web`

### `.github/workflows/ci-mobile.yml`

- `test-mobile` job:
  - `just test-ferrostar-flutter-plugin`
  - `just test-mobile`
  - (analyze + test are inside both recipes)
- `test-mobile-ios` job:
  - Keep raw: `flutter config --enable-swift-package-manager`, `flutter build ios --no-codesign --simulator`, sim UDID detection + boot
  - Then: `just test-ios UDID=$SIM_UDID`

### Unchanged

- `cd.yml`, `flutter-plugin.yml`, `refresh-data.yml` — no edits unless a justfile recipe supersedes their commands; review during implementation.

## Docs updates

### `README.md`

Quickstart block becomes:

```sh
brew install just        # one-time
just setup
just dev
```

Mobile block becomes `just dev-ios-sim`.

### `CLAUDE.md`

Replace all raw command blocks in "Build & Run" with `just <recipe>`. One-line prose describes what the recipe does. Example:

> Development: `just dev` — runs full stack with hot-reload frontend via `compose.yml` + `compose.dev.yml`.

"Previewing changes when working in a worktree" section becomes: `just preview` — copies `data/` from main repo, picks random port, runs dev stack.

"Map style" regen: `just build-mobile-style`.

Keep the env-var table and architecture prose unchanged.

## Install

- `brew install just` on macOS (both docs note this)
- CI: `extractions/setup-just@v3` action

## Rollout

Order:

1. Write `justfile` with all recipes; run each locally to verify
2. Update CI workflows to call recipes; confirm green on a PR
3. Update `README.md` and `CLAUDE.md`
4. Delete the paint-by-commands prose from docs that is now redundant

## Open risks

- `just` not installed on a contributor's machine → install step in README mitigates
- `env_var_or_default` requires `just` ≥ 1.5 (well below current stable; no concern)
- `shuf` and `ipconfig getifaddr` are macOS-friendly; Linux dev hosts need `ip addr` instead. Out of scope — primary dev host is macOS, CI runs Ubuntu/macOS per job but doesn't call these recipes.
