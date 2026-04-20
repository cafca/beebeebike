import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { suppressNextMapClick, shouldSuppressMapClick } from './paintGesture.js';

describe('paintGesture', () => {
  beforeEach(() => vi.useFakeTimers({ shouldAdvanceTime: false }));
  afterEach(() => vi.useRealTimers());

  it('returns false before any suppression', () => {
    expect(shouldSuppressMapClick()).toBe(false);
  });

  it('returns true for 250ms after suppressNextMapClick', () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
    suppressNextMapClick();
    expect(shouldSuppressMapClick()).toBe(true);
    vi.setSystemTime(new Date('2026-01-01T00:00:00.249Z'));
    expect(shouldSuppressMapClick()).toBe(true);
    vi.setSystemTime(new Date('2026-01-01T00:00:00.251Z'));
    expect(shouldSuppressMapClick()).toBe(false);
  });
});
