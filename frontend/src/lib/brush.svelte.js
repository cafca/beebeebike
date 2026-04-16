import buffer from '@turf/buffer';
import { lineString } from '@turf/helpers';
import { api } from './api.js';
import { refreshOverlay } from './overlay.js';
import { suppressNextMapClick } from './paintGesture.js';
import { computeRoute, route } from './routing.svelte.js';

export const ratingTools = [
  { value: -7, color: '#c0392b' },
  { value: -3, color: '#e74c3c' },
  { value: -1, color: '#f1948a' },
  { value: 0,  color: '#6b7280' },
  { value: 1,  color: '#76d7c4' },
  { value: 3,  color: '#1abc9c' },
  { value: 7,  color: '#0e6655' },
];

// Shared reactive state
export const brush = $state({
  value: 1,
  size: 30,
  canUndo: false,
  canRedo: false,
  paintMode: false,
});

let painting = false;
let activePointerId = null;
let lastTouchEndTime = 0;
let points = [];
let lastPointerPixel = null;
let lastAddedPixel = null;
let previewRafId = null;
const MIN_MOVE_PX = 4; // suppress sub-pixel jitter; squared below
let currentMap = null;
let initialized = false;
let currentCanvas = null;
let dragPanWasEnabled = false;
let modifierDown = false;
let lastCursorLngLat = null;
let hoveringOverRecolorTarget = false;
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
  currentCanvas.removeEventListener('pointerdown', onPointerDown, listenerOptions);
  currentCanvas.removeEventListener('pointermove', onPointerMove, listenerOptions);
  currentCanvas.removeEventListener('pointerleave', onPointerLeave, listenerOptions);
  currentCanvas.removeEventListener('pointercancel', onPointerCancel, listenerOptions);
  currentCanvas.addEventListener('pointerdown', onPointerDown, listenerOptions);
  currentCanvas.addEventListener('pointermove', onPointerMove, listenerOptions);
  currentCanvas.addEventListener('pointerleave', onPointerLeave, listenerOptions);
  currentCanvas.addEventListener('pointercancel', onPointerCancel, listenerOptions);
  document.removeEventListener('pointerup', onPointerUp, listenerOptions);
  document.addEventListener('pointerup', onPointerUp, listenerOptions);
  document.addEventListener('keydown', onKeyDown);
  document.addEventListener('keyup', onKeyUp);

  initialized = true;
  syncCursor();
  syncPreviewPaint();
  syncBrushCursorPaint();

  // Sync initial undo/redo button state from the server
  refreshOverlay(map).then((data) => {
    if (data) {
      brush.canUndo = data.can_undo ?? false;
      brush.canRedo = data.can_redo ?? false;
    }
  });
}

export function destroyBrush() {
  if (currentCanvas) {
    currentCanvas.style.cursor = '';
    currentCanvas.style.touchAction = '';
    currentCanvas.removeEventListener('pointerdown', onPointerDown, listenerOptions);
    currentCanvas.removeEventListener('pointermove', onPointerMove, listenerOptions);
    currentCanvas.removeEventListener('pointerleave', onPointerLeave, listenerOptions);
    currentCanvas.removeEventListener('pointercancel', onPointerCancel, listenerOptions);
  }
  document.removeEventListener('pointerup', onPointerUp, listenerOptions);
  document.removeEventListener('keydown', onKeyDown);
  document.removeEventListener('keyup', onKeyUp);
  if (brush.paintMode && currentMap) {
    currentMap.dragPan.enable();
  }
  if (previewRafId !== null) {
    cancelAnimationFrame(previewRafId);
    previewRafId = null;
  }
  brush.paintMode = false;
  painting = false;
  activePointerId = null;
  points = [];
  lastAddedPixel = null;
  modifierDown = false;
  lastCursorLngLat = null;
  clearBrushCursor();
  restoreDragPan();
  initialized = false;
  currentCanvas = null;
  currentMap = null;
}

function onPointerDown(e) {
  if (!isPaintModifier(e)) return;
  if (e.button !== 0) return;

  // A second pointer while already painting means a pinch gesture has started — cancel
  // the current stroke and let MapLibre handle zoom/rotate.
  if (painting) {
    cancelPaint();
    return;
  }

  // The second tap of a double-tap-and-drag touch-zoom fires as a lone pointerdown;
  // ignore it so only deliberate single-finger drags paint.
  if (e.pointerType === 'touch' && Date.now() - lastTouchEndTime < 300) {
    return;
  }

  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();

  activePointerId = e.pointerId;
  painting = true;
  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);
  lastPointerPixel = [e.offsetX, e.offsetY];
  lastAddedPixel = [e.offsetX, e.offsetY];
  points = [lastCursorLngLat];
  currentCanvas.setPointerCapture(e.pointerId);
  if (!brush.paintMode) {
    dragPanWasEnabled = currentMap.dragPan.isEnabled();
    if (dragPanWasEnabled) currentMap.dragPan.disable();
  }
  syncCursor();
  updateBrushCursor(lastCursorLngLat);
}

