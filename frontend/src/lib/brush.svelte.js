import buffer from '@turf/buffer';
import { lineString } from '@turf/helpers';
import { api } from './api.js';
import { refreshOverlay } from './overlay.js';
import { computeRoute, route } from './routing.svelte.js';

// Shared reactive state
export const brush = $state({
  active: false,
  value: 1,
  size: 30,
  canUndo: false,
  canRedo: false,
});

const undoStack = [];
const redoStack = [];
let painting = false;
let points = [];
let currentMap = null;
let initialized = false;
let currentCanvas = null;

export function initBrush(map) {
  if (initialized && currentMap === map) {
    syncInteractionMode();
    return;
  }

  if (initialized) {
    destroyBrush();
  }

  currentMap = map;

  // Preview layer
  if (!map.getSource('brush-preview')) {
    map.addSource('brush-preview', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    });
  }

  if (!map.getLayer('brush-preview-fill')) {
    map.addLayer({
      id: 'brush-preview-fill',
      type: 'fill',
      source: 'brush-preview',
      paint: { 'fill-color': '#60a5fa', 'fill-opacity': 0.3 },
    });
  }

  currentCanvas = map.getCanvas();
  currentCanvas.removeEventListener('mousedown', onMouseDown);
  currentCanvas.removeEventListener('mousemove', onMouseMove);
  currentCanvas.removeEventListener('mouseup', onMouseUp);
  currentCanvas.addEventListener('mousedown', onMouseDown);
  currentCanvas.addEventListener('mousemove', onMouseMove);
  currentCanvas.addEventListener('mouseup', onMouseUp);
  document.addEventListener('keydown', onKeyDown);

  initialized = true;
  syncInteractionMode();
}

export function destroyBrush() {
  if (currentCanvas) {
    currentCanvas.style.cursor = '';
    currentCanvas.removeEventListener('mousedown', onMouseDown);
    currentCanvas.removeEventListener('mousemove', onMouseMove);
    currentCanvas.removeEventListener('mouseup', onMouseUp);
  }
  document.removeEventListener('keydown', onKeyDown);
  painting = false;
  points = [];
  initialized = false;
  currentCanvas = null;
  currentMap = null;
}

export function setBrushActive(active) {
  brush.active = active;
  if (!active) {
    painting = false;
    points = [];
    clearPreview();
    if (currentMap && !currentMap.dragPan.isEnabled()) {
      currentMap.dragPan.enable();
    }
  }
  syncInteractionMode();
}

function onMouseDown(e) {
  if (!brush.active) return;
  if (e.button !== 0) return;
  painting = true;
  points = [currentMap.unproject([e.offsetX, e.offsetY])];
  currentMap.dragPan.disable();
}

function onMouseMove(e) {
  if (!painting) return;
  points.push(currentMap.unproject([e.offsetX, e.offsetY]));
  updatePreview();
}

function onMouseUp() {
  if (!painting) return;
  painting = false;
  currentMap.dragPan.enable();

  if (points.length < 2) {
    clearPreview();
    return;
  }

  const polygon = buildPolygon();
  if (!polygon) {
    clearPreview();
    return;
  }

  clearPreview();
  submitPaint(polygon, brush.value);
}

function buildPolygon() {
  const coords = points.map(p => [p.lng, p.lat]);
  if (coords.length < 2) return null;

  const line = lineString(coords);
  const zoom = currentMap.getZoom();
  // Convert brush pixel size to km based on zoom and latitude
  const metersPerPixel = 40075016.686 * Math.cos(52.52 * Math.PI / 180) / Math.pow(2, zoom + 8);
  const radiusKm = (brush.size * metersPerPixel) / 1000;

  const buffered = buffer(line, Math.max(radiusKm, 0.005), { units: 'kilometers' });
  return buffered?.geometry || null;
}

function updatePreview() {
  const polygon = buildPolygon();
  if (!polygon) return;
  currentMap.getSource('brush-preview').setData({
    type: 'FeatureCollection',
    features: [{ type: 'Feature', properties: {}, geometry: polygon }],
  });
}

function clearPreview() {
  if (currentMap && initialized && currentMap.getSource('brush-preview')) {
    currentMap.getSource('brush-preview').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}

function syncInteractionMode() {
  if (!currentMap) return;
  const canvas = currentMap.getCanvas();
  canvas.style.cursor = brush.active ? 'crosshair' : '';
  if (brush.active && currentMap.dragPan.isEnabled()) {
    currentMap.dragPan.disable();
  } else if (!brush.active && !currentMap.dragPan.isEnabled()) {
    currentMap.dragPan.enable();
  }
}

async function submitPaint(geometry, value) {
  try {
    const result = await api.paint(geometry, value);
    undoStack.push({ geometry, value, result });
    redoStack.length = 0;
    brush.canUndo = undoStack.length > 0;
    brush.canRedo = false;
    await refreshOverlay(currentMap);
    await refreshRouteIfReady();
  } catch (e) {
    console.error('Paint failed:', e);
  }
}

export async function undo() {
  if (undoStack.length === 0) return;
  const entry = undoStack.pop();
  redoStack.push(entry);
  brush.canUndo = undoStack.length > 0;
  brush.canRedo = true;

  try {
    await api.paint(entry.geometry, 0); // erase
    await refreshOverlay(currentMap);
    await refreshRouteIfReady();
  } catch (e) {
    console.error('Undo failed:', e);
  }
}

export async function redo() {
  if (redoStack.length === 0) return;
  const entry = redoStack.pop();
  undoStack.push(entry);
  brush.canUndo = true;
  brush.canRedo = redoStack.length > 0;

  try {
    await api.paint(entry.geometry, entry.value);
    await refreshOverlay(currentMap);
    await refreshRouteIfReady();
  } catch (e) {
    console.error('Redo failed:', e);
  }
}

async function refreshRouteIfReady() {
  if (route.origin && route.destination) {
    await computeRoute();
  }
}

function onKeyDown(e) {
  if (e.key === 'z' && (e.metaKey || e.ctrlKey) && e.shiftKey) {
    e.preventDefault();
    redo();
  } else if (e.key === 'z' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault();
    undo();
  }
}
