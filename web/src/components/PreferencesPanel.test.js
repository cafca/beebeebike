import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { preferences } from '../lib/preferences.svelte.js';
import { route } from '../lib/routing.svelte.js';
import PreferencesPanel from './PreferencesPanel.svelte';

beforeEach(() => {
  // Reset to defaults
  preferences.ratingWeight = 0.5;
  preferences.distanceInfluence = 60;
  route.origin = null;
  route.destination = null;
});

describe('PreferencesPanel', () => {
  it('renders Preference strength label and formatted value', () => {
    render(PreferencesPanel);
    expect(screen.getByLabelText(/preference strength/i)).toBeInTheDocument();
    // Default ratingWeight 0.5 → "50%"
    expect(screen.getByText('50%')).toBeInTheDocument();
  });

  it('renders Route directness label and formatted value', () => {
    render(PreferencesPanel);
    expect(screen.getByLabelText(/route directness/i)).toBeInTheDocument();
    // Default distanceInfluence 60 → "60"
    expect(screen.getByText('60')).toBeInTheDocument();
  });

  it('updating the rating-weight slider persists the new value', async () => {
    render(PreferencesPanel);
    const slider = screen.getByLabelText(/preference strength/i);
    await fireEvent.input(slider, { target: { value: '0.75' } });
    expect(preferences.ratingWeight).toBeCloseTo(0.75);
    expect(window.localStorage.getItem('beebeebike.ratingWeight')).toBe('0.75');
  });

  it('updating the distance-influence slider persists the new value', async () => {
    render(PreferencesPanel);
    const slider = screen.getByLabelText(/route directness/i);
    await fireEvent.input(slider, { target: { value: '50' } });
    expect(preferences.distanceInfluence).toBe(50);
    expect(window.localStorage.getItem('beebeebike.distanceInfluence')).toBe('50');
  });
});
