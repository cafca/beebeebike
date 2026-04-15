import { api } from './api.js';
import { shouldSuppressMapClick } from './paintGesture.js';

export const route = $state({
  origin: null,      // { lng, lat, name }
  destination: null,  // { lng, lat, name }
  data: null,         // { geometry, distance, time }
  loading: false,
});

let currentMap = null;
let initialized = false;

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
  route.origin = null;
  route.destination = null;
  if (currentMap && initialized) {
    currentMap.getSource('route').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}

function handleMapClick(event) {
  if (shouldSuppressMapClick()) return;
  if (route.data) return;

  const point = {
    lng: event.lngLat.lng,
    lat: event.lngLat.lat,
    name: `Pinned point (${event.lngLat.lat.toFixed(5)}, ${event.lngLat.lng.toFixed(5)})`,
  };

  if (!route.origin) {
    route.origin = point;
    return;
  }

  if (!route.destination) {
    route.destination = point;
    computeRoute();
  }
}
