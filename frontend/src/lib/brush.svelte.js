import buffer from '@turf/buffer';
import { lineString } from '@turf/helpers';
import { api } from './api.js';
import { refreshOverlay } from './overlay.js';
import { suppressNextMapClick } from './paintGesture.js';
import { computeRoute, route } from './routing.svelte.js';

export const ratingTools = [
  { value: -7, color: '#991b1b' },
  { value: -3, color: '#dc2626' },
  { value: -1, color: '#fca5a5' },
  { value: 0,  color: '#6b7280' },
  { value: 1,  color: '#86efac' },
  { value: 3,  color: '#22c55e' },
  { value: 7,  color: '#059669' },
];

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
let currentCanvas = null;
let dragPanWasEnabled = false;
let modifierDown = false;
let lastCursorLngLat = null;
const listenerOptions = { capture: true };
const emptyFeatureCollection = { type: 'FeatureCollection', features: [] };

export function initBrush(map) {
  if (initialized && currentMap === map) {
    syncCursor();
    syncPreviewPaint();
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

  if (!map.getSource('brush-cursor')) {
    map.addSource('brush-cursor', {
      type: 'geojson',
      data: emptyFeatureCollection,
    });
  }

  if (!map.getLayer('brush-cursor-halo')) {
    map.addLayer({
      id: 'brush-cursor-halo',
      type: 'circle',
      source: 'brush-cursor',
      paint: {
        'circle-radius': brush.size,
        'circle-color': 'rgba(255,255,255,0)',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 4,
        'circle-stroke-opacity': 0.9,
      },
    });
  }

  if (!map.getLayer('brush-cursor-outline')) {
    map.addLayer({
      id: 'brush-cursor-outline',
      type: 'circle',
      source: 'brush-cursor',
      paint: {
        'circle-radius': brush.size,
        'circle-color': 'rgba(255,255,255,0)',
        'circle-stroke-color': currentTool().color,
        'circle-stroke-width': 2,
        'circle-stroke-opacity': 0.95,
      },
    });
  }

  currentCanvas = map.getCanvas();
  currentCanvas.removeEventListener('mousedown', onMouseDown, listenerOptions);
  currentCanvas.removeEventListener('mousemove', onMouseMove, listenerOptions);
  currentCanvas.removeEventListener('mouseleave', onMouseLeave, listenerOptions);
  currentCanvas.addEventListener('mousedown', onMouseDown, listenerOptions);
  currentCanvas.addEventListener('mousemove', onMouseMove, listenerOptions);
  currentCanvas.addEventListener('mouseleave', onMouseLeave, listenerOptions);
  document.removeEventListener('mouseup', onMouseUp, listenerOptions);
  document.addEventListener('mouseup', onMouseUp, listenerOptions);
  document.addEventListener('keydown', onKeyDown);
  document.addEventListener('keyup', onKeyUp);

  initialized = true;
  syncCursor();
  syncPreviewPaint();
  syncBrushCursorPaint();
}

export function destroyBrush() {
  if (currentCanvas) {
    currentCanvas.style.cursor = '';
    currentCanvas.removeEventListener('mousedown', onMouseDown, listenerOptions);
    currentCanvas.removeEventListener('mousemove', onMouseMove, listenerOptions);
    currentCanvas.removeEventListener('mouseleave', onMouseLeave, listenerOptions);
  }
  document.removeEventListener('mouseup', onMouseUp, listenerOptions);
  document.removeEventListener('keydown', onKeyDown);
  document.removeEventListener('keyup', onKeyUp);
  painting = false;
  points = [];
  modifierDown = false;
  lastCursorLngLat = null;
  clearBrushCursor();
  restoreDragPan();
  initialized = false;
  currentCanvas = null;
  currentMap = null;
}

function onMouseDown(e) {
  if (!isPaintModifier(e)) return;
  if (e.button !== 0) return;
  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();

  painting = true;
  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);
  points = [lastCursorLngLat];
  dragPanWasEnabled = currentMap.dragPan.isEnabled();
  if (dragPanWasEnabled) currentMap.dragPan.disable();
  syncCursor();
  updateBrushCursor(lastCursorLngLat);
}

