import { describe, it, expect } from 'vitest';
import { ENCODED_VALUES, paintExpression, getEncodedValue } from './debugOverlay.svelte.js';

describe('debugOverlay metadata', () => {
  it('every entry has a unique key', () => {
    const keys = ENCODED_VALUES.map((ev) => ev.key);
    expect(new Set(keys).size).toBe(keys.length);
  });

  it('enum entries have at least one member', () => {
    for (const ev of ENCODED_VALUES) {
      if (ev.kind === 'enum') {
        expect(ev.members.length).toBeGreaterThan(0);
        for (const m of ev.members) {
          expect(typeof m.value).toBe('string');
          expect(m.color).toMatch(/^#[0-9a-f]{6}$/i);
        }
      }
    }
  });

  it('number entries have monotonically increasing stop domains', () => {
    for (const ev of ENCODED_VALUES) {
      if (ev.kind !== 'number') continue;
      const xs = ev.stops.map(([v]) => v);
      for (let i = 1; i < xs.length; i++) {
        expect(xs[i]).toBeGreaterThan(xs[i - 1]);
      }
    }
  });
});

describe('paintExpression', () => {
  it('returns a fallback color for unknown encoded values', () => {
    expect(paintExpression(undefined)).toBe('#888');
  });

  it('builds a match expression covering bare and "X | X" pair forms for enums', () => {
    const ev = getEncodedValue('road_class');
    const expr = paintExpression(ev);
    expect(expr[0]).toBe('match');
    expect(expr[1]).toEqual(['get', 'road_class']);
    // Each member contributes one [bare, "v | v"] / color pair.
    for (const m of ev.members) {
      const idx = expr.findIndex(
        (v) => Array.isArray(v) && v[0] === m.value && v[1] === `${m.value} | ${m.value}`
      );
      expect(idx, `member ${m.value} missing from match`).toBeGreaterThan(-1);
      expect(expr[idx + 1]).toBe(m.color);
    }
    // Final element is the fallback color.
    expect(expr[expr.length - 1]).toBe('#888');
  });

  it('builds a directional boolean expression that accepts mixed pairs', () => {
    const ev = getEncodedValue('get_off_bike');
    const expr = paintExpression(ev);
    expect(expr[0]).toBe('match');
    expect(expr[2]).toEqual(['true', 'true | true', 'true | false', 'false | true']);
    expect(expr[3]).toBe(ev.trueColor);
    expect(expr[4]).toBe(ev.falseColor);
  });

  it('non-directional boolean only matches "true"', () => {
    const ev = getEncodedValue('roundabout');
    const expr = paintExpression(ev);
    expect(expr[2]).toEqual(['true']);
  });

  it('directional number expression slices forward part before to-number', () => {
    const ev = getEncodedValue('max_speed');
    const expr = paintExpression(ev);
    // ["interpolate", ["linear"], <inputExpr>, stop1, color1, ...]
    expect(expr[0]).toBe('interpolate');
    const valueExpr = expr[2];
    expect(valueExpr[0]).toBe('to-number');
    expect(JSON.stringify(valueExpr)).toContain('index-of');
    expect(JSON.stringify(valueExpr)).toContain('slice');
  });

  it('non-directional number reads the property directly', () => {
    const ev = getEncodedValue('average_slope');
    const expr = paintExpression(ev);
    expect(expr[2]).toEqual(['to-number', ['get', 'average_slope'], -15]);
  });
});
