import { test as base, expect } from '@playwright/test';

export const test = base.extend({
  page: async ({ page }, use) => {
    const consoleErrors = [];
    const pageErrors = [];

    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', err => pageErrors.push(err.message));

    // Stub backend API calls so the app boots cleanly without a running server.
    // - GET  /api/auth/me        → 401 (expected; app falls through to anonymous)
    // - POST /api/auth/anonymous → 200 with a minimal anonymous user object
    // - GET  /api/ratings?bbox=… → 200 empty FeatureCollection (else overlay logs console.error)
    // - GET  /api/locations/home → 404 (app catches and ignores the error)
    await page.route('**/api/**', route => {
      const url = route.request().url();
      const method = route.request().method();

      if (url.includes('/api/auth/me') && method === 'GET') {
        return route.fulfill({ status: 401, body: '{}' });
      }
      if (url.includes('/api/auth/anonymous') && method === 'POST') {
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
        return route.fulfill({ status: 404, body: '{"error":"not found"}' });
      }
      return route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
    });

    await use(page);

    expect(consoleErrors, 'browser console errors').toEqual([]);
    expect(pageErrors, 'uncaught page exceptions').toEqual([]);
  },
});

export { expect };