function onMouseMove(e) {
  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);

  if (!painting) {
    const paintModifier = isPaintModifier(e);
    modifierDown = paintModifier;
    syncCursor();

    if (paintModifier) {
      updateBrushCursor(lastCursorLngLat);
    } else {
      clearBrushCursor();
    }
    return;
  }

  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();
  points.push(lastCursorLngLat);
  updateBrushCursor(lastCursorLngLat);
  updatePreview();
}

function onMouseLeave() {
  if (!painting) {
    lastCursorLngLat = null;
    clearBrushCursor();
  }
}

function onMouseUp(e) {
  if (!painting) return;
  e?.preventDefault();
  e?.stopPropagation();
  e?.stopImmediatePropagation?.();
  painting = false;
  suppressNextMapClick();
  restoreDragPan();
  syncCursor();
  if (modifierDown && lastCursorLngLat) {
    updateBrushCursor(lastCursorLngLat);
  } else {
    clearBrushCursor();
  }

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
  const latitude = points.reduce((sum, point) => sum + point.lat, 0) / points.length;
  const metersPerPixel = 40075016.686 * Math.cos(latitude * Math.PI / 180) / Math.pow(2, zoom + 9);
  const radiusKm = (brush.size * metersPerPixel) / 1000;

  const buffered = buffer(line, Math.max(radiusKm, 0.005), { units: 'kilometers' });
  return buffered?.geometry || null;
}

function updatePreview() {
  const polygon = buildPolygon();
  if (!polygon) return;
  syncPreviewPaint();
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

function updateBrushCursor(lngLat) {
  if (!currentMap || !initialized || !currentMap.getSource('brush-cursor')) return;
  syncBrushCursorPaint();
  currentMap.getSource('brush-cursor').setData({
    type: 'FeatureCollection',
    features: [{
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'Point',
        coordinates: [lngLat.lng, lngLat.lat],
      },
    }],
  });
}

function clearBrushCursor() {
  if (currentMap && initialized && currentMap.getSource('brush-cursor')) {
    currentMap.getSource('brush-cursor').setData(emptyFeatureCollection);
  }
}

function syncCursor() {
  if (!currentMap) return;
  const canvas = currentMap.getCanvas();
  canvas.style.cursor = painting || modifierDown ? 'crosshair' : '';
}

function syncPreviewPaint() {
  if (!currentMap || !currentMap.getLayer('brush-preview-fill')) return;
  currentMap.setPaintProperty('brush-preview-fill', 'fill-color', currentTool().color);
}

function syncBrushCursorPaint() {
  if (!currentMap || !currentMap.getLayer('brush-cursor-outline')) return;
  currentMap.setPaintProperty('brush-cursor-halo', 'circle-radius', Number(brush.size));
  currentMap.setPaintProperty('brush-cursor-outline', 'circle-radius', Number(brush.size));
  currentMap.setPaintProperty('brush-cursor-outline', 'circle-stroke-color', currentTool().color);
}

function currentTool() {
  return ratingTools.find(tool => tool.value === brush.value) ?? ratingTools[4];
}

function restoreDragPan() {
  if (currentMap && dragPanWasEnabled && !currentMap.dragPan.isEnabled()) {
    currentMap.dragPan.enable();
  }
  dragPanWasEnabled = false;
}

function isPaintModifier(e) {
  return e.metaKey || e.ctrlKey;
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
  } else if (e.key >= '1' && e.key <= '7' && !e.metaKey && !e.ctrlKey && !e.altKey && !isEditableTarget(e.target)) {
    const index = Number(e.key) - 1;
    brush.value = ratingTools[index].value;
    syncPreviewPaint();
    syncBrushCursorPaint();
  }

  if (e.metaKey || e.ctrlKey || e.key === 'Meta' || e.key === 'Control') {
    modifierDown = true;
    syncCursor();
    if (lastCursorLngLat) updateBrushCursor(lastCursorLngLat);
  }
}

function onKeyUp(e) {
  if (!e.metaKey && !e.ctrlKey && (e.key === 'Meta' || e.key === 'Control')) {
    modifierDown = false;
    syncCursor();
    clearBrushCursor();
  }
}

export function syncBrushSizePreview() {
  syncBrushCursorPaint();
  if ((modifierDown || painting) && lastCursorLngLat) updateBrushCursor(lastCursorLngLat);
}

function isEditableTarget(target) {
  if (!target) return false;
  const tag = target.tagName?.toLowerCase();
  return tag === 'input' || tag === 'textarea' || tag === 'select' || target.isContentEditable;
}
