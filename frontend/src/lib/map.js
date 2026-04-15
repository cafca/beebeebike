import maplibregl from 'maplibre-gl';

const STYLE_URL = '/tiles/assets/styles/colorful/style.json';
const LOCAL_TILE_PATH = '/tiles/tiles/osm/{z}/{x}/{y}';
const LOCAL_GLYPHS_PATH = '/tiles/assets/glyphs/{fontstack}/{range}.pbf';
const LOCAL_SPRITE_PATH = '/tiles/assets/sprites/basics/sprites';

const COLORS = {
  background: '#f8f4ec',
  water: '#b8dcef',
  park: '#cfe7bc',
  forest: '#9fc686',
  grass: '#dceccc',
  building: '#eee5dc',
  buildingShadow: '#d8d0c7',
  localRoad: '#fffdf8',
  localRoadCasing: '#d9d6ce',
  arterial: '#fff2de',
  arterialCasing: '#d0a589',
  bikeHalo: '#edf4ef',
  cycleway: '#4f9f91',
  designated: '#6ca77f',
  corridor: '#5d9b95',
  path: '#7fa26c',
  caution: '#b8795d',
};

export async function createMap(container) {
  const style = await loadBicycleStyle();
  const map = new maplibregl.Map({
    container,
    style,
    center: [13.405, 52.52],
    zoom: 12,
    maxBounds: [[12.9, 52.2], [13.9, 52.8]],
  });


  return map;
}

async function loadBicycleStyle() {
  const response = await fetch(STYLE_URL);
  if (!response.ok) {
    throw new Error(`Failed to load map style: ${response.status}`);
  }

  return optimizeStyleForBicycleRouting(await response.json());
}

export function optimizeStyleForBicycleRouting(style) {
  style.name = 'beebeebike-bicycle-planning';
  style.glyphs = absoluteUrl(LOCAL_GLYPHS_PATH);
  style.sprite = [{ id: 'basics', url: absoluteUrl(LOCAL_SPRITE_PATH) }];

  for (const source of Object.values(style.sources ?? {})) {
    if (source.type === 'vector') {
      source.tiles = [absoluteUrl(LOCAL_TILE_PATH)];
      source.scheme = 'xyz';
    }
  }

  style.layers = style.layers.map(tuneLayerForCycling);
  insertBicyclePlanningLayers(style);

  return style;
}

function absoluteUrl(path) {
  const origin = globalThis.location?.origin ?? 'http://127.0.0.1:5175';
  return `${origin.replace(/\/$/, '')}${path}`;
}

function tuneLayerForCycling(layer) {
  const next = {
    ...layer,
    paint: { ...(layer.paint ?? {}) },
    ...(layer.layout ? { layout: { ...layer.layout } } : {}),
  };

  if (next.id === 'background') {
    next.paint['background-color'] = COLORS.background;
  }

  if (next.id.startsWith('water-')) {
    if (next.type === 'fill') next.paint['fill-color'] = COLORS.water;
    if (next.type === 'line') next.paint['line-color'] = COLORS.water;
  }

  const landColors = {
    'land-park': COLORS.park,
    'land-garden': COLORS.park,
    'land-leisure': COLORS.park,
    'land-forest': COLORS.forest,
    'land-grass': COLORS.grass,
    'land-vegetation': '#d5e4bf',
    'land-commercial': '#f0e3e5',
    'land-industrial': '#efe6ce',
    'land-residential': '#ebe7df',
  };
  if (landColors[next.id]) {
    next.paint['fill-color'] = landColors[next.id];
  }

  if (next.id === 'building:outline') {
    next.paint['fill-color'] = COLORS.buildingShadow;
  }
  if (next.id === 'building') {
    next.paint['fill-color'] = COLORS.building;
    next.paint['fill-translate'] = [-1, -1];
  }

  if (next.type === 'line' && isArterialLayer(next.id)) {
    next.paint['line-color'] = isCasingLayer(next.id) ? COLORS.arterialCasing : COLORS.arterial;
    next.paint['line-opacity'] = isCasingLayer(next.id) ? 0.7 : 0.92;
  }

  if (next.type === 'line' && isLocalStreetLayer(next.id)) {
    next.paint['line-color'] = isCasingLayer(next.id) ? COLORS.localRoadCasing : COLORS.localRoad;
  }

  if (next.type === 'line' && next.id.includes('way-steps')) {
    next.paint['line-color'] = COLORS.caution;
    next.paint['line-opacity'] = 0.7;
    next.paint['line-dasharray'] = [0.6, 0.6];
  }

  if (next.id === 'site-bicycleparking') {
    next.paint['fill-color'] = '#c9f4e8';
  }

  if (next.id === 'marking-oneway' || next.id === 'marking-oneway-reverse') {
    next.paint['icon-opacity'] = { stops: [[15, 0], [16, 0.55], [20, 0.55]] };
  }

  if (next.type === 'symbol' && next.paint?.['text-halo-color']) {
    next.paint['text-halo-color'] = 'rgba(248,244,236,0.9)';
  }

  return next;
}

