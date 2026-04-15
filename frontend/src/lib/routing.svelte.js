import maplibregl from 'maplibre-gl';
import { api } from './api.js';
import { locations, routePointFromLocation } from './locations.svelte.js';
import { shouldSuppressMapClick } from './paintGesture.js';

export const route = $state({
  origin: null,      // { lng, lat, name }
  destination: null,  // { lng, lat, name }
  data: null,         // { geometry, distance, time }
  loading: false,
});

let currentMap = null;
let initialized = false;
let homeMarker = null;

export function initRouting(map) {
  if (initialized && currentMap === map) return;
  currentMap = map;

  if (!map.getSource('route')) {
    map.addSource('route', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    });
  }

  if (!map.getLayer('route-line')) {
    map.addLayer({
      id: 'route-line',
      type: 'line',
      source: 'route',
      paint: {
        'line-color': '#2563eb',
        'line-width': 5,
        'line-opacity': 0.8,
      },
    });
  }

  map.off('click', handleMapClick);
  map.on('click', handleMapClick);

  initialized = true;
  syncHomeMarker();
}

export async function computeRoute() {
  if (!route.origin || !route.destination) return;

  route.loading = true;
  try {
    const data = await api.route(
      [route.origin.lng, route.origin.lat],
      [route.destination.lng, route.destination.lat]
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
  if (route.data) return;

  const point = {
    lng: event.lngLat.lng,
    lat: event.lngLat.lat,
    name: `Pinned point (${event.lngLat.lat.toFixed(5)}, ${event.lngLat.lng.toFixed(5)})`,
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
