import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import ZoomControls from './ZoomControls.svelte';

describe('ZoomControls', () => {
  it('renders zoom in and zoom out buttons', () => {
    const map = { zoomIn: vi.fn(), zoomOut: vi.fn() };
    render(ZoomControls, { map });
    // Buttons use aria-label for accessible names
    expect(screen.getByRole('button', { name: /zoom in/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /zoom out/i })).toBeInTheDocument();
  });

  it('calls map.zoomIn when zoom in button is clicked', async () => {
    const map = { zoomIn: vi.fn(), zoomOut: vi.fn() };
    render(ZoomControls, { map });
    await fireEvent.click(screen.getByRole('button', { name: /zoom in/i }));
    expect(map.zoomIn).toHaveBeenCalledOnce();
    expect(map.zoomOut).not.toHaveBeenCalled();
  });

  it('calls map.zoomOut when zoom out button is clicked', async () => {
    const map = { zoomIn: vi.fn(), zoomOut: vi.fn() };
    render(ZoomControls, { map });
    await fireEvent.click(screen.getByRole('button', { name: /zoom out/i }));
    expect(map.zoomOut).toHaveBeenCalledOnce();
    expect(map.zoomIn).not.toHaveBeenCalled();
  });
});
