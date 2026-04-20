# Frontend Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Vitest unit tests (lib + components) and a Playwright chromium smoke spec, wired into CI as parallel jobs.

**Architecture:** Vitest runs under happy-dom with `@testing-library/svelte` for component mounts and MSW for fetch mocking. Rune stores tested as modules (reset state in `beforeEach`). Playwright boots `vite preview` and asserts no console errors on app load. CI renames `test-backend`→`backend`, `test-frontend`→`frontend`, adds parallel `frontend-e2e`.

**Tech Stack:** Vitest, `@testing-library/svelte`, `@testing-library/jest-dom`, happy-dom, MSW, `@playwright/test`.

**Spec:** [`docs/superpowers/specs/2026-04-20-frontend-test-suite-design.md`](../specs/2026-04-20-frontend-test-suite-design.md)

---

## File layout

**New files**

- `web/vitest.setup.js` — jest-dom matcher import, MSW lifecycle, localStorage clear, maplibre-gl mock.
- `web/src/mocks/handlers.js` — default MSW handlers for `/api/*`.
- `web/src/mocks/server.js` — MSW `setupServer` instance.
- `web/src/lib/api.test.js`
- `web/src/lib/bicycle-style.test.js`
- `web/src/lib/paintGesture.test.js`
- `web/src/lib/preferences.svelte.test.js`
- `web/src/lib/locations.svelte.test.js`
- `web/src/lib/auth.svelte.test.js`
- `web/src/lib/routing.svelte.test.js`
- `web/src/lib/brush.svelte.test.js`
- `web/src/lib/overlay.test.js`
- `web/src/components/AuthModal.test.js`
- `web/src/components/WelcomeModal.test.js`
- `web/src/components/ZoomControls.test.js`
- `web/src/components/Toolbar.test.js`
- `web/src/components/SearchBar.test.js`
- `web/src/components/PreferencesPanel.test.js`
- `web/src/components/RoutePanel.test.js`
- `web/playwright.config.js`
- `web/tests/e2e/fixtures.js` — console/pageerror-asserting test fixture.
- `web/tests/e2e/smoke.spec.js`

**Modified**

- `web/package.json` — add `test`, `test:watch`, `test:e2e` scripts; add devDependencies.
- `web/vite.config.js` — add `test` block.
- `web/.gitignore` — add `playwright-report/`, `test-results/`, `coverage/`.
- `.github/workflows/ci.yml` — rename `test-backend`→`backend`, `test-frontend`→`frontend`; add `frontend-e2e`.

No production source files are modified. Rune-store reset happens in tests via direct property assignment — no `reset()` helper added.

---

## Task 1: Install dev dependencies

**Files:**
- Modify: `web/package.json`

- [ ] **Step 1: Install packages**

Run (in `web/`):

```bash
npm install --save-dev \
  vitest@^2 \
  @vitest/ui@^2 \
  @testing-library/svelte@^5 \
  @testing-library/jest-dom@^6 \
  @testing-library/user-event@^14 \
  happy-dom@^15 \
  msw@^2 \
  @playwright/test@^1.48
```

Expected: `package.json` gains those entries under `devDependencies`; `package-lock.json` updates.

- [ ] **Step 2: Install Playwright chromium**

Run (in `web/`):

```bash
npx playwright install --with-deps chromium
```

Expected: chromium binary downloaded. On failure (e.g., no sudo), retry without `--with-deps`.

- [ ] **Step 3: Commit**

```bash
git add web/package.json web/package-lock.json
git commit -m "chore(web): add test deps (vitest, testing-library, msw, playwright)"
```

---

## Task 2: Vitest config + setup + MSW scaffolding

**Files:**
- Modify: `web/vite.config.js`
- Create: `web/vitest.setup.js`
- Create: `web/src/mocks/server.js`
- Create: `web/src/mocks/handlers.js`
- Modify: `web/package.json` (scripts)
- Modify: `web/.gitignore`

- [ ] **Step 1: Read current `web/vite.config.js`**

Read the existing file so you preserve Svelte plugin config.

- [ ] **Step 2: Add `test` block to `web/vite.config.js`**

Append to the existing `defineConfig` call (keeping existing plugins/server config):

```js
/// <reference types="vitest" />
// ... existing imports + defineConfig(...)
export default defineConfig({
  // ... existing plugins + server ...
  test: {
    environment: 'happy-dom',
    globals: false,
    setupFiles: ['./vitest.setup.js'],
    include: ['src/**/*.{test,spec}.{js,svelte.js}'],
    exclude: ['node_modules', 'dist', 'tests/e2e/**'],
    clearMocks: true,
  },
});
```

Adjust shape to match the current file (it may spread plugins into an array). Keep the `/// <reference types="vitest" />` at the top of the file.

- [ ] **Step 3: Create `web/src/mocks/handlers.js`**

```js
import { http, HttpResponse } from 'msw';

// Default handlers return 200 with realistic shapes. Override per test with server.use().
export const handlers = [
  http.get('/api/auth/me', () =>
    HttpResponse.json({ id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false })
  ),
  http.post('/api/auth/anonymous', () =>
    HttpResponse.json({ id: 'anon1', email: null, display_name: null, anonymous: true })
  ),
  http.post('/api/auth/login', () =>
    HttpResponse.json({ id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false })
  ),
  http.post('/api/auth/register', () =>
    HttpResponse.json({ id: 'u2', email: 'new@example.com', display_name: 'New', anonymous: false })
  ),
  http.post('/api/auth/logout', () => new HttpResponse(null, { status: 204 })),

  http.get('/api/locations/home', () => HttpResponse.json({ label: 'Home', lng: 13.4, lat: 52.5 })),
  http.put('/api/locations/home', async ({ request }) => HttpResponse.json(await request.json())),
  http.delete('/api/locations/home', () => new HttpResponse(null, { status: 204 })),

  http.get('/api/ratings', () =>
    HttpResponse.json({ type: 'FeatureCollection', features: [], can_undo: false, can_redo: false })
  ),
  http.put('/api/ratings/paint', () => HttpResponse.json({ can_undo: true, can_redo: false })),
  http.post('/api/ratings/undo', () => HttpResponse.json({ can_undo: false, can_redo: true })),
  http.post('/api/ratings/redo', () => HttpResponse.json({ can_undo: true, can_redo: false })),

  http.post('/api/route', () =>
    HttpResponse.json({
      geometry: { type: 'LineString', coordinates: [[13.4, 52.5], [13.41, 52.51]] },
      distance: 1200,
      time: 360,
    })
  ),

  http.get('/api/geocode', () =>
    HttpResponse.json({
      features: [
        {
          geometry: { coordinates: [13.4, 52.5] },
          properties: { name: 'Alexanderplatz', osm_key: 'place', osm_value: 'square' },
        },
      ],
    })
  ),
];
```

