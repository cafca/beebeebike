import maplibregl from 'maplibre-gl';

const TILES_URL = 'http://localhost:8080';

export function createMap(container) {
  const map = new maplibregl.Map({
    container,
    style: `${TILES_URL}/tiles/osm/style.json`,
    center: [13.405, 52.52],
    zoom: 12,
    maxBounds: [[12.9, 52.2], [13.9, 52.8]],
  });

  map.addControl(new maplibregl.NavigationControl(), 'top-right');

  return map;
}
