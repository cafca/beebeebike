import { describe, it, expect, beforeEach } from 'vitest';
import { brush, ratingTools, togglePaintMode } from './brush.svelte.js';

beforeEach(() => {
  brush.value = 1;
  brush.size = 30;
  brush.canUndo = false;
  brush.canRedo = false;
  brush.paintMode = false;
});

describe('brush store', () => {
  it('exposes the seven rating tools including eraser', () => {
    expect(ratingTools.map(t => t.value)).toEqual([-7, -3, -1, 0, 1, 3, 7]);
    expect(ratingTools.find(t => t.value === 0)).toBeDefined();
  });

  it('togglePaintMode flips the flag without a map', () => {
    expect(brush.paintMode).toBe(false);
    togglePaintMode();
    expect(brush.paintMode).toBe(true);
    togglePaintMode();
    expect(brush.paintMode).toBe(false);
  });

  it('allows direct state mutation for size/value', () => {
    brush.value = -3;
    brush.size = 50;
    expect(brush.value).toBe(-3);
    expect(brush.size).toBe(50);
  });
});
