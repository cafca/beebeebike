import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { route } from '../lib/routing.svelte.js';
import { locations } from '../lib/locations.svelte.js';
import SearchBar from './SearchBar.svelte';

beforeEach(() => {
  route.origin = null;
  route.destination = null;
  route.data = null;
  route.loading = false;
  locations.home = null;
  locations.startAtHome = false;
});

describe('SearchBar', () => {
  it('renders the search input with origin placeholder by default', () => {
    render(SearchBar);
    expect(screen.getByPlaceholderText(/search origin/i)).toBeInTheDocument();
  });

  it('shows geocode results after typing and debounce', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    render(SearchBar);
    const input = screen.getByPlaceholderText(/search origin/i);
    await fireEvent.input(input, { target: { value: 'Alex' } });
    // Advance past the 300ms debounce
    await vi.advanceTimersByTimeAsync(350);
    // MSW returns Alexanderplatz
    expect(await screen.findByText(/alexanderplatz/i, {}, { timeout: 1000 })).toBeInTheDocument();
    vi.useRealTimers();
  });

  it('selecting a result sets route.origin and clears the results list', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    render(SearchBar);
    const input = screen.getByPlaceholderText(/search origin/i);
    await fireEvent.input(input, { target: { value: 'Alex' } });
    await vi.advanceTimersByTimeAsync(350);
    const result = await screen.findByText(/alexanderplatz/i, {}, { timeout: 1000 });
    await fireEvent.click(result.closest('button'));
    expect(route.origin).toMatchObject({ name: 'Alexanderplatz' });
    // After selection, results dropdown (the <ul>) should be gone
    expect(screen.queryByRole('list')).not.toBeInTheDocument();
    vi.useRealTimers();
  });
});
