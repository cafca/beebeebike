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
  // Node v25 exposes a built-in localStorage that lacks .clear(); use a
  // key-iteration fallback that works in both Node v25 and happy-dom.
  const ls = window.localStorage;
  if (typeof ls?.clear === 'function') {
    ls.clear();
  } else if (ls) {
    const keys = [];
    for (let i = 0; i < (ls.length ?? 0); i++) keys.push(ls.key(i));
    keys.forEach(k => ls.removeItem(k));
  }
});
