import { describe, it, expect } from 'vitest';
import { buildBicycleStyle, COLORS } from './bicycle-style.js';

const opts = {
  tilesUrl: 'http://tiles.example/{z}/{x}/{y}',
  glyphsUrl: 'http://tiles.example/fonts/{fontstack}/{range}',
  spriteUrl: 'http://tiles.example/sprites/basics',
};

describe('buildBicycleStyle', () => {
  it('returns a style with name, glyphs, and sprite applied', () => {
    const style = buildBicycleStyle(opts);
    expect(style.name).toBe('beebeebike-bicycle-planning');
    expect(style.glyphs).toBe(opts.glyphsUrl);
    expect(style.sprite).toEqual([{ id: 'basics', url: opts.spriteUrl }]);
  });

  it('rewrites vector source tiles to the provided URL', () => {
    const style = buildBicycleStyle(opts);
    const vectorSources = Object.values(style.sources).filter(s => s.type === 'vector');
    expect(vectorSources.length).toBeGreaterThan(0);
    for (const src of vectorSources) {
      expect(src.tiles).toEqual([opts.tilesUrl]);
      expect(src.scheme).toBe('xyz');
    }
  });

  it('inserts the bike-priority layers', () => {
    const style = buildBicycleStyle(opts);
    const ids = style.layers.map(l => l.id);
    for (const expected of [
      'bike-cycleway',
      'bike-cycleway-casing',
      'bike-designated',
      'bike-street-corridor',
      'bike-arterial-caution',
      'bike-steps-caution',
    ]) {
      expect(ids).toContain(expected);
    }
  });

  it('exports the bicycle palette', () => {
    expect(COLORS.cycleway).toMatch(/^#[0-9a-f]{6}$/i);
    expect(Object.keys(COLORS)).toContain('background');
  });

  it('scales symbol text sizes when mobile: true', () => {
    const web = buildBicycleStyle(opts);
    const mobile = buildBicycleStyle({ ...opts, mobile: true });

    const pickText = style =>
      style.layers.find(
        l => l.type === 'symbol' && typeof l.layout?.['text-size'] === 'number'
      );
    const a = pickText(web);
    const b = pickText(mobile);
    if (a && b) {
      expect(b.layout['text-size']).toBeGreaterThan(a.layout['text-size']);
    }
  });
});