- [ ] **Step 4: Create `web/src/mocks/server.js`**

```js
import { setupServer } from 'msw/node';
import { handlers } from './handlers.js';

export const server = setupServer(...handlers);
```

- [ ] **Step 5: Create `web/vitest.setup.js`**

```js
import '@testing-library/jest-dom/vitest';
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest';
import { server } from './src/mocks/server.js';

// maplibre-gl loads WebGL on import; stub it so modules that import at the top level
// (e.g. lib/routing.svelte.js) don't blow up in happy-dom.
vi.mock('maplibre-gl', () => {
  class LngLatBounds {
    extend() { return this; }
  }
  class Marker {
    constructor() {}
    setLngLat() { return this; }
    addTo() { return this; }
    remove() { return this; }
    on() { return this; }
    getLngLat() { return { lng: 0, lat: 0 }; }
  }
  return {
    default: { LngLatBounds, Marker },
    LngLatBounds,
    Marker,
  };
});

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

beforeEach(() => {
  window.localStorage.clear();
});
```

- [ ] **Step 6: Add scripts to `web/package.json`**

Under `scripts`:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "build:mobile-style": "node scripts/build-mobile-style.mjs",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test"
  }
}
```

- [ ] **Step 7: Update `web/.gitignore`**

Append:

```
playwright-report/
test-results/
coverage/
```

- [ ] **Step 8: Smoke-run Vitest to verify toolchain**

Run (in `web/`):

```bash
npx vitest run --reporter=verbose
```

Expected: `No test files found` (exit 0 or a benign "no tests" exit). That confirms config parses, plugins load, happy-dom resolves. If it errors, fix before moving on.

- [ ] **Step 9: Commit**

```bash
git add web/vite.config.js web/vitest.setup.js web/src/mocks web/package.json web/package-lock.json web/.gitignore
git commit -m "chore(web): wire vitest config, msw scaffolding, test scripts"
```

---

## Task 3: Test `lib/bicycle-style.js`

**Files:**
- Create: `web/src/lib/bicycle-style.test.js`
- Test: `web/src/lib/bicycle-style.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect } from 'vitest';
import { buildBicycleStyle, COLORS } from './bicycle-style.js';

const opts = {
  tilesUrl: 'http://tiles.example/{z}/{x}/{y}',
  glyphsUrl: 'http://tiles.example/fonts/{fontstack}/{range}',
  spriteUrl: 'http://tiles.example/sprites/basics',
};

