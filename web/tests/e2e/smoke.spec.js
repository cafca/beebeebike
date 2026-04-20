import { test, expect } from './fixtures.js';

test('app boots with a map canvas visible and no console errors', async ({ page }) => {
  await page.goto('/');

  const canvas = page.locator('canvas.maplibregl-canvas');
  await expect(canvas).toBeAttached({ timeout: 15_000 });
  const box = await canvas.boundingBox();
  expect(box?.width).toBeGreaterThan(0);
  expect(box?.height).toBeGreaterThan(0);

  await page.waitForTimeout(1_000);
});
