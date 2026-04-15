import buffer from '@turf/buffer';
import { lineString } from '@turf/helpers';
import { api } from './api.js';
import { refreshOverlay } from './overlay.js';

// Shared reactive state
export const brush = $state({
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

export function initBrush(map) {
  if (initialized) return;
  currentMap = map;

  // Preview layer
  map.addSource('brush-preview', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  });
  map.addLayer({
    id: 'brush-preview-fill',
    type: 'fill',
    source: 'brush-preview',
    paint: { 'fill-color': '#60a5fa', 'fill-opacity': 0.3 },
  });

  const canvas = map.getCanvas();
  canvas.addEventListener('mousedown', onMouseDown);
  canvas.addEventListener('mousemove', onMouseMove);
  canvas.addEventListener('mouseup', onMouseUp);
  document.addEventListener('keydown', onKeyDown);

  initialized = true;
}

export function destroyBrush() {
  if (currentMap) {
    const canvas = currentMap.getCanvas();
    canvas.removeEventListener('mousedown', onMouseDown);
    canvas.removeEventListener('mousemove', onMouseMove);
    canvas.removeEventListener('mouseup', onMouseUp);
  }
  document.removeEventListener('keydown', onKeyDown);
  initialized = false;
  currentMap = null;
}

function onMouseDown(e) {
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
  if (currentMap && initialized) {
    currentMap.getSource('brush-preview').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}

async function submitPaint(geometry, value) {
  try {
    const result = await api.paint(geometry, value);
    undoStack.push({ geometry, value, result });
    redoStack.length = 0;
    brush.canUndo = undoStack.length > 0;
    brush.canRedo = false;
    refreshOverlay(currentMap);
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
    refreshOverlay(currentMap);
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
    refreshOverlay(currentMap);
  } catch (e) {
    console.error('Redo failed:', e);
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