describe('buildBicycleStyle', () => {
  it('returns a style with name, glyphs, and sprite applied', () => {
    const style = buildBicycleStyle(opts);
    expect(style.name).toBe('beebeebike-bicycle-planning');
    expect(style.glyphs).toBe(opts.glyphsUrl);
    expect(style.sprite).toEqual([{ id: 'basics', url: opts.spriteUrl }]);
  });

  it('rewrites vector source tiles to the provided URL', () => {
    const style = buildBicycleStyle(opts);
    const vectorSources = Object.values(style.sources).filter(s => s.type === 'vector');
    expect(vectorSources.length).toBeGreaterThan(0);
    for (const src of vectorSources) {
      expect(src.tiles).toEqual([opts.tilesUrl]);
      expect(src.scheme).toBe('xyz');
    }
  });

  it('inserts the bike-priority layers', () => {
    const style = buildBicycleStyle(opts);
    const ids = style.layers.map(l => l.id);
    for (const expected of [
      'bike-cycleway',
      'bike-cycleway-casing',
      'bike-designated',
      'bike-street-corridor',
      'bike-arterial-caution',
      'bike-steps-caution',
    ]) {
      expect(ids).toContain(expected);
    }
  });

  it('exports the bicycle palette', () => {
    expect(COLORS.cycleway).toMatch(/^#[0-9a-f]{6}$/i);
    expect(Object.keys(COLORS)).toContain('background');
  });

  it('scales symbol text sizes when mobile: true', () => {
    const web = buildBicycleStyle(opts);
    const mobile = buildBicycleStyle({ ...opts, mobile: true });

    const pickText = style =>
      style.layers.find(
        l => l.type === 'symbol' && typeof l.layout?.['text-size'] === 'number'
      );
    const a = pickText(web);
    const b = pickText(mobile);
    if (a && b) {
      expect(b.layout['text-size']).toBeGreaterThan(a.layout['text-size']);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it passes**

Run (in `web/`):

```bash
npx vitest run src/lib/bicycle-style.test.js
```

Expected: 5 passing. (No implementation change required — `bicycle-style.js` is already written.)

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/bicycle-style.test.js
git commit -m "test(web): cover buildBicycleStyle palette, layers, url substitution"
```

---

## Task 4: Test `lib/paintGesture.js`

**Files:**
- Create: `web/src/lib/paintGesture.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { suppressNextMapClick, shouldSuppressMapClick } from './paintGesture.js';

describe('paintGesture', () => {
  beforeEach(() => vi.useFakeTimers({ shouldAdvanceTime: false }));
  afterEach(() => vi.useRealTimers());

  it('returns false before any suppression', () => {
    expect(shouldSuppressMapClick()).toBe(false);
  });

  it('returns true for 250ms after suppressNextMapClick', () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
    suppressNextMapClick();
    expect(shouldSuppressMapClick()).toBe(true);
    vi.setSystemTime(new Date('2026-01-01T00:00:00.249Z'));
    expect(shouldSuppressMapClick()).toBe(true);
    vi.setSystemTime(new Date('2026-01-01T00:00:00.251Z'));
    expect(shouldSuppressMapClick()).toBe(false);
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/paintGesture.test.js
```

Expected: 2 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/paintGesture.test.js
git commit -m "test(web): cover paintGesture click suppression window"
```

---

## Task 5: Test `lib/preferences.svelte.js`

**Files:**
- Create: `web/src/lib/preferences.svelte.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import {
  preferences,
  setRatingWeight,
  setDistanceInfluence,
  formatRatingWeight,
  formatDistanceInfluence,
} from './preferences.svelte.js';

beforeEach(() => {
  // Module-level $state retains values between tests; reset by invoking setters.
  setRatingWeight(0.5);
  setDistanceInfluence(70);
});

describe('preferences', () => {
  it('clamps ratingWeight to [0, 1]', () => {
    setRatingWeight(1.5);
    expect(preferences.ratingWeight).toBe(1);
    setRatingWeight(-0.2);
    expect(preferences.ratingWeight).toBe(0);
  });

  it('clamps distanceInfluence to [0, 100]', () => {
    setDistanceInfluence(150);
    expect(preferences.distanceInfluence).toBe(100);
    setDistanceInfluence(-5);
    expect(preferences.distanceInfluence).toBe(0);
  });

  it('falls back to defaults for NaN', () => {
    setRatingWeight('hello');
    expect(preferences.ratingWeight).toBe(0.5);
    setDistanceInfluence(undefined);
    expect(preferences.distanceInfluence).toBe(70);
  });

  it('persists ratingWeight to localStorage', () => {
    setRatingWeight(0.8);
    expect(window.localStorage.getItem('beebeebike.ratingWeight')).toBe('0.8');
  });

  it('persists distanceInfluence to localStorage', () => {
    setDistanceInfluence(42);
    expect(window.localStorage.getItem('beebeebike.distanceInfluence')).toBe('42');
  });

  it('formats for display', () => {
    expect(formatRatingWeight(0.75)).toBe('75%');
    expect(formatDistanceInfluence(42.6)).toBe('43');
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/preferences.svelte.test.js
```

Expected: 6 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/preferences.svelte.test.js
git commit -m "test(web): cover preferences clamping, persistence, formatting"
```

---

## Task 6: Test `lib/api.js` against MSW

**Files:**
- Create: `web/src/lib/api.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { api } from './api.js';

describe('api', () => {
  it('login posts JSON and returns the user', async () => {
    let captured;
    server.use(
      http.post('/api/auth/login', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ id: 'u1', email: captured.email });
      })
    );
    const user = await api.login('a@b.c', 'hunter22');
    expect(captured).toEqual({ email: 'a@b.c', password: 'hunter22' });
    expect(user).toEqual({ id: 'u1', email: 'a@b.c' });
  });

  it('register posts display_name', async () => {
    let captured;
    server.use(
      http.post('/api/auth/register', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ id: 'u2' });
      })
    );
    await api.register('x@y.z', 'password8', 'Sam');
    expect(captured).toEqual({ email: 'x@y.z', password: 'password8', display_name: 'Sam' });
  });

  it('logout returns null on 204', async () => {
    expect(await api.logout()).toBeNull();
  });

  it('getOverlay passes bbox in querystring', async () => {
    let url;
    server.use(
      http.get('/api/ratings', ({ request }) => {
        url = new URL(request.url);
        return HttpResponse.json({ type: 'FeatureCollection', features: [] });
      })
    );
    await api.getOverlay('1,2,3,4');
    expect(url.searchParams.get('bbox')).toBe('1,2,3,4');
  });

  it('paint includes target_id when provided, omits when null', async () => {
    const bodies = [];
    server.use(
      http.put('/api/ratings/paint', async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json({ can_undo: true, can_redo: false });
      })
    );
    const geom = { type: 'Polygon', coordinates: [] };
    await api.paint(geom, 3);
    await api.paint(geom, -7, 42);
    expect(bodies[0]).toEqual({ geometry: geom, value: 3 });
    expect(bodies[1]).toEqual({ geometry: geom, value: -7, target_id: 42 });
  });

  it('route posts origin/destination + tuning', async () => {
    let captured;
    server.use(
      http.post('/api/route', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ geometry: {}, distance: 0, time: 0 });
      })
    );
    await api.route([1, 2], [3, 4], 0.5, 70);
    expect(captured).toEqual({
      origin: [1, 2],
      destination: [3, 4],
      rating_weight: 0.5,
      distance_influence: 70,
    });
  });

  it('geocode URL-encodes the query', async () => {
    let url;
    server.use(
      http.get('/api/geocode', ({ request }) => {
        url = new URL(request.url);
        return HttpResponse.json({ features: [] });
      })
    );
    await api.geocode('hello world & friends');
    expect(url.searchParams.get('q')).toBe('hello world & friends');
  });

  it('throws with status and error message on non-2xx JSON', async () => {
    server.use(
      http.post('/api/auth/login', () =>
        HttpResponse.json({ error: 'bad creds' }, { status: 401 })
      )
    );
    await expect(api.login('a', 'b')).rejects.toMatchObject({
      message: 'bad creds',
      status: 401,
    });
  });

  it('throws with statusText on non-JSON error', async () => {
    server.use(
      http.post('/api/auth/login', () => new HttpResponse('oops', { status: 500 }))
    );
    await expect(api.login('a', 'b')).rejects.toMatchObject({ status: 500 });
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/api.test.js
```

Expected: 9 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/api.test.js
git commit -m "test(web): cover api.js request shapes and error paths"
```

---

## Task 7: Test `lib/auth.svelte.js`

**Files:**
- Create: `web/src/lib/auth.svelte.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { auth, checkSession, login, register, logout } from './auth.svelte.js';

beforeEach(() => {
  auth.user = null;
  auth.ready = false;
  auth.isNewSession = false;
});

describe('auth store', () => {
  it('checkSession uses the existing session when /me succeeds', async () => {
    await checkSession();
    expect(auth.user).toEqual({
      id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false,
    });
    expect(auth.ready).toBe(true);
    expect(auth.isNewSession).toBe(false);
  });

  it('checkSession falls back to anonymous when /me 401s', async () => {
    server.use(
      http.get('/api/auth/me', () => HttpResponse.json({ error: 'no session' }, { status: 401 }))
    );
    await checkSession();
    expect(auth.isNewSession).toBe(true);
    expect(auth.user).toMatchObject({ anonymous: true });
    expect(auth.ready).toBe(true);
  });

  it('checkSession sets user=null when both /me and /anonymous fail', async () => {
    server.use(
      http.get('/api/auth/me', () => HttpResponse.json({ error: 'no' }, { status: 401 })),
      http.post('/api/auth/anonymous', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await checkSession();
    expect(auth.user).toBeNull();
    expect(auth.ready).toBe(true);
  });

  it('login sets user and ready', async () => {
    await login('u@example.com', 'hunter22');
    expect(auth.user).toMatchObject({ id: 'u1', email: 'u@example.com' });
    expect(auth.ready).toBe(true);
  });

  it('register sets user and ready', async () => {
    await register('new@example.com', 'hunter22', 'New');
    expect(auth.user).toMatchObject({ id: 'u2', display_name: 'New' });
    expect(auth.ready).toBe(true);
  });

  it('logout swaps user for a fresh anonymous identity', async () => {
    auth.user = { id: 'u1', anonymous: false };
    await logout();
    expect(auth.user).toMatchObject({ id: 'anon1', anonymous: true });
    expect(auth.ready).toBe(true);
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/auth.svelte.test.js
```

Expected: 6 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/auth.svelte.test.js
git commit -m "test(web): cover auth rune store state transitions"
```

---

## Task 8: Test `lib/locations.svelte.js`

**Files:**
- Create: `web/src/lib/locations.svelte.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import {
  locations,
  loadHomeLocation,
  saveHomeLocation,
  resetHomeLocation,
  setStartAtHome,
  routePointFromLocation,
} from './locations.svelte.js';

beforeEach(() => {
  locations.home = null;
  locations.startAtHome = false;
  locations.ready = false;
  locations.saving = false;
  locations.error = null;
});

describe('locations store', () => {
  it('loadHomeLocation sets home and startAtHome=true when the server has one', async () => {
    await loadHomeLocation();
    expect(locations.home).toEqual({ label: 'Home', lng: 13.4, lat: 52.5 });
    expect(locations.startAtHome).toBe(true);
    expect(locations.ready).toBe(true);
  });

  it('loadHomeLocation rethrows and sets error on 5xx', async () => {
    server.use(
      http.get('/api/locations/home', () => HttpResponse.json({ error: 'db' }, { status: 500 }))
    );
    await expect(loadHomeLocation()).rejects.toThrow('db');
    expect(locations.home).toBeNull();
    expect(locations.startAtHome).toBe(false);
    expect(locations.error).toBe('db');
    expect(locations.ready).toBe(true);
  });

  it('saveHomeLocation sends label/lng/lat and updates store', async () => {
    let body;
    server.use(
      http.put('/api/locations/home', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(body);
      })
    );
    const saved = await saveHomeLocation({ name: 'My place', lng: 13.3, lat: 52.4 });
    expect(body).toEqual({ label: 'My place', lng: 13.3, lat: 52.4 });
    expect(saved).toEqual(body);
    expect(locations.home).toEqual(body);
    expect(locations.startAtHome).toBe(true);
    expect(locations.saving).toBe(false);
  });

  it('saveHomeLocation returns null and does nothing when point is falsy', async () => {
    const result = await saveHomeLocation(null);
    expect(result).toBeNull();
    expect(locations.home).toBeNull();
  });

  it('resetHomeLocation clears home and startAtHome', async () => {
    locations.home = { label: 'x', lng: 1, lat: 2 };
    locations.startAtHome = true;
    await resetHomeLocation();
    expect(locations.home).toBeNull();
    expect(locations.startAtHome).toBe(false);
  });

  it('setStartAtHome requires a home to enable', () => {
    setStartAtHome(true);
    expect(locations.startAtHome).toBe(false);
    locations.home = { label: 'x', lng: 1, lat: 2 };
    setStartAtHome(true);
    expect(locations.startAtHome).toBe(true);
    setStartAtHome(false);
    expect(locations.startAtHome).toBe(false);
  });

  it('routePointFromLocation maps fields and returns null for empty input', () => {
    expect(routePointFromLocation(null)).toBeNull();
    expect(routePointFromLocation({ label: 'Home', name: 'home', lng: 1, lat: 2 })).toEqual({
      lng: 1, lat: 2, name: 'Home', savedLocationName: 'home',
    });
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/locations.svelte.test.js
```

Expected: 7 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/locations.svelte.test.js
git commit -m "test(web): cover locations rune store CRUD + startAtHome"
```

---

## Task 9: Test `lib/routing.svelte.js` (pure paths only)

`computeRoute` and map-marker code paths need a real map — skip those. Test the pure branches.

**Files:**
- Create: `web/src/lib/routing.svelte.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { route, clearRoute, applyStartAtHome } from './routing.svelte.js';
import { locations } from './locations.svelte.js';

beforeEach(() => {
  route.origin = null;
  route.destination = null;
  route.data = null;
  route.loading = false;
  locations.home = null;
  locations.startAtHome = false;
});

describe('routing store', () => {
  it('clearRoute resets state when startAtHome is off', () => {
    route.origin = { lng: 1, lat: 2, name: 'A' };
    route.destination = { lng: 3, lat: 4, name: 'B' };
    route.data = { geometry: {}, distance: 1, time: 2 };
    clearRoute();
    expect(route.origin).toBeNull();
    expect(route.destination).toBeNull();
    expect(route.data).toBeNull();
  });

  it('clearRoute refills origin from home when startAtHome is on', () => {
    locations.home = { label: 'Home', name: 'home', lng: 13.4, lat: 52.5 };
    locations.startAtHome = true;
    route.destination = { lng: 3, lat: 4, name: 'B' };
    clearRoute();
    expect(route.origin).toEqual({
      lng: 13.4, lat: 52.5, name: 'Home', savedLocationName: 'home',
    });
    expect(route.destination).toBeNull();
  });

  it('applyStartAtHome is a no-op when startAtHome is off', () => {
    applyStartAtHome();
    expect(route.origin).toBeNull();
  });

  it('applyStartAtHome seeds origin when no existing route', () => {
    locations.home = { label: 'Home', name: 'home', lng: 1, lat: 2 };
    locations.startAtHome = true;
    applyStartAtHome();
    expect(route.origin).toMatchObject({ lng: 1, lat: 2, savedLocationName: 'home' });
  });

  it('applyStartAtHome does not overwrite an existing destination/data', () => {
    locations.home = { label: 'Home', name: 'home', lng: 1, lat: 2 };
    locations.startAtHome = true;
    route.destination = { lng: 9, lat: 9, name: 'B' };
    applyStartAtHome();
    expect(route.origin).toBeNull();
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/routing.svelte.test.js
```

Expected: 5 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/routing.svelte.test.js
git commit -m "test(web): cover routing store pure state transitions"
```

---

## Task 10: Test `lib/brush.svelte.js` (state only)

Paint logic requires a real MapLibre canvas — skip. Test exports + `togglePaintMode` state flip.

**Files:**
- Create: `web/src/lib/brush.svelte.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { brush, ratingTools, togglePaintMode } from './brush.svelte.js';

beforeEach(() => {
  brush.value = 1;
  brush.size = 30;
  brush.canUndo = false;
  brush.canRedo = false;
  brush.paintMode = false;
});

describe('brush store', () => {
  it('exposes the seven rating tools including eraser', () => {
    expect(ratingTools.map(t => t.value)).toEqual([-7, -3, -1, 0, 1, 3, 7]);
    expect(ratingTools.find(t => t.value === 0)).toBeDefined();
  });

  it('togglePaintMode flips the flag without a map', () => {
    expect(brush.paintMode).toBe(false);
    togglePaintMode();
    expect(brush.paintMode).toBe(true);
    togglePaintMode();
    expect(brush.paintMode).toBe(false);
  });

  it('allows direct state mutation for size/value', () => {
    brush.value = -3;
    brush.size = 50;
    expect(brush.value).toBe(-3);
    expect(brush.size).toBe(50);
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/brush.svelte.test.js
```

Expected: 3 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/brush.svelte.test.js
git commit -m "test(web): cover brush store ratings + paintMode toggle"
```

---

## Task 11: Test `lib/overlay.js` with a fake map

`overlay.js` only adds sources/layers + wires `moveend`. Use a minimal fake map.

**Files:**
- Create: `web/src/lib/overlay.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { initOverlay, refreshOverlay } from './overlay.js';

function makeFakeMap() {
  const sources = new Map();
  const layers = new Map();
  const source = {
    data: null,
    setData(d) { this.data = d; },
  };
  return {
    sources,
    layers,
    setData(data) { source.data = data; },
    addSource(id, def) { sources.set(id, { ...def, ...source }); },
    addLayer(def) { layers.set(def.id, def); },
    getSource(id) { return sources.get(id); },
    getLayer(id) { return layers.get(id); },
    on: vi.fn(),
    off: vi.fn(),
    getBounds: () => ({ getWest: () => 1, getSouth: () => 2, getEast: () => 3, getNorth: () => 4 }),
  };
}

// initOverlay is module-singletoned; reset by reloading the module per test.
let freshOverlay;
beforeEach(async () => {
  vi.resetModules();
  freshOverlay = await import('./overlay.js');
});

describe('overlay', () => {
  it('adds the ratings source and fill/outline layers on initOverlay', () => {
    const map = makeFakeMap();
    freshOverlay.initOverlay(map);
    expect(map.sources.has('ratings')).toBe(true);
    expect(map.layers.has('ratings-fill')).toBe(true);
    expect(map.layers.has('ratings-outline')).toBe(true);
    const fill = map.layers.get('ratings-fill');
    expect(fill.paint['fill-color'][0]).toBe('match');
  });

  it('refreshOverlay pushes the fetched GeoJSON into the ratings source', async () => {
    const fc = {
      type: 'FeatureCollection',
      features: [],
      can_undo: true,
      can_redo: false,
    };
    server.use(http.get('/api/ratings', () => HttpResponse.json(fc)));

    const map = makeFakeMap();
    freshOverlay.initOverlay(map);
    const source = map.getSource('ratings');

    const data = await freshOverlay.refreshOverlay(map);
    expect(data).toEqual(fc);
    expect(source.data).toEqual(fc);
  });

  it('refreshOverlay returns null when not initialized', async () => {
    const map = makeFakeMap();
    expect(await freshOverlay.refreshOverlay(map)).toBeNull();
  });

  it('registers a moveend listener on init', () => {
    const map = makeFakeMap();
    freshOverlay.initOverlay(map);
    expect(map.on).toHaveBeenCalledWith('moveend', expect.any(Function));
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/lib/overlay.test.js
```

Expected: 4 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/overlay.test.js
git commit -m "test(web): cover overlay init + refresh against fake map"
```

---

## Task 12: Test `components/AuthModal.svelte`

**Files:**
- Create: `web/src/components/AuthModal.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { auth } from '../lib/auth.svelte.js';
import AuthModal from './AuthModal.svelte';

beforeEach(() => {
  auth.user = null;
  auth.ready = false;
});

describe('AuthModal', () => {
  it('renders the login form by default', () => {
    render(AuthModal, { initialMode: 'login', onclose: () => {} });
    expect(screen.getByRole('heading', { name: /log in/i })).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/email/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^log in$/i })).toBeInTheDocument();
  });

  it('submits login and calls onclose on success', async () => {
    const onclose = vi.fn();
    render(AuthModal, { initialMode: 'login', onclose });

    await fireEvent.input(screen.getByPlaceholderText(/email/i), { target: { value: 'u@example.com' } });
    await fireEvent.input(screen.getByPlaceholderText(/password/i), { target: { value: 'hunter22' } });
    await fireEvent.submit(screen.getByRole('button', { name: /^log in$/i }).closest('form'));

    await vi.waitFor(() => expect(onclose).toHaveBeenCalled());
    expect(auth.user).toMatchObject({ id: 'u1' });
  });

  it('shows error message on login failure', async () => {
    server.use(
      http.post('/api/auth/login', () => HttpResponse.json({ error: 'nope' }, { status: 401 }))
    );
    render(AuthModal, { initialMode: 'login', onclose: () => {} });

    await fireEvent.input(screen.getByPlaceholderText(/email/i), { target: { value: 'u@example.com' } });
    await fireEvent.input(screen.getByPlaceholderText(/password/i), { target: { value: 'hunter22' } });
    await fireEvent.submit(screen.getByPlaceholderText(/email/i).closest('form'));

    expect(await screen.findByText('nope')).toBeInTheDocument();
  });

  it('switches to register mode and exposes the display name field', async () => {
    render(AuthModal, { initialMode: 'login', onclose: () => {} });
    await fireEvent.click(screen.getByRole('button', { name: /sign up/i }));
    expect(screen.getByPlaceholderText(/display name/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/AuthModal.test.js
```

Expected: 4 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/AuthModal.test.js
git commit -m "test(web): smoke AuthModal renders, submits, error, mode switch"
```

---

## Task 13: Test `components/WelcomeModal.svelte`

**Files:**
- Create: `web/src/components/WelcomeModal.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import WelcomeModal from './WelcomeModal.svelte';

describe('WelcomeModal', () => {
  it('renders the welcome heading and CTA', () => {
    render(WelcomeModal, { onclose: () => {} });
    expect(screen.getByRole('heading', { name: /welcome to beebeebike/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /start exploring/i })).toBeInTheDocument();
  });

  it('invokes onclose when CTA clicked', async () => {
    const onclose = vi.fn();
    render(WelcomeModal, { onclose });
    await fireEvent.click(screen.getByRole('button', { name: /start exploring/i }));
    expect(onclose).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/WelcomeModal.test.js
```

Expected: 2 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/WelcomeModal.test.js
git commit -m "test(web): smoke WelcomeModal renders + onclose"
```

---

## Task 14: Test `components/ZoomControls.svelte`

**Files:**
- Create: `web/src/components/ZoomControls.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import ZoomControls from './ZoomControls.svelte';

describe('ZoomControls', () => {
  it('renders zoom in/out buttons', () => {
    render(ZoomControls, { map: null });
    expect(screen.getByRole('button', { name: /zoom in/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /zoom out/i })).toBeInTheDocument();
  });

  it('calls map.zoomIn and map.zoomOut when the buttons are clicked', async () => {
    const map = { zoomIn: vi.fn(), zoomOut: vi.fn() };
    render(ZoomControls, { map });
    await fireEvent.click(screen.getByRole('button', { name: /zoom in/i }));
    await fireEvent.click(screen.getByRole('button', { name: /zoom out/i }));
    expect(map.zoomIn).toHaveBeenCalledOnce();
    expect(map.zoomOut).toHaveBeenCalledOnce();
  });

  it('is safe when map is undefined', async () => {
    render(ZoomControls, { map: null });
    await fireEvent.click(screen.getByRole('button', { name: /zoom in/i }));
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/ZoomControls.test.js
```

Expected: 3 passing.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/ZoomControls.test.js
git commit -m "test(web): smoke ZoomControls forwards to map.zoomIn/Out"
```

---

## Task 15: Test `components/Toolbar.svelte`

**Files:**
- Create: `web/src/components/Toolbar.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { brush } from '../lib/brush.svelte.js';
import Toolbar from './Toolbar.svelte';

beforeEach(() => {
  brush.value = 1;
  brush.size = 30;
  brush.canUndo = false;
  brush.canRedo = false;
  brush.paintMode = false;
});

describe('Toolbar', () => {
  it('renders seven color buttons', () => {
    render(Toolbar);
    const colorButtons = screen.getAllByRole('button').filter(b => b.title?.match(/Eraser|^\d+:/));
    expect(colorButtons.length).toBe(7);
  });

  it('clicking a color button updates brush.value', async () => {
    render(Toolbar);
    const minusSeven = screen.getByRole('button', { name: '1' });
    await fireEvent.click(minusSeven);
    expect(brush.value).toBe(-7);
  });

  it('undo/redo buttons are disabled when state flags are false', () => {
    render(Toolbar);
    const undo = screen.getByRole('button', { name: /undo/i });
    expect(undo).toBeDisabled();
  });

  it('paint toggle flips brush.paintMode', async () => {
    render(Toolbar);
    const toggle = screen.getByRole('button', { name: /paint mode/i });
    await fireEvent.click(toggle);
    expect(brush.paintMode).toBe(true);
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/Toolbar.test.js
```

Expected: 4 passing. If `togglePaintMode` fails because `syncCursor` touches the DOM canvas, the `if (!currentMap) return;` guard already covers it — verify by reading `brush.svelte.js` if a failure happens.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/Toolbar.test.js
git commit -m "test(web): smoke Toolbar color picker, undo state, paint toggle"
```

---

## Task 16: Test `components/SearchBar.svelte`

**Files:**
- Create: `web/src/components/SearchBar.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { route } from '../lib/routing.svelte.js';
import { locations } from '../lib/locations.svelte.js';
import SearchBar from './SearchBar.svelte';

beforeEach(() => {
  route.origin = null;
  route.destination = null;
  route.data = null;
  locations.home = null;
  locations.startAtHome = false;
  vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] });
});

function flushDebounce(ms = 301) {
  vi.advanceTimersByTime(ms);
  return Promise.resolve();
}

describe('SearchBar', () => {
  it('renders the origin placeholder and preferences toggle', () => {
    render(SearchBar);
    expect(screen.getByPlaceholderText(/search origin/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /preferences/i })).toBeInTheDocument();
  });

  it('queries geocode after debounce and shows results', async () => {
    server.use(
      http.get('/api/geocode', () =>
        HttpResponse.json({
          features: [
            { geometry: { coordinates: [13.4, 52.5] }, properties: { name: 'Alexanderplatz' } },
          ],
        })
      )
    );
    render(SearchBar);
    const input = screen.getByPlaceholderText(/search origin/i);
    await fireEvent.input(input, { target: { value: 'alex' } });
    await flushDebounce();
    expect(await screen.findByText('Alexanderplatz')).toBeInTheDocument();
  });

  it('ignores queries shorter than 2 characters', async () => {
    const seen = vi.fn();
    server.use(
      http.get('/api/geocode', () => { seen(); return HttpResponse.json({ features: [] }); })
    );
    render(SearchBar);
    const input = screen.getByPlaceholderText(/search origin/i);
    await fireEvent.input(input, { target: { value: 'a' } });
    await flushDebounce();
    expect(seen).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/SearchBar.test.js
```

Expected: 3 passing. If fake timers fight the fetch Promise, drop fake timers and use `vi.waitFor(..., { timeout: 1000 })` to await the debounced call.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/SearchBar.test.js
git commit -m "test(web): smoke SearchBar debounce + geocode results render"
```

---

## Task 17: Test `components/PreferencesPanel.svelte`

**Files:**
- Create: `web/src/components/PreferencesPanel.test.js`

The component renders two range inputs with ids `rating-weight` (min=0, max=1, step=0.05) and `distance-influence` (min=0, max=100, step=5), a label "Preference strength" for the first, "Route directness" for the second, and formatted values next to each.

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { preferences, setRatingWeight, setDistanceInfluence } from '../lib/preferences.svelte.js';
import PreferencesPanel from './PreferencesPanel.svelte';

beforeEach(() => {
  setRatingWeight(0.5);
  setDistanceInfluence(70);
});

describe('PreferencesPanel', () => {
  it('renders the two labelled range inputs with current values', () => {
    render(PreferencesPanel);
    const rating = screen.getByLabelText(/preference strength/i);
    const distance = screen.getByLabelText(/route directness/i);
    expect(rating).toHaveAttribute('type', 'range');
    expect(distance).toHaveAttribute('type', 'range');
    expect(rating.value).toBe('0.5');
    expect(distance.value).toBe('70');
  });

  it('renders the formatted current values', () => {
    render(PreferencesPanel);
    expect(screen.getByText('50%')).toBeInTheDocument();
    expect(screen.getByText('70')).toBeInTheDocument();
  });

  it('input on the rating slider persists to the store', async () => {
    render(PreferencesPanel);
    const rating = screen.getByLabelText(/preference strength/i);
    await fireEvent.input(rating, { target: { value: '0.8' } });
    expect(preferences.ratingWeight).toBeCloseTo(0.8);
  });

  it('input on the distance slider persists to the store', async () => {
    render(PreferencesPanel);
    const distance = screen.getByLabelText(/route directness/i);
    await fireEvent.input(distance, { target: { value: '25' } });
    expect(preferences.distanceInfluence).toBe(25);
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/PreferencesPanel.test.js
```

Expected: 4 passing.

- [ ] **Step 3: Commit

```bash
git add web/src/components/PreferencesPanel.test.js
git commit -m "test(web): smoke PreferencesPanel renders + persists slider changes"
```

---

## Task 18: Test `components/RoutePanel.svelte`

**Files:**
- Create: `web/src/components/RoutePanel.test.js`

RoutePanel renders nothing unless `route.loading` is true or `route.data` is set. When loading: "Computing route..." + spinner. When data set: `formatDist(meters)` ("X.Y km" ≥1000, "X m" <1000) and `formatTime(ms)` ("X min" <60, "Xh Ym" ≥60).

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { route } from '../lib/routing.svelte.js';
import RoutePanel from './RoutePanel.svelte';

beforeEach(() => {
  route.origin = null;
  route.destination = null;
  route.data = null;
  route.loading = false;
});

describe('RoutePanel', () => {
  it('renders nothing when no route is loading and no data', () => {
    const { container } = render(RoutePanel);
    expect(container.textContent.trim()).toBe('');
  });

  it('shows a computing message while loading', () => {
    route.loading = true;
    render(RoutePanel);
    expect(screen.getByText(/computing route/i)).toBeInTheDocument();
  });

  it('renders km + minutes from route.data', () => {
    route.data = {
      geometry: { type: 'LineString', coordinates: [] },
      distance: 2500,   // 2.5 km
      time: 600_000,    // 10 min
    };
    render(RoutePanel);
    expect(screen.getByText('2.5 km')).toBeInTheDocument();
    expect(screen.getByText('10 min')).toBeInTheDocument();
  });

  it('uses metres for sub-kilometre routes and h/m for long ones', () => {
    route.data = {
      geometry: { type: 'LineString', coordinates: [] },
      distance: 450,
      time: 60 * 60 * 1000 + 5 * 60 * 1000, // 1h 5m
    };
    render(RoutePanel);
    expect(screen.getByText('450 m')).toBeInTheDocument();
    expect(screen.getByText('1h 5m')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test**

```bash
npx vitest run src/components/RoutePanel.test.js
```

Expected: 4 passing.

- [ ] **Step 3: Commit

```bash
git add web/src/components/RoutePanel.test.js
git commit -m "test(web): smoke RoutePanel empty + with route data"
```

---

## Task 19: Full Vitest sweep

- [ ] **Step 1: Run all Vitest tests**

```bash
npx vitest run
```

Expected: every test from tasks 3–18 passes. Fix any failure before proceeding; do not move on with red tests.

- [ ] **Step 2: (Optional) no commit** — no changes unless you fixed something.

---

## Task 20: Playwright config

**Files:**
- Create: `web/playwright.config.js`

- [ ] **Step 1: Write the config**

```js
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: {
    command: 'npm run build && npx vite preview --port 4173 --host 127.0.0.1',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

- [ ] **Step 2: Commit**

```bash
git add web/playwright.config.js
git commit -m "chore(web): add Playwright config (chromium, vite preview)"
```

---

## Task 21: Playwright fixture asserting zero console errors

**Files:**
- Create: `web/tests/e2e/fixtures.js`

- [ ] **Step 1: Write the fixture**

```js
import { test as base, expect } from '@playwright/test';

// Extends base `test` with auto-collected console + pageerror logs and asserts
// they are empty at the end of each test.
export const test = base.extend({
  page: async ({ page }, use) => {
    const consoleErrors = [];
    const pageErrors = [];

    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', err => pageErrors.push(err.message));

    await use(page);

    expect(consoleErrors, 'browser console errors').toEqual([]);
    expect(pageErrors, 'uncaught page exceptions').toEqual([]);
  },
});

export { expect };
```

- [ ] **Step 2: Commit**

```bash
git add web/tests/e2e/fixtures.js
git commit -m "test(web): e2e fixture that fails on console errors + pageerror"
```

---

## Task 22: Playwright smoke spec

**Files:**
- Create: `web/tests/e2e/smoke.spec.js`

- [ ] **Step 1: Write the failing test**

```js
import { test, expect } from './fixtures.js';

test('app boots with a map canvas visible and no console errors', async ({ page }) => {
  await page.goto('/');

  // MapLibre canvas must be attached. It may not be visible yet if tiles are slow —
  // wait for the canvas to exist and its bounding box to be non-empty.
  const canvas = page.locator('canvas.maplibregl-canvas');
  await expect(canvas).toBeAttached({ timeout: 15_000 });
  const box = await canvas.boundingBox();
  expect(box?.width).toBeGreaterThan(0);
  expect(box?.height).toBeGreaterThan(0);

  // Settle — give lazily-loaded code a chance to raise any import/init errors
  // before the fixture asserts on console state.
  await page.waitForTimeout(1_000);
});
```

- [ ] **Step 2: Run Playwright locally**

```bash
npx playwright test
```

Expected: 1 passed. `vite preview` auto-starts. If tile server calls generate 404s, those show as network failures, not console errors — the assertion only checks `console.error` level messages and uncaught JS exceptions.

If the test fails on console errors, read the failure, decide whether it's a real regression in the app or noise (e.g., a MapLibre warning that got logged at error level). If it's noise, narrow the fixture filter — do not relax the assertion globally.

- [ ] **Step 3: Commit**

```bash
git add web/tests/e2e/smoke.spec.js
git commit -m "test(web): Playwright smoke asserts map canvas + clean console"
```

---

## Task 23: Rename CI jobs and add `frontend-e2e`

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read current `ci.yml`**

Confirm current layout (jobs `lint`, `test-backend`, `test-frontend`).

- [ ] **Step 2: Rename `test-backend` to `backend`**

Change `test-backend:` to `backend:` on the job key. No other fields change.

- [ ] **Step 3: Rename `test-frontend` to `frontend`; add `npm test` step**

Change the job key from `test-frontend:` to `frontend:`. Insert `- run: npm test` after `- run: npm ci` and before `- run: npm run build`. The final job should look like:

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
      - run: npm test
        working-directory: web
      - run: npm run build
        working-directory: web
      - name: regenerate mobile style and verify it matches committed artifact
        run: |
          npm --prefix web run build:mobile-style
          git diff --exit-code mobile/assets/styles/beebeebike-style.json
```

- [ ] **Step 4: Add `frontend-e2e` job**

Append after `frontend:`:

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
      - run: npm run build
        working-directory: web
      - run: npm run test:e2e
        working-directory: web
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

- [ ] **Step 5: Verify the YAML is valid**

Run:

```bash
python3 -c 'import yaml, sys; yaml.safe_load(open(".github/workflows/ci.yml"))'
```

Expected: no output (valid). If `yaml` is not installed, `npx --yes js-yaml .github/workflows/ci.yml` also works.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: rename test-* jobs; add frontend-e2e Playwright job"
```

---

## Task 24: Final verification

- [ ] **Step 1: Full local run**

```bash
cd web
npm test
npm run build
npm run test:e2e
```

Expected: all green. Vitest reports ~55 passing across the lib + component suites. Playwright reports 1 passing.

- [ ] **Step 2: Review artifacts**

```bash
ls web/playwright-report/
```

Expected: directory exists and contains `index.html`. The `playwright-report/` entry in `.gitignore` from Task 2 keeps it out of git.

- [ ] **Step 3: Push the branch and confirm CI**

```bash
git push -u origin HEAD
```

Open the PR (or watch the push CI run); confirm jobs `lint`, `backend`, `frontend`, `frontend-e2e` all pass.

- [ ] **Step 4: (No commit unless fixes needed.)**
