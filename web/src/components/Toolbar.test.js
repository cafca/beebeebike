import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { brush, ratingTools } from '../lib/brush.svelte.js';
import Toolbar from './Toolbar.svelte';

beforeEach(() => {
  brush.value = 1;
  brush.size = 30;
  brush.canUndo = false;
  brush.canRedo = false;
  brush.paintMode = false;
});

describe('Toolbar', () => {
  it('renders color buttons for all rating tools', () => {
    render(Toolbar);
    // Color buttons have titles like "1: -7", "2: -3", ..., "4: Eraser", ..., "7: 7"
    ratingTools.forEach((r, i) => {
      const expectedTitle = `${i + 1}: ${r.value === 0 ? 'Eraser' : r.value}`;
      expect(screen.getByTitle(expectedTitle)).toBeInTheDocument();
    });
  });

  it('clicking a color button updates brush.value', async () => {
    render(Toolbar);
    // Click the first color button (value = -7, title = "1: -7")
    await fireEvent.click(screen.getByTitle('1: -7'));
    expect(brush.value).toBe(-7);
  });

  it('undo button is disabled when canUndo is false', () => {
    brush.canUndo = false;
    render(Toolbar);
    // Toolbar renders undo in two places (.undo-redo-inline and .undo-redo-fab); all should be disabled
    const undoBtns = screen.getAllByTitle('Undo (Ctrl+Z)');
    expect(undoBtns.length).toBeGreaterThan(0);
    undoBtns.forEach(btn => expect(btn).toBeDisabled());
  });

  it('paint toggle button reflects paintMode state and toggles it', async () => {
    brush.paintMode = false;
    render(Toolbar);
    const toggleBtn = screen.getByTitle('Enter paint mode (draw with touch/click)');
    expect(toggleBtn).toBeInTheDocument();
    await fireEvent.click(toggleBtn);
    expect(brush.paintMode).toBe(true);
  });
});