function onPointerMove(e) {
  // Ignore move events from fingers that are not the active painting pointer
  if (painting && e.pointerId !== activePointerId) return;

  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);

  if (!painting) {
    const paintModifier = isPaintModifier(e);
    modifierDown = paintModifier;

    if (paintModifier) {
      const pixel = [e.offsetX, e.offsetY];
      const features = currentMap.queryRenderedFeatures(pixel, { layers: ['ratings-fill'] });
      hoveringOverRecolorTarget = features.length > 0 &&
        features[0].properties?.value !== undefined &&
        features[0].properties.value !== brush.value;
      if (hoveringOverRecolorTarget) {
        clearBrushCursor();
      } else {
        updateBrushCursor(lastCursorLngLat);
      }
    } else {
      hoveringOverRecolorTarget = false;
      clearBrushCursor();
    }
    syncCursor();
    return;
  }

  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();

  // Only add a point when the pointer has moved a meaningful distance to avoid
  // bloating the points array with jitter (each point feeds Turf buffer()).
  const dx = e.offsetX - lastAddedPixel[0];
  const dy = e.offsetY - lastAddedPixel[1];
  if (dx * dx + dy * dy >= MIN_MOVE_PX * MIN_MOVE_PX) {
    lastAddedPixel = [e.offsetX, e.offsetY];
    points.push(lastCursorLngLat);
    schedulePreview();
  }
  updateBrushCursor(lastCursorLngLat);
}

function onPointerLeave() {
  if (!painting) {
    lastCursorLngLat = null;
    hoveringOverRecolorTarget = false;
    clearBrushCursor();
    syncCursor();
  }
}

function onPointerUp(e) {
  if (!painting) return;
  if (e.pointerId !== activePointerId) return;

  if (e.pointerType === 'touch') lastTouchEndTime = Date.now();
  activePointerId = null;
  if (previewRafId !== null) {
    cancelAnimationFrame(previewRafId);
    previewRafId = null;
  }

  e?.preventDefault();
  e?.stopPropagation();
  e?.stopImmediatePropagation?.();
  painting = false;
  suppressNextMapClick();
  restoreDragPan();
  syncCursor();
  if ((modifierDown || brush.paintMode) && lastCursorLngLat) {
    updateBrushCursor(lastCursorLngLat);
  } else {
    clearBrushCursor();
  }

  if (points.length < 2) {
    clearPreview();
    if (lastPointerPixel) {
      const features = currentMap.queryRenderedFeatures(lastPointerPixel, { layers: ['ratings-fill'] });
      if (features.length > 0) {
        const feature = features[0];
        const featureValue = feature.properties?.value;
        if (featureValue !== undefined && featureValue !== brush.value) {
          submitPaint(feature.geometry, brush.value, featureAreaId(feature));
        }
      }
    }
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

function cancelPaint() {
  if (previewRafId !== null) {
    cancelAnimationFrame(previewRafId);
    previewRafId = null;
  }
  painting = false;
  activePointerId = null;
  points = [];
  lastPointerPixel = null;
  lastAddedPixel = null;
  clearPreview();
  restoreDragPan();
  syncCursor();
}

function onPointerCancel(e) {
  if (painting && e.pointerId === activePointerId) {
    cancelPaint();
  }
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

function schedulePreview() {
  if (previewRafId !== null) return;
  previewRafId = requestAnimationFrame(() => {
    previewRafId = null;
    if (painting) updatePreview();
  });
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
  if (painting) {
    canvas.style.cursor = 'crosshair';
  } else if ((modifierDown || brush.paintMode) && hoveringOverRecolorTarget) {
    canvas.style.cursor = createBucketCursor(currentTool().color);
  } else if (modifierDown || brush.paintMode) {
    canvas.style.cursor = 'crosshair';
  } else {
    canvas.style.cursor = '';
  }
}

function createBucketCursor(color) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
    <path fill="#111" stroke="#fff" stroke-width="0.8" d="M16.56 8.94L7.62 0 6.21 1.41l2.38 2.38-5.15 5.15c-.59.56-.59 1.53 0 2.12l5.5 5.5c.29.29.68.44 1.06.44s.77-.15 1.06-.44l5.5-5.5c.59-.58.59-1.53 0-2.12zM5.21 10L10 5.21 14.79 10H5.21z"/>
    <path fill="${color}" stroke="#fff" stroke-width="0.8" d="M19 11.5s-2 2.17-2 3.5c0 1.1.9 2 2 2s2-.9 2-2c0-1.33-2-3.5-2-3.5z"/>
  </svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}") 19 17, pointer`;
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
  if (brush.paintMode) return;
  if (currentMap && dragPanWasEnabled && !currentMap.dragPan.isEnabled()) {
    currentMap.dragPan.enable();
  }
  dragPanWasEnabled = false;
}

export function togglePaintMode() {
  brush.paintMode = !brush.paintMode;
  if (currentMap) {
    if (brush.paintMode) {
      currentMap.dragPan.disable();
      currentMap.getCanvas().style.touchAction = 'none';
    } else {
      currentMap.dragPan.enable();
      currentMap.getCanvas().style.touchAction = '';
    }
  }
  syncCursor();
}

function isPaintModifier(e) {
  return e.metaKey || e.ctrlKey || brush.paintMode;
}

function featureAreaId(feature) {
  const rawId = feature?.id ?? feature?.properties?.id;
  const id = Number(rawId);
  return Number.isFinite(id) ? id : null;
}

async function submitPaint(geometry, value, targetId = null) {
  try {
    const result = await api.paint(geometry, value, targetId);
    brush.canUndo = result.can_undo;
    brush.canRedo = result.can_redo;
    await refreshOverlay(currentMap);
    await refreshRouteIfReady();
  } catch (e) {
    console.error('Paint failed:', e);
  }
}

export async function undo() {
  try {
    const r = await api.undo();
    brush.canUndo = r.can_undo;
    brush.canRedo = r.can_redo;
    await refreshOverlay(currentMap);
    await refreshRouteIfReady();
  } catch (e) {
    console.error('Undo failed:', e);
  }
}

export async function redo() {
  try {
    const r = await api.redo();
    brush.canUndo = r.can_undo;
    brush.canRedo = r.can_redo;
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
