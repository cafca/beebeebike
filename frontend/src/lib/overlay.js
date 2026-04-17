import { api } from './api.js';

const COLORS = {
  '-7': '#c0392b', // dark red
  '-3': '#e74c3c', // medium red
  '-1': '#f1948a', // pale red
  '1':  '#76d7c4', // pale teal
  '3':  '#1abc9c', // teal
  '7':  '#0e6655', // dark teal
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
  if (!initialized || !map) return null;
  const bounds = map.getBounds();
  const bbox = `${bounds.getWest()},${bounds.getSouth()},${bounds.getEast()},${bounds.getNorth()}`;
  try {
    const data = await api.getOverlay(bbox);
    map.getSource('ratings').setData(data);
    return data;
  } catch (e) {
    console.error('Failed to load overlay:', e);
    return null;
  }
}
