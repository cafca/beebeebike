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
