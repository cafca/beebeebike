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