function insertBicyclePlanningLayers(style) {
  const beforeId = style.layers.find((layer) => layer.type === 'symbol' && layer.id.startsWith('label-'))?.id;
  const insertAt = beforeId
    ? style.layers.findIndex((layer) => layer.id === beforeId)
    : style.layers.length;

  style.layers.splice(insertAt, 0, ...bicyclePlanningLayers());
}

function bicyclePlanningLayers() {
  return [
    {
      id: 'bike-cycleway-casing',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: ['in', 'kind', 'cycleway'],
      minzoom: 10,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.bikeHalo,
        'line-width': { stops: [[10, 1], [13, 2.5], [16, 5], [19, 9]] },
        'line-opacity': { stops: [[10, 0.25], [13, 0.42], [16, 0.52]] },
      },
    },
    {
      id: 'bike-cycleway',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: ['in', 'kind', 'cycleway'],
      minzoom: 10,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.cycleway,
        'line-width': { stops: [[10, 0.5], [13, 1.2], [16, 2.2], [19, 4.5]] },
        'line-opacity': 0.68,
      },
    },
    {
      id: 'bike-designated-casing',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: [
        'all',
        ['==', 'bicycle', 'designated'],
        ['in', 'kind', 'track', 'path', 'pedestrian', 'service'],
      ],
      minzoom: 12,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.bikeHalo,
        'line-width': { stops: [[12, 0.8], [15, 2.2], [18, 5], [20, 9]] },
        'line-opacity': 0.42,
      },
    },
    {
      id: 'bike-designated',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: [
        'all',
        ['==', 'bicycle', 'designated'],
        ['in', 'kind', 'track', 'path', 'pedestrian', 'service'],
      ],
      minzoom: 12,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.designated,
        'line-width': { stops: [[12, 0.4], [15, 1], [18, 2], [20, 4]] },
        'line-dasharray': [1, 1.4],
        'line-opacity': 0.58,
      },
    },
    {
      id: 'bike-street-corridor-casing',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: [
        'all',
        ['in', 'kind', 'living_street', 'residential', 'unclassified', 'tertiary', 'secondary', 'primary'],
        ['in', 'bicycle', 'designated', 'yes', 'permissive', 'optional_sidepath', 'use_sidepath'],
      ],
      minzoom: 12,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.bikeHalo,
        'line-width': { stops: [[12, 0.8], [15, 2.2], [18, 5], [20, 9]] },
        'line-opacity': { stops: [[12, 0.12], [14, 0.34]] },
      },
    },
    {
      id: 'bike-street-corridor',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: [
        'all',
        ['in', 'kind', 'living_street', 'residential', 'unclassified', 'tertiary', 'secondary', 'primary'],
        ['in', 'bicycle', 'designated', 'yes', 'permissive', 'optional_sidepath', 'use_sidepath'],
      ],
      minzoom: 12,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.corridor,
        'line-width': { stops: [[12, 0.35], [15, 0.9], [18, 1.8], [20, 3.6]] },
        'line-dasharray': [2.6, 1.6],
        'line-opacity': { stops: [[12, 0.22], [14, 0.5]] },
      },
    },
    {
      id: 'bike-path-options',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: [
        'all',
        ['in', 'kind', 'path', 'track', 'footway', 'pedestrian'],
        ['in', 'bicycle', 'yes', 'permissive', 'destination'],
      ],
      minzoom: 14,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.path,
        'line-width': { stops: [[14, 0.3], [16, 0.7], [19, 1.5]] },
        'line-dasharray': [0.6, 1],
        'line-opacity': 0.34,
      },
    },
    {
      id: 'bike-arterial-caution',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: ['in', 'kind', 'motorway', 'trunk', 'primary'],
      minzoom: 12,
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.caution,
        'line-width': { stops: [[12, 0.3], [15, 0.7], [18, 1.6]] },
        'line-opacity': 0.18,
      },
    },
    {
      id: 'bike-steps-caution',
      type: 'line',
      source: 'versatiles-shortbread',
      'source-layer': 'streets',
      filter: ['in', 'kind', 'steps'],
      minzoom: 15,
      layout: { 'line-cap': 'butt', 'line-join': 'round' },
      paint: {
        'line-color': COLORS.caution,
        'line-width': { stops: [[15, 0.9], [18, 1.8], [20, 3.6]] },
        'line-dasharray': [0.35, 0.55],
        'line-opacity': 0.55,
      },
    },
  ];
}

function isArterialLayer(id) {
  return /(^|-)street-(motorway|trunk|primary|secondary)(-|:|$)/.test(id);
}

function isLocalStreetLayer(id) {
  return /(^|-)street-(residential|livingstreet|unclassified|service|pedestrian|track)(:|$)/.test(id);
}

function isCasingLayer(id) {
  return id.includes(':outline') || id.includes(':bridge');
}
