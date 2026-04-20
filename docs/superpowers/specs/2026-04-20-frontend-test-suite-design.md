# Frontend Test Suite Design

Date: 2026-04-20
Scope: `web/` (Svelte 5 + Vite frontend)

## Goal

Add a frontend test suite: unit tests for pure logic, rune-stores, and component smoke; plus a Playwright e2e smoke test that boots the app in a real browser. Wire both into CI as parallel jobs.

## Stack

- **Vitest** — test runner, shares `vite.config.js`.
- **`@testing-library/svelte`** + **`@testing-library/jest-dom`** — component mount + DOM matchers.
- **`happy-dom`** — test environment (lighter than jsdom, good Svelte 5 compat).
- **`msw`** — fetch mocking for `api.js` and rune-stores that touch the network.
- **Playwright** (`@playwright/test`) with **chromium only** — e2e smoke.

### `web/package.json` scripts

- `test` — `vitest run`
- `test:watch` — `vitest`
- `test:e2e` — `playwright test`

Existing scripts (`dev`, `build`, `preview`, `build:mobile-style`) stay.

## Unit test layout

Tests co-located with source:

- `src/lib/foo.js` → `src/lib/foo.test.js`
- `src/lib/foo.svelte.js` → `src/lib/foo.svelte.test.js` (rune-stores)
- `src/components/Foo.svelte` → `src/components/Foo.test.js`

### Targets

| File | Test type | Focus |
|------|-----------|-------|
| `lib/api.js` | unit + msw | request shape, error handling, session cookie |
| `lib/bicycle-style.js` | unit | `buildBicycleStyle` returns valid style obj; `{{TILE_BASE}}` placeholder swap |
| `lib/overlay.js` | unit | GeoJSON FeatureCollection shape, rating→color mapping |
| `lib/paintGesture.js` | unit | gesture state machine |
| `lib/brush.svelte.js` | rune-store | brush size/rating mutations |
| `lib/auth.svelte.js` | rune-store + msw | login/logout/register state transitions |
| `lib/locations.svelte.js` | rune-store + msw | add/remove/list |
| `lib/preferences.svelte.js` | rune-store | persistence + defaults |
| `lib/routing.svelte.js` | rune-store + msw | route request/response, loading state |
| `components/AuthModal.svelte` | component smoke | renders; submit fires login |
| `components/PreferencesPanel.svelte` | component smoke | renders; toggles update store |
| `components/SearchBar.svelte` | component smoke | input + submit fires geocode |
| `components/Toolbar.svelte` | component smoke | buttons render, dispatch events |
| `components/WelcomeModal.svelte` | component smoke | renders, dismiss persists |
| `components/ZoomControls.svelte` | component smoke | +/- buttons fire |
| `components/RoutePanel.svelte` | component smoke | renders route summary |
| `components/Map.svelte` | **skip** | MapLibre WebGL, not unit-testable |

### Rune-store test pattern

Rune stores export `$state`-backed objects. Each store gets a `reset()` helper (added where absent) to restore defaults for test isolation.

```js
// lib/auth.svelte.test.js
import { describe, it, expect, beforeEach } from 'vitest';
import { auth } from './auth.svelte.js';

beforeEach(() => auth.reset());

it('login sets user on 200', async () => {
  // msw handler returns 200 with user payload
  await auth.login('a', 'b');
  expect(auth.user).toEqual({ id: '...', name: 'a' });
});
```

Test files importing rune state must be named `*.svelte.js` / `*.svelte.test.js` so the Svelte preprocessor runs on them.

### Setup file

`web/vitest.setup.js`:

- Import `@testing-library/jest-dom/vitest`.
- Start MSW server in `beforeAll`; reset handlers `afterEach`; close `afterAll`.
- `beforeEach`: `localStorage.clear()`.
- If any component imports `maplibre-gl` transitively, `vi.mock('maplibre-gl')` stubs it. Audit during implementation and mock only if needed.

### Vitest config

Shared `vite.config.js` gains a `test` block:

```js
test: {
  environment: 'happy-dom',
  setupFiles: ['./vitest.setup.js'],
  globals: false,
  include: ['src/**/*.{test,spec}.{js,svelte.js}'],
}
```

## Playwright e2e smoke

Config: `web/playwright.config.js`.

- `webServer`: `npm run build && npx vite preview --port 4173` (no docker required).
- `baseURL`: `http://localhost:4173`.
- Project: chromium only.
- `retries: process.env.CI ? 2 : 0`.
- `reporter: [['html'], ['list']]`.

Tests in `web/tests/e2e/smoke.spec.js`:

- **`app boots`** — navigate to `/`, assert `.maplibregl-canvas` visible, sign-in button visible.

Every spec registers a `page.on('console', ...)` + `page.on('pageerror', ...)` listener at start and asserts zero `error`-level console messages and zero uncaught exceptions at end. Shared via a fixture in `web/tests/e2e/fixtures.js`.

No backend calls asserted. Network calls are either absent (static assets) or left to 404 without failing the test.

## CI wiring

`.github/workflows/ci.yml`:

- Rename job `test-backend` → `backend`.
- Rename job `test-frontend` → `frontend`. Add `- run: npm test` step after `npm ci`, before `npm run build`. Keep mobile-style verify step.
- Add job `frontend-e2e`, parallel to `frontend`. Steps:
  1. `actions/checkout@v4`
  2. `actions/setup-node@v4` (node 22, npm cache)
  3. `npm ci` in `web`
  4. Cache `~/.cache/ms-playwright` keyed on `web/package-lock.json`
  5. `npx playwright install --with-deps chromium`
  6. `npm run build` in `web`
  7. `npm run test:e2e` in `web`
  8. On failure: `actions/upload-artifact@v4` with `web/playwright-report/` and `web/test-results/`.

`cd.yml` unchanged — it gates on the CI workflow's overall success, which covers the new/renamed jobs automatically.

## Files added / modified

### New

- `web/vitest.setup.js`
- `web/playwright.config.js`
- `web/tests/e2e/smoke.spec.js`
- `web/tests/e2e/fixtures.js` (console/pageerror assertion fixture)
- `web/src/lib/mocks/handlers.js` (MSW request handlers)
- `web/src/lib/mocks/server.js` (MSW server instance)
- Per-target `*.test.js` / `*.svelte.test.js` files alongside source.

### Modified

- `web/package.json` — scripts + devDependencies.
- `web/vite.config.js` — `test` block.
- `web/.gitignore` — add `playwright-report/`, `test-results/`, `coverage/`.
- `.github/workflows/ci.yml` — rename + new job.
- Rune-store files — add `reset()` where absent (minimal surface).

## Non-goals

- Cross-browser e2e (chromium only).
- Backend-wired e2e flows (auth, paint, route). Covered by backend Rust tests + Vitest msw-backed rune-store tests.
- `Map.svelte` unit tests (MapLibre WebGL).
- Visual regression / screenshot diff.
- Coverage gates (can add later).

## Success criteria

- `npm test` in `web/` runs Vitest and exits 0 with all targets green.
- `npm run test:e2e` in `web/` boots the app, smoke spec passes, zero console errors, zero uncaught exceptions.
- `ci.yml` has jobs `lint`, `backend`, `frontend`, `frontend-e2e`, all green on PRs touching `web/`.
