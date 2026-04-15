import maplibregl from 'maplibre-gl';
import { api } from './api.js';
import { locations, routePointFromLocation } from './locations.svelte.js';
import { shouldSuppressMapClick } from './paintGesture.js';
import { preferences } from './preferences.svelte.js';

export const route = $state({
  origin: null,      // { lng, lat, name }
  destination: null,  // { lng, lat, name }
  data: null,         // { geometry, distance, time }
  loading: false,
});

let currentMap = null;
let initialized = false;
let homeMarker = null;
let originMarker = null;
let destMarker = null;
let pendingRouteClick = null;

const SINGLE_CLICK_DELAY_MS = 250;

export function initRouting(map) {
  if (initialized && currentMap === map) return;
  currentMap = map;

  if (!map.getSource('route')) {
    map.addSource('route', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    });
  }

  if (!map.getLayer('route-line-casing')) {
    map.addLayer({
      id: 'route-line-casing',
      type: 'line',
      source: 'route',
      paint: {
        'line-color': '#ffffff',
        'line-width': 9,
        'line-opacity': 0.9,
      },
      layout: {
        'line-cap': 'round',
        'line-join': 'round',
      },
    });
  }

  if (!map.getLayer('route-line')) {
    map.addLayer({
      id: 'route-line',
      type: 'line',
      source: 'route',
      paint: {
        'line-color': '#155e75',
        'line-width': 5,
        'line-opacity': 0.95,
      },
      layout: {
        'line-cap': 'round',
        'line-join': 'round',
      },
    });
  }

  map.off('click', handleMapClick);
  map.off('dblclick', handleMapDoubleClick);
  map.on('click', handleMapClick);
  map.on('dblclick', handleMapDoubleClick);

  initialized = true;
  syncHomeMarker();
}

export async function computeRoute({ fitBounds = true } = {}) {
  if (!route.origin || !route.destination) return;

  if (fitBounds && currentMap) {
    const bounds = new maplibregl.LngLatBounds();
    bounds.extend([route.origin.lng, route.origin.lat]);
    bounds.extend([route.destination.lng, route.destination.lat]);
    currentMap.fitBounds(bounds, {
      padding: { top: 140, bottom: 140, left: 80, right: 80 },
      maxZoom: 15,
      duration: 400,
    });
  }

  route.loading = true;
  try {
    const data = await api.route(
      [route.origin.lng, route.origin.lat],
      [route.destination.lng, route.destination.lat],
      preferences.ratingWeight
    );
    route.data = data;

    if (currentMap) {
      currentMap.getSource('route').setData({
        type: 'Feature',
        properties: {},
        geometry: data.geometry,
      });
    }
  } catch (e) {
    console.error('Routing failed:', e);
    route.data = null;
  } finally {
    route.loading = false;
  }
}

export function clearRoute() {
  route.data = null;
  route.destination = null;
  route.origin = locations.startAtHome
    ? routePointFromLocation(locations.home)
    : null;
  clearRouteGeometry();
  syncRouteMarkers();
}

export function centerOnHome(map) {
  const m = map || currentMap;
  if (!m || !locations.home) return;
  m.jumpTo({
    center: [locations.home.lng, locations.home.lat],
    zoom: 14,
  });
}

export function applyStartAtHome() {
  if (!locations.startAtHome || !locations.home) return;
  if (route.data || route.destination) return;
  route.origin = routePointFromLocation(locations.home);
}

export function syncHomeMarker() {
  if (!currentMap) return;

  if (!locations.home) {
    homeMarker?.remove();
    homeMarker = null;
    return;
  }

  if (!homeMarker) {
    homeMarker = new maplibregl.Marker({
      element: createHomeMarkerElement(),
      anchor: 'bottom',
    });
  }

  homeMarker
    .setLngLat([locations.home.lng, locations.home.lat])
    .addTo(currentMap);
}

