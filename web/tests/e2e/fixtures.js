import { test as base, expect } from '@playwright/test';

// Minimal 1×1 transparent PNG for the sprite atlas image.
const TRANSPARENT_1X1_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);

export const test = base.extend({
  page: async ({ page }, use) => {
    const consoleErrors = [];
    const pageErrors = [];

    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', err => pageErrors.push(err.message));

    // Stub backend API calls so the app boots cleanly without a running server.
    //
    // - GET  /api/auth/me        → 200 anonymous user (returning 401 causes
    //                             Chrome to emit a "Failed to load resource" console error)
    // - GET  /api/ratings?bbox=… → 200 empty FeatureCollection (overlay logs
    //                             console.error on fetch failure)
    // - GET  /api/locations/home → 204 no content (app treats null as "no home";
    //                             avoids Chrome logging a 4xx as console.error)
    // - everything else          → 200 empty JSON
    await page.route('**/api/**', route => {
      const url = route.request().url();
      const method = route.request().method();

      if (url.includes('/api/auth/me') && method === 'GET') {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ id: 'anon-stub', account_type: 'anonymous', anonymous: true }),
        });
      }
      if (url.includes('/api/ratings') && method === 'GET') {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ type: 'FeatureCollection', features: [] }),
        });
      }
      if (url.includes('/api/locations/home') && method === 'GET') {
        return route.fulfill({ status: 204, body: '' });
      }
      return route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
    });

    // Stub map assets (tiles, glyphs, sprites) — vite preview proxies these to
    // localhost:8080 (not running), which returns 502s that MapLibre logs as errors.
    // Return minimal valid 200 responses so MapLibre loads silently:
    // - sprite JSON  → {} (empty sprite sheet; no icons rendered, no error)
    // - sprite PNG   → 1×1 transparent PNG (valid image; no icons rendered)
    // - glyph PBFs   → empty body 200 (MapLibre ignores unrecognised PBF data)
    // - vector tiles → empty body 200 (treated as empty tile)
    await page.route('**/tiles/**', route => {
      const url = route.request().url();
      if (url.endsWith('.json')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: '{}',
        });
      }
      if (url.endsWith('.png')) {
        return route.fulfill({
          status: 200,
          contentType: 'image/png',
          body: TRANSPARENT_1X1_PNG,
        });
      }
      if (url.endsWith('.pbf')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/x-protobuf',
          body: Buffer.alloc(0),
        });
      }
      // Vector tiles (/{z}/{x}/{y} with no extension)
      return route.fulfill({
        status: 200,
        contentType: 'application/x-protobuf',
        body: Buffer.alloc(0),
      });
    });

    await use(page);

    expect(consoleErrors, 'browser console errors').toEqual([]);
    expect(pageErrors, 'uncaught page exceptions').toEqual([]);
  },
});

export { expect };
