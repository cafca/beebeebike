import '@testing-library/jest-dom/vitest';
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest';
import { server } from './src/mocks/server.js';

// Node v25 ships its own global `localStorage` (a bare object without setItem/
// getItem/clear). Vitest's populateGlobal skips keys already on the global, so
// happy-dom's Storage never replaces it. Install a proper in-memory shim so that
// modules that call localStorage.getItem() at import time (e.g. preferences.svelte.js)
// find a working Storage.
if (typeof window.localStorage?.getItem !== 'function') {
  const store = {};
  Object.defineProperty(window, 'localStorage', {
    configurable: true,
    writable: true,
    value: {
      getItem: (k) => Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null,
      setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; },
      clear: () => { Object.keys(store).forEach(k => delete store[k]); },
      key: (i) => Object.keys(store)[i] ?? null,
      get length() { return Object.keys(store).length; },
    },
  });
}

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