export function syncRouteMarkers() {
  if (!currentMap) return;

  // Origin marker — skip if origin is the home location (home marker covers it)
  if (route.origin && route.origin.savedLocationName !== 'home') {
    if (!originMarker) {
      originMarker = new maplibregl.Marker({
        element: createRouteMarkerElement('#f1c40f', 'Origin'),
        anchor: 'bottom',
        draggable: true,
      });
      originMarker.on('dragend', () => {
        const { lng, lat } = originMarker.getLngLat();
        route.origin = { lng, lat, name: `${lat.toFixed(5)}, ${lng.toFixed(5)}` };
        if (route.destination) computeRoute({ fitBounds: false });
      });
    }
    originMarker.setLngLat([route.origin.lng, route.origin.lat]).addTo(currentMap);
  } else {
    originMarker?.remove();
    originMarker = null;
  }

  // Destination marker
  if (route.destination) {
    if (!destMarker) {
      destMarker = new maplibregl.Marker({
        element: createRouteMarkerElement('#2980b9', 'Destination'),
        anchor: 'bottom',
        draggable: true,
      });
      destMarker.on('dragend', () => {
        const { lng, lat } = destMarker.getLngLat();
        route.destination = { lng, lat, name: `${lat.toFixed(5)}, ${lng.toFixed(5)}` };
        computeRoute({ fitBounds: false });
      });
    }
    destMarker.setLngLat([route.destination.lng, route.destination.lat]).addTo(currentMap);
  } else {
    destMarker?.remove();
    destMarker = null;
  }
}

function createRouteMarkerElement(color, label) {
  const el = document.createElement('div');
  el.setAttribute('aria-label', label);
  el.title = label;
  el.style.width = '30px';
  el.style.height = '38px';
  el.style.filter = 'drop-shadow(0 2px 4px rgba(0,0,0,0.28))';
  el.innerHTML = `
    <svg viewBox="0 0 30 38" width="30" height="38" role="img" aria-hidden="true">
      <path fill="${color}" stroke="rgba(0,0,0,0.25)" stroke-width="1" d="M15 37c0 0 11-13 11-22C26 8.925 21.075 4 15 4S4 8.925 4 15c0 9 11 22 11 22Z"/>
      <circle cx="15" cy="15" r="5" fill="white" fill-opacity="0.9"/>
    </svg>
  `;
  return el;
}

function clearRouteGeometry() {
  if (currentMap && initialized && currentMap.getSource('route')) {
    currentMap.getSource('route').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}

function createHomeMarkerElement() {
  const el = document.createElement('div');
  el.setAttribute('aria-label', 'Home');
  el.title = 'Home';
  el.style.width = '30px';
  el.style.height = '38px';
  el.style.color = '#111827';
  el.style.filter = 'drop-shadow(0 2px 4px rgba(0,0,0,0.28))';
  el.innerHTML = `
    <svg viewBox="0 0 30 38" width="30" height="38" role="img" aria-hidden="true">
      <path fill="#ffffff" stroke="currentColor" stroke-width="2" d="M15 37c0 0 11-13 11-22C26 8.925 21.075 4 15 4S4 8.925 4 15c0 9 11 22 11 22Z"/>
      <path fill="#facc15" d="M9 15.2 15 10l6 5.2v8.3a1 1 0 0 1-1 1h-3.3v-5.2h-3.4v5.2H10a1 1 0 0 1-1-1v-8.3Z"/>
      <path fill="#111827" d="m7.7 15.1 7.3-6.3 7.3 6.3-1.2 1.4-6.1-5.2-6.1 5.2-1.2-1.4Z"/>
    </svg>
  `;
  return el;
}

function handleMapClick(event) {
  if (shouldSuppressMapClick()) return;
  if (event.originalEvent?.detail > 1) return;

  scheduleRouteClick({
    lng: event.lngLat.lng,
    lat: event.lngLat.lat,
  });
}

function handleMapDoubleClick() {
  cancelPendingRouteClick();
}

function scheduleRouteClick(lngLat) {
  cancelPendingRouteClick();
  pendingRouteClick = window.setTimeout(() => {
    pendingRouteClick = null;
    setRoutePoint(lngLat);
  }, SINGLE_CLICK_DELAY_MS);
}

function cancelPendingRouteClick() {
  if (!pendingRouteClick) return;
  window.clearTimeout(pendingRouteClick);
  pendingRouteClick = null;
}

function setRoutePoint(lngLat) {
  if (route.data) return;

  const point = {
    lng: lngLat.lng,
    lat: lngLat.lat,
    name: `Pinned point (${lngLat.lat.toFixed(5)}, ${lngLat.lng.toFixed(5)})`,
  };

  if (locations.startAtHome && locations.home && !route.origin) {
    route.origin = routePointFromLocation(locations.home);
  }

  if (!route.origin) {
    route.origin = point;
    return;
  }

  if (!route.destination) {
    route.destination = point;
    computeRoute();
  }
}
