#!/usr/bin/env node
// Builds mobile/assets/styles/beebeebike-style.json by running
// `buildBicycleStyle` (which wraps `@versatiles/style`) with placeholder URLs.
// The mobile app substitutes `{{TILE_BASE}}` with `AppConfig.tileServerBaseUrl`
// at runtime.
//
// Usage:
//   npm --prefix web run build:mobile-style

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import { buildBicycleStyle } from '../src/lib/bicycle-style.js';

const TILE_BASE = '{{TILE_BASE}}';

const style = buildBicycleStyle({
  tilesUrl: `${TILE_BASE}/tiles/osm/{z}/{x}/{y}`,
  glyphsUrl: `${TILE_BASE}/assets/glyphs/{fontstack}/{range}.pbf`,
  spriteUrl: `${TILE_BASE}/assets/sprites/basics/sprites`,
  mobile: true,
});

const here = dirname(fileURLToPath(import.meta.url));
const outPath = resolve(here, '../../mobile/assets/styles/beebeebike-style.json');
writeFileSync(outPath, `${JSON.stringify(style, null, '\t')}\n`);

const sizeKb = (JSON.stringify(style).length / 1024).toFixed(1);
console.log(`wrote ${outPath} (${sizeKb} KB)`);
