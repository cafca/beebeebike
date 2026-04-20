import maplibregl from 'maplibre-gl';

import { buildBicycleStyle } from './bicycle-style.js';

const LOCAL_TILE_PATH = '/tiles/tiles/osm/{z}/{x}/{y}';
const LOCAL_GLYPHS_PATH = '/tiles/assets/glyphs/{fontstack}/{range}.pbf';
const LOCAL_SPRITE_PATH = '/tiles/assets/sprites/basics/sprites';

const DEFAULT_CENTER = [13.405, 52.52];
const DEFAULT_ZOOM = 12;

export async function createMap(container, { center, zoom } = {}) {
  const style = buildBicycleStyle({
    tilesUrl: absoluteUrl(LOCAL_TILE_PATH),
    glyphsUrl: absoluteUrl(LOCAL_GLYPHS_PATH),
    spriteUrl: absoluteUrl(LOCAL_SPRITE_PATH),
  });

  return new maplibregl.Map({
    container,
    style,
    center: center || DEFAULT_CENTER,
    zoom: zoom ?? DEFAULT_ZOOM,
    maxBounds: [[12.9, 52.2], [13.9, 52.8]],
  });
}

function absoluteUrl(path) {
  const origin = globalThis.location?.origin ?? 'http://127.0.0.1:5175';
  return `${origin.replace(/\/$/, '')}${path}`;
}

export { buildBicycleStyle };
