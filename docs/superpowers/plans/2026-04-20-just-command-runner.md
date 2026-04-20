# `just` command runner implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a root `justfile` as the single source of truth for dev, test, lint, build, release, and clean commands; migrate CI workflows and docs to use it.

**Architecture:** Single root `justfile` with grouped recipes (`setup`, `dev`, `test`, `lint`, `build`, `clean`). Each recipe inlines `cd <subdir>`. Variables at top for prod URLs (`env_var_or_default`). CI installs `just` and calls recipes; `CLAUDE.md` and `README.md` link to recipe names, not raw commands. Some CI steps keep raw `flutter build ios` commands for local-dev speed.

**Tech Stack:** `just` 1.x, bash, GitHub Actions, existing `cargo`/`npm`/`flutter`/`docker compose` stack.

---

## Prerequisites

The engineer must have `just` installed locally:

```bash
brew install just
just --version   # >= 1.14 for env_var_or_default
```

The branch must be up to date with `origin/main`, which contains the Vitest + Playwright frontend test suite (PR #36). Recipes below assume `web/package.json` has scripts `test`, `test:watch`, `test:e2e` and that `web/playwright.config.js` exists. If not, rebase onto `origin/main` before starting.

## File structure

- Create: `justfile` (repo root) — all recipes, grouped
- Modify: `.github/workflows/ci.yml` — install `just`, replace raw commands
- Modify: `.github/workflows/ci-mobile.yml` — install `just`, replace most raw commands (keep ios build + sim boot raw)
- Modify: `README.md` — Quickstart + mobile blocks
- Modify: `CLAUDE.md` — Build & Run section
- Unchanged: `web/package.json`, `compose.*.yml`, `scripts/*.sh`, `backend/**`, `mobile/**`, `packages/ferrostar_flutter/**`, `.github/workflows/cd.yml`, `.github/workflows/flutter-plugin.yml`, `.github/workflows/refresh-data.yml`

Reference: the spec at [docs/superpowers/specs/2026-04-20-just-command-runner-design.md](../specs/2026-04-20-just-command-runner-design.md).

---

## Task 1: Skeleton `justfile` + `setup` group

**Files:**
- Create: `justfile`

- [ ] **Step 1: Create the skeleton**

Create `justfile` with the header, variables, and `setup` group:

```just
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
```

- [ ] **Step 2: Verify the file parses**

Run: `just --list`

Expected: prints four recipes grouped under `[setup]`: `setup`, `setup-data`, `setup-web`, `setup-mobile`, plus `default`.

- [ ] **Step 3: Dry-run a recipe**

Run: `just -n setup-web`

Expected output (exact, one line):

```
cd web && npm ci
```

- [ ] **Step 4: Commit**

```bash
git add justfile
git commit -m "feat(just): root justfile skeleton with setup recipes"
```

---

## Task 2: `dev` group

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Append the dev group**

Append after the setup group:

```just
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
```

- [ ] **Step 2: Verify parse**

Run: `just --list`

Expected: `[dev]` group appears with four recipes: `dev`, `dev-ios-sim`, `dev-ios-device`, `preview`.

- [ ] **Step 3: Dry-run `dev`**

Run: `just -n dev`

Expected:

```
docker compose -f compose.yml -f compose.dev.yml up
```

- [ ] **Step 4: Verify `dev-ios-device` argument is required**

Run: `just dev-ios-device`

Expected: error like `error: Recipe 'dev-ios-device' got 0 arguments but takes 1`.

- [ ] **Step 5: Commit**

```bash
git add justfile
git commit -m "feat(just): dev recipes (docker stack, ios sim/device, worktree preview)"
```

---

## Task 3: `test` group

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Append the test group**

Append after the dev group:

```just
# ---------- test ----------

[group('test')]
test: test-backend test-web test-mobile test-ferrostar-flutter-plugin

[group('test')]
test-backend:
    cd backend && cargo test

# Fast web test suite: build, vitest unit tests, mobile-style parity.
# Mirrors the CI `frontend` job. e2e lives in `test-e2e` (separate because
# chromium install and real browser are slow).
[group('test')]
test-web:
    cd web && npm run build
    cd web && npm test
    cd web && npm run build:mobile-style
    git diff --exit-code mobile/assets/styles/beebeebike-style.json

# Playwright chromium e2e. Assumes `npx playwright install chromium` has
# been run once; recipe does not auto-install. Mirrors CI `frontend-e2e`.
[group('test')]
test-e2e:
    cd web && npm run build
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
```

- [ ] **Step 2: Verify parse**

Run: `just --list`

Expected: `[test]` group with seven recipes: `test`, `test-backend`, `test-web`, `test-e2e`, `test-mobile`, `test-ferrostar-flutter-plugin`, `test-ios`.

- [ ] **Step 3: Dry-run the aggregate**

Run: `just -n test`

Expected: prints the bodies of all four constituent recipes in order.

- [ ] **Step 4: Run a safe recipe end-to-end**

If the backend compiles and the test DB isn't required for all tests, run: `just test-backend`

If it requires `TEST_DATABASE_URL` and that's not set up locally, skip this step — will be verified in CI.

- [ ] **Step 5: Commit**

```bash
git add justfile
git commit -m "feat(just): test recipes (backend, web+mobile-style parity, flutter, ios sim)"
```

---

## Task 4: `lint`, `build`, `clean` groups

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Append the three remaining groups**

Append:

```just
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
```

- [ ] **Step 2: Verify parse**

Run: `just --list`

Expected: three new groups (`lint`, `build`, `clean`) with the recipes listed above.

- [ ] **Step 3: Run a safe lint recipe**

Run: `just lint-backend-fmt`

Expected: exit 0 if backend is already formatted; non-zero if not. Either outcome confirms the recipe runs.

If it fails because code is unformatted, run `just fmt`, commit separately, then re-run.

- [ ] **Step 4: Dry-run release**

Run: `just -n release`

Expected:

```
docker compose -f compose.prod.yml up -d --build
```

- [ ] **Step 5: Dry-run `release-ios-device`**

Run: `just -n release-ios-device my-iphone`

Expected output contains `flutter run --release -d my-iphone --dart-define=BEEBEEBIKE_API_BASE_URL=https://beebeebike.com --dart-define=BEEBEEBIKE_TILE_SERVER_BASE_URL=https://beebeebike.com/tiles`.

- [ ] **Step 6: Commit**

```bash
git add justfile
git commit -m "feat(just): lint, build, release, clean recipes"
```

---

## Task 5: Migrate `ci.yml` to use `just`

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read the current file**

Run: `cat .github/workflows/ci.yml`

Note the four jobs to modify: `lint`, `backend`, `frontend`, `frontend-e2e`. The `ship` job is a reusable workflow dispatch; its `needs:` list stays the same (already `[lint, backend, frontend, frontend-e2e]`).

- [ ] **Step 2: Update the `lint` job**

Replace the `lint` job's steps with:

```yaml
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - uses: Swatinem/rust-cache@v2
        with:
          workspaces: backend

      - uses: extractions/setup-just@v3

      - name: cargo fmt
        run: just lint-backend-fmt

      - name: cargo clippy
        run: just lint-backend-clippy
```

- [ ] **Step 3: Update the `backend` job**

Keep the services block, `TEST_DATABASE_URL` env, and rust-toolchain setup exactly as they are. Add `extractions/setup-just@v3` after `Swatinem/rust-cache@v2`, then replace the final step:

```yaml
      - uses: extractions/setup-just@v3

      - name: cargo test
        run: just test-backend
```

- [ ] **Step 4: Update the `frontend` job**

Replace the `npm run build`, `npm test`, and mobile-style steps with a single `just` call. The final job:

```yaml
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: web/package-lock.json

      - run: npm ci
        working-directory: web

      - uses: extractions/setup-just@v3

      - name: build + vitest + mobile-style parity
        run: just test-web
```

`npm ci` stays as a separate step so the setup-node cache works correctly — `just test-web` assumes deps are installed.

- [ ] **Step 5: Update the `frontend-e2e` job**

Replace the `npm run build` and `npm run test:e2e` steps with `just test-e2e`. Keep the playwright browser cache and install steps raw — they are CI-specific. The final job:

```yaml
  frontend-e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: web/package-lock.json

      - run: npm ci
        working-directory: web

      - name: Cache Playwright browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ runner.os }}-${{ hashFiles('web/package-lock.json') }}

      - name: Install Playwright chromium
        run: npx playwright install --with-deps chromium
        working-directory: web

      - uses: extractions/setup-just@v3

      - name: build + playwright smoke
        run: just test-e2e

      - name: Upload Playwright report on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: |
            web/playwright-report
            web/test-results
          retention-days: 7
```

- [ ] **Step 6: Verify the workflow parses**

Run: `cat .github/workflows/ci.yml`

Visually confirm the four jobs have the expected shape, `ship.needs` is still `[lint, backend, frontend, frontend-e2e]`, and each non-ship job has `extractions/setup-just@v3`. Then (optional) validate YAML if `actionlint` or `yamllint` is available: `actionlint .github/workflows/ci.yml`.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: call just recipes from lint, backend, frontend, and frontend-e2e jobs"
```

---

## Task 6: Migrate `ci-mobile.yml` to use `just`

**Files:**
- Modify: `.github/workflows/ci-mobile.yml`

- [ ] **Step 1: Update the `test-mobile` job**

Replace the "Analyze (plugin/app)" and "Test (plugin/app)" steps with `just` calls. The final job:

```yaml
  test-mobile:
    name: Flutter tests (iOS)
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - uses: extractions/setup-just@v3

      - name: Install dependencies (plugin)
        working-directory: packages/ferrostar_flutter
        run: flutter pub get

      - name: Install dependencies (app)
        working-directory: mobile
        run: flutter pub get

      - name: Test plugin
        run: just test-ferrostar-flutter-plugin

      - name: Test app
        run: just test-mobile
```

Rationale: `flutter pub get` stays raw because `just setup-mobile` does both (plugin + app) together and we want separate CI step names. The test recipes internally run analyze then test.

- [ ] **Step 2: Update the `test-mobile-ios` job**

Replace the "Run integration smoke test" step. Keep `flutter config --enable-swift-package-manager`, `flutter build ios --no-codesign --simulator`, and the sim UDID detection+boot raw — they are CI-specific and would slow local dev if folded into the recipe. The final job:

```yaml
  test-mobile-ios:
    name: Flutter integration tests (iOS simulator)
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - uses: flutter-actions/setup-flutter@v3
        with:
          channel: stable

      - uses: extractions/setup-just@v3

      - name: Install dependencies (plugin)
        working-directory: packages/ferrostar_flutter
        run: flutter pub get

      - name: Install dependencies (app)
        working-directory: mobile
        run: flutter pub get

      - name: Boot iPhone 17 simulator
        run: |
          UDID=$(xcrun simctl list devices available --json \
            | python3 -c "
          import json,sys
          devs = json.load(sys.stdin)['devices']
          for runtime, devices in devs.items():
            for d in devices:
              if 'iPhone 17' in d['name'] and d['isAvailable']:
                print(d['udid']); exit()
          ")
          xcrun simctl boot "$UDID"
          echo "SIM_UDID=$UDID" >> "$GITHUB_ENV"

      - name: Enable Flutter SPM integration
        working-directory: mobile
        run: flutter config --enable-swift-package-manager

      - name: Build (simulator, no codesign)
        working-directory: mobile
        run: flutter build ios --no-codesign --simulator

      - name: Run integration smoke test
        run: just test-ios UDID=$SIM_UDID
```

- [ ] **Step 3: Verify**

Run: `cat .github/workflows/ci-mobile.yml`

Confirm: both jobs have the `extractions/setup-just@v3` step, test-mobile calls `just test-*` for the test steps, test-mobile-ios keeps raw sim setup and calls `just test-ios UDID=$SIM_UDID` at the end.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci-mobile.yml
git commit -m "ci: call just recipes from mobile test jobs"
```

---

## Task 7: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the current README**

Run: `cat README.md`

- [ ] **Step 2: Replace the Quickstart block**

Find:

```sh
./scripts/download_berlin_osm.sh
./scripts/download_berlin_tiles.sh
docker compose -f compose.yml -f compose.dev.yml up --build
```

Replace with:

```sh
brew install just   # one-time
just setup
just dev
```

- [ ] **Step 3: Replace the Mobile block**

Find:

```bash
cd mobile
flutter pub get
flutter run -d ios \
  --dart-define=BEEBEEBIKE_API_BASE_URL=http://127.0.0.1:3000 \
  --dart-define=BEEBEEBIKE_TILE_STYLE_URL=http://127.0.0.1:8080/tiles/assets/styles/colorful/style.json
```

Replace with:

```bash
just setup-mobile
just dev-ios-sim
```

- [ ] **Step 4: Verify**

Run: `cat README.md`

Confirm both blocks are replaced and the prose around them still reads correctly.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): use just recipes in quickstart and mobile sections"
```

---

## Task 8: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read current CLAUDE.md**

Run: `cat CLAUDE.md`

- [ ] **Step 2: Rewrite the "Build & Run" section**

Replace the entire "Build & Run" section (from its heading down to the "Architecture" heading) with this content:

```markdown
## Build & Run

All day-to-day commands run through `just`. Install once with `brew install just`, then `just` (no args) lists everything.

### Full stack (Docker Compose)

- Dev: `just dev` — full stack with hot-reload frontend (`compose.yml` + `compose.dev.yml`)
- Prod: `just release` — `compose.prod.yml`, detached, with rebuild

### Previewing changes when working in a worktree

Always do this when you have completed a unit of work.

`just preview` — copies `data/` from the main repo checkout if missing, picks a random port in 20000–30000, echoes the URL, and starts the dev stack with `VITE_DEV_PORT` set. Frontend has HMR — don't restart the stack after changes.

### Backend

- `just test-backend` — cargo test
- `just lint-backend` — fmt check + clippy with `-D warnings`
- `just fmt` — mutating `cargo fmt`

Backend uses `SQLX_OFFLINE=true` for Docker builds. Locally, sqlx connects to Postgres at build time for query checking.

### Web app (Svelte)

- `just setup-web` — `npm ci`
- `just build-web` — production build to `web/dist/`
- `just test-web` — build + vitest unit tests + mobile-style parity (same as CI `frontend` job)
- `just test-e2e` — Playwright chromium smoke (same as CI `frontend-e2e`). Requires one-time `npx playwright install chromium` from inside `web/`.

### Mobile app (iOS only)

- `just setup-mobile` — `flutter pub get` for plugin and app
- `just dev-ios-sim` — run on iOS simulator against local docker stack (defaults to 127.0.0.1)
- `just dev-ios-device <DEVICE>` — run on physical device against dev stack over LAN (auto-detects host IP via `ipconfig getifaddr en0`)
- `just release-ios-device <DEVICE>` — release-mode run against production URLs (`https://beebeebike.com`)
- `just test-mobile` — analyze + test for the app
- `just test-ferrostar-flutter-plugin` — analyze + test for the plugin at `packages/ferrostar_flutter/`
- `just test-ios [UDID=""]` — iOS sim integration smoke test; auto-picks an available iPhone 17 if `UDID` is empty

Platform scope: iOS only in v0.1. `ferrostar_flutter` at `packages/ferrostar_flutter/` is a path dependency and must be present.

### Map style (web + mobile)

The bicycle-planning visual style lives in `web/src/lib/bicycle-style.js` as `buildBicycleStyle`. Mobile bundles a pre-baked artifact at `mobile/assets/styles/beebeebike-style.json` whose URLs use `{{TILE_BASE}}`, swapped at runtime. After editing the shared builder, regenerate with `just build-mobile-style`. CI (`just test-web`) fails if the committed artifact diverges.

### Static data (not in repo)

OSM extract and vector tiles must be downloaded before first run: `just setup-data` (runs both `scripts/download_berlin_*.sh`).

### Clean

- `just clean` — clean everything (cargo, web, flutter, docker volumes)
- Subcommands: `clean-backend`, `clean-web`, `clean-mobile`, `clean-docker`
```

- [ ] **Step 3: Verify**

Run: `cat CLAUDE.md`

Confirm the Build & Run section uses `just` throughout, the Architecture section below it is untouched, and the CI/CD and migrations sections are untouched.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): use just recipes for all build/run commands"
```

---

## Task 9: End-to-end verification

**Files:** none

- [ ] **Step 1: Full recipe list**

Run: `just --list`

Expected: six groups with all recipes listed. Count: 4 setup (+ `default`), 4 dev, 7 test (`test`, `test-backend`, `test-web`, `test-e2e`, `test-mobile`, `test-ferrostar-flutter-plugin`, `test-ios`), 6 lint (`lint`, `lint-backend`, `lint-backend-fmt`, `lint-backend-clippy`, `fmt`, `lint-mobile`), 4 build, 5 clean. Adjust if something's missing.

- [ ] **Step 2: Backend lint locally**

Run: `just lint-backend`

Expected: exit 0. If it fails because code isn't formatted, that's a pre-existing issue unrelated to this plan — fix separately.

- [ ] **Step 3: Frontend build + style parity**

Run: `just setup-web && just test-web`

Expected: exit 0. The style parity check passes if the committed `mobile/assets/styles/beebeebike-style.json` matches regeneration.

- [ ] **Step 4: Confirm CI workflow files have no remaining raw commands we meant to migrate**

Run:

```bash
grep -nE 'cargo (fmt|clippy|test)|npm (run (build|test:e2e)|test)($| )' .github/workflows/ci.yml || echo "clean"
```

Expected: `clean`. (Workflows now call `just` for these.)

For `ci-mobile.yml`, the raw commands we intentionally kept are: `flutter pub get`, `flutter config`, `flutter build ios`, and the sim UDID boot block. Confirm `flutter analyze` and `flutter test integration_test` do NOT appear as raw step bodies:

```bash
grep -nE 'flutter (analyze|test integration_test)' .github/workflows/ci-mobile.yml || echo "clean"
```

Expected: `clean`.

- [ ] **Step 5: Open a PR**

Push the branch and open a PR. Watch CI. If any workflow step fails, fix the recipe or the workflow call, re-push. Do not merge until all checks green.
