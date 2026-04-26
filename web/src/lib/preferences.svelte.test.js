import { describe, it, expect, beforeEach } from 'vitest';
import {
  preferences,
  setRatingWeight,
  setDistanceInfluence,
  formatRatingWeight,
  formatDistanceInfluence,
} from './preferences.svelte.js';

beforeEach(() => {
  // Module-level $state retains values between tests; reset by invoking setters.
  setRatingWeight(0.5);
  setDistanceInfluence(60);
});

describe('preferences', () => {
  it('clamps ratingWeight to [0, 1]', () => {
    setRatingWeight(1.5);
    expect(preferences.ratingWeight).toBe(1);
    setRatingWeight(-0.2);
    expect(preferences.ratingWeight).toBe(0);
  });

  it('clamps distanceInfluence to [0, 100]', () => {
    setDistanceInfluence(150);
    expect(preferences.distanceInfluence).toBe(100);
    setDistanceInfluence(-5);
    expect(preferences.distanceInfluence).toBe(0);
  });

  it('falls back to defaults for NaN', () => {
    setRatingWeight('hello');
    expect(preferences.ratingWeight).toBe(0.5);
    setDistanceInfluence(undefined);
    expect(preferences.distanceInfluence).toBe(60);
  });

  it('persists ratingWeight to localStorage', () => {
    setRatingWeight(0.8);
    expect(window.localStorage.getItem('beebeebike.ratingWeight')).toBe('0.8');
  });

  it('persists distanceInfluence to localStorage', () => {
    setDistanceInfluence(42);
    expect(window.localStorage.getItem('beebeebike.distanceInfluence')).toBe('42');
  });

  it('formats for display', () => {
    expect(formatRatingWeight(0.75)).toBe('75%');
    expect(formatDistanceInfluence(42.6)).toBe('43');
  });
});
