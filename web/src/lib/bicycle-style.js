// Pure style builder shared between the web app (runtime) and the mobile
// build script (offline). Wraps `@versatiles/style`'s `colorful` style with a
// bicycle-planning palette and an extra set of bike-priority layers.
//
// To regenerate the mobile asset after editing this file:
//   npm --prefix web run build:mobile-style

import { colorful } from '@versatiles/style';

export const COLORS = {
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

// `colorful` requires baseUrl to parse as a URL. We override tile/sprite/glyph
// URLs explicitly afterwards, so this hostname is never fetched.
const BASE_URL_PLACEHOLDER = 'http://placeholder.local';

/**
 * Build a MapLibre style for bicycle planning.
 *
 * @param {object} opts
 * @param {string} opts.tilesUrl — URL template for vector tiles ({z}/{x}/{y})
 * @param {string} opts.glyphsUrl — URL template for glyph PBFs ({fontstack}/{range})
 * @param {string} opts.spriteUrl — base URL for the sprite atlas
 * @param {boolean} [opts.mobile=false] — bump label sizes for mobile devices
 */
export function buildBicycleStyle({ tilesUrl, glyphsUrl, spriteUrl, mobile = false }) {
  const style = colorful({
    baseUrl: BASE_URL_PLACEHOLDER,
    colors: {
      land: COLORS.background,
      water: COLORS.water,
      park: COLORS.park,
      leisure: COLORS.park,
      wood: COLORS.forest,
      grass: COLORS.grass,
      building: COLORS.building,
      buildingbg: COLORS.buildingShadow,
      street: COLORS.localRoad,
      streetbg: COLORS.localRoadCasing,
      motorway: COLORS.arterial,
      motorwaybg: COLORS.arterialCasing,
      trunk: COLORS.arterial,
      trunkbg: COLORS.arterialCasing,
      labelHalo: 'rgba(248,244,236,0.9)',
    },
  });

  style.name = 'beebeebike-bicycle-planning';
  style.glyphs = glyphsUrl;
  style.sprite = [{ id: 'basics', url: spriteUrl }];
  for (const source of Object.values(style.sources ?? {})) {
    if (source.type === 'vector') {
      source.tiles = [tilesUrl];
      source.scheme = 'xyz';
    }
  }

  style.layers = style.layers.map((layer) => tuneLayerForCycling(layer, { mobile }));
  insertBicyclePlanningLayers(style);

  return style;
}

function tuneLayerForCycling(layer, { mobile }) {
  const next = {
    ...layer,
    paint: { ...(layer.paint ?? {}) },
    ...(layer.layout ? { layout: { ...layer.layout } } : {}),
  };

  if (next.id === 'building') {
    next.paint['fill-translate'] = [-1, -1];
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

  if (mobile && next.type === 'symbol' && next.layout?.['text-size'] != null) {
    next.layout = { ...next.layout, 'text-size': scaleTextSize(next.layout['text-size'], 1.15) };
  }

  return next;
}

function scaleTextSize(value, factor) {
  if (typeof value === 'number') return Math.round(value * factor * 10) / 10;
  if (value && Array.isArray(value.stops)) {
    return {
      ...value,
      stops: value.stops.map(([z, s]) => [z, Math.round(s * factor * 10) / 10]),
    };
  }
  return value;
}

function insertBicyclePlanningLayers(style) {
  const beforeId = style.layers.find(
    (layer) => layer.type === 'symbol' && layer.id.startsWith('label-'),
  )?.id;
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
