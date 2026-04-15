import maplibregl from 'maplibre-gl';

const TILES_URL = 'http://localhost:8080';
const STYLE_URL = `${TILES_URL}/assets/styles/colorful/style.json`;

export function createMap(container) {
  const map = new maplibregl.Map({
    container,
    style: STYLE_URL,
    center: [13.405, 52.52],
    zoom: 12,
    maxBounds: [[12.9, 52.2], [13.9, 52.8]],
  });

  map.addControl(new maplibregl.NavigationControl(), 'top-right');
  initTrackpadGestures(map);

  return map;
}

function initTrackpadGestures(map) {
  map.scrollZoom.disable();

  const canvas = map.getCanvas();
  canvas.addEventListener('wheel', (event) => {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation?.();

    if (event.metaKey) return;

    if (event.ctrlKey) {
      const point = [event.offsetX, event.offsetY];
      const zoomDelta = -event.deltaY * 0.01;
      map.zoomTo(map.getZoom() + zoomDelta, {
        around: map.unproject(point),
        duration: 0,
      });
      return;
    }

    map.panBy([event.deltaX, event.deltaY], {
      animate: false,
      duration: 0,
    });
  }, { passive: false, capture: true });
}
