import { api } from './api.js';

const COLORS = {
  '-7': '#991b1b', // dark red
  '-3': '#dc2626', // intense red
  '-1': '#fca5a5', // light red
  '1':  '#86efac', // light green
  '3':  '#22c55e', // intense green
  '7':  '#059669', // emerald green
};

let initialized = false;
let currentMap = null;

export function initOverlay(map) {
  if (initialized) return; // prevent double-init
  currentMap = map;

  map.addSource('ratings', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  });

  map.addLayer({
    id: 'ratings-fill',
    type: 'fill',
    source: 'ratings',
    paint: {
      'fill-color': [
        'match', ['get', 'value'],
        -7, COLORS['-7'],
        -3, COLORS['-3'],
        -1, COLORS['-1'],
        1,  COLORS['1'],
        3,  COLORS['3'],
        7,  COLORS['7'],
        '#6b7280', // fallback gray
      ],
      'fill-opacity': 0.4,
    },
  });

  map.addLayer({
    id: 'ratings-outline',
    type: 'line',
    source: 'ratings',
    paint: {
      'line-color': [
        'match', ['get', 'value'],
        -7, COLORS['-7'],
        -3, COLORS['-3'],
        -1, COLORS['-1'],
        1,  COLORS['1'],
        3,  COLORS['3'],
        7,  COLORS['7'],
        '#6b7280',
      ],
      'line-width': 1,
      'line-opacity': 0.7,
    },
  });

  initialized = true;

  // Refresh on viewport change
  map.on('moveend', () => refreshOverlay(map));
  refreshOverlay(map);
}

export async function refreshOverlay(map) {
  if (!initialized || !map) return;
  const bounds = map.getBounds();
  const bbox = `${bounds.getWest()},${bounds.getSouth()},${bounds.getEast()},${bounds.getNorth()}`;
  try {
    const data = await api.getOverlay(bbox);
    map.getSource('ratings').setData(data);
  } catch (e) {
    console.error('Failed to load overlay:', e);
  }
}
