import { describe, it, expect, vi, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';

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
