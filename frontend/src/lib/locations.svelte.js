import { api } from './api.js';

export const locations = $state({
  home: null,
  startAtHome: false,
  ready: false,
  saving: false,
  error: null,
});

export function routePointFromLocation(location) {
  if (!location) return null;

  return {
    lng: location.lng,
    lat: location.lat,
    name: location.label,
    savedLocationName: location.name,
  };
}

export async function loadHomeLocation() {
  locations.ready = false;
  locations.error = null;

  try {
    locations.home = await api.getHomeLocation();
    locations.startAtHome = Boolean(locations.home);
  } catch (e) {
    locations.home = null;
    locations.startAtHome = false;
    locations.error = e.message;
    throw e;
  } finally {
    locations.ready = true;
  }
}

export async function saveHomeLocation(point) {
  if (!point) return null;

  locations.saving = true;
  locations.error = null;

  try {
    locations.home = await api.saveHomeLocation({
      label: point.name,
      lng: point.lng,
      lat: point.lat,
    });
    locations.startAtHome = true;
    return locations.home;
  } catch (e) {
    locations.error = e.message;
    throw e;
  } finally {
    locations.saving = false;
  }
}

export async function resetHomeLocation() {
  locations.saving = true;
  locations.error = null;

  try {
    await api.deleteHomeLocation();
    locations.home = null;
    locations.startAtHome = false;
  } catch (e) {
    locations.error = e.message;
    throw e;
  } finally {
    locations.saving = false;
  }
}

export function setStartAtHome(enabled) {
  locations.startAtHome = Boolean(enabled && locations.home);
}
