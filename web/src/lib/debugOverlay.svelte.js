// Dev-only encoded-value visualizer. Adds an MVT source over the map showing
// per-edge values for the selected GraphHopper encoded value, served by the
// backend's /api/debug/mvt proxy.
//
// GraphHopper's MVTResource encodes per-edge feature properties as STRINGS:
//   - enum values are lowercase ("footway", "asphalt")
//   - directional values are pipe-separated, e.g. "true | true",
//     "50.0 | 50.0", "missing | missing"
// `paintExpression()` accepts both bare and `"X | X"` forms for the same key.

const FALLBACK = '#888';

const PALETTE = [
  '#e6194b', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4',
  '#46f0f0', '#f032e6', '#bcf60c', '#fabebe', '#008080', '#e6beff',
];

function enumMembers(values) {
  return values.map((v, i) => ({
    value: v,
    color: PALETTE[i % PALETTE.length],
    label: v,
  }));
}

export const ENCODED_VALUES = [
  // Bike-specific
  {
    key: 'bike_priority',
    kind: 'number',
    domain: [0, 1.5],
    stops: [
      [0.0, '#d73027'],
      [0.3, '#fdae61'],
      [0.6, '#fee08b'],
      [0.9, '#a6d96a'],
      [1.5, '#1a9850'],
    ],
    note: 'Decimal in [0, 1]. GraphHopper\'s opinionated "how nice is this for a bike" score. Used as <code>multiply_by: bike_priority</code> on the first line of <code>graphhopper_profile.json</code>.<br><br><strong>Computed from:</strong> Internal <code>BikePriorityParser</code> mixing <code>road_class</code>, <code>cycleway:*</code>, <code>bicycle=designated</code>, <code>bicycle_road=yes</code>, <code>surface</code>, <code>smoothness</code>, <code>tracktype</code>, <code>motor_vehicle=*</code>. Result is bucketed into ~7 levels (<code>AVOID_AT_ALL_COSTS</code> … <code>BEST</code>).<br><br><strong>Why keep:</strong> Free baseline shaping. Caveat: opaque — you can layer penalties on top, but you can\'t <em>raise</em> an edge above the bucket GraphHopper assigned.',
  },
  {
    key: 'bike_average_speed',
    kind: 'number',
    domain: [0, 30],
    stops: [
      [0,  '#d73027'],
      [10, '#fdae61'],
      [20, '#a6d96a'],
      [30, '#1a9850'],
    ],
    note: 'Decimal (km/h). Realistic cycling speed for the edge type and surface, before slope and custom-model speed rules apply.<br><br><strong>Computed from:</strong> <code>highway=*</code> table (cycleway ≈ 18, residential ≈ 18, secondary ≈ 16, track ≈ 12, path ≈ 10), then reduced by <code>surface</code> and <code>smoothness</code> heuristics.<br><br><strong>Why keep:</strong> Drives ETA. <code>bike_elevation.json</code> modulates this further by <code>average_slope</code>.',
  },
  {
    key: 'bike_road_access',
    kind: 'enum',
    members: enumMembers(['missing', 'yes', 'no', 'private', 'destination', 'delivery', 'customers', 'military', 'dismount', 'use_sidepath', 'designated']),
    note: 'Enum: <code>MISSING, YES, NO, PRIVATE, DESTINATION, DELIVERY, CUSTOMERS, MILITARY, DISMOUNT, USE_SIDEPATH, DESIGNATED</code>.<br><br><strong>Computed from:</strong> <code>bicycle=*</code> and <code>access=*</code> interpreted with bike-specific semantics. <code>DISMOUNT</code> ↔ <code>bicycle=dismount</code>; <code>USE_SIDEPATH</code> ↔ <code>bicycle=use_sidepath</code> (mandatory adjacent cycle path under StVO 2.3.4).<br><br><strong>Why keep:</strong> Lets us zero out roads with <code>bicycle=no</code>, penalise <code>PRIVATE</code> (already in our profile), and gives a hook to penalise <code>DISMOUNT</code>/<code>USE_SIDEPATH</code> later.',
  },
  {
    key: 'bike_network',
    kind: 'enum',
    members: [
      { value: 'missing',       color: '#666666', label: 'missing' },
      { value: 'other',         color: '#bbbbbb', label: 'other' },
      { value: 'local',         color: '#a6d96a', label: 'local' },
      { value: 'regional',      color: '#1a9850', label: 'regional' },
      { value: 'national',      color: '#4363d8', label: 'national' },
      { value: 'international', color: '#911eb4', label: 'international' },
    ],
    note: 'Enum: <code>MISSING, OTHER, INTERNATIONAL, NATIONAL, REGIONAL, LOCAL</code> (shared <code>RouteNetwork</code> enum).<br><br><strong>Computed from:</strong> OSM relations of <code>route=bicycle</code> with <code>network=icn|ncn|rcn|lcn</code>. Each edge inherits the highest-tier network it belongs to.<br><br><strong>Why keep:</strong> Berliner Mauerweg, Radfernweg Berlin–Kopenhagen, Leipzig, the regional RSV/Radschnellverbindungen all show up via this. Profile already gives ×1.4 / ×1.2.',
  },
  {
    key: 'mtb_rating',
    kind: 'number',
    domain: [0, 6],
    stops: [[0,'#1a9850'],[2,'#fee08b'],[4,'#f46d43'],[6,'#a50026']],
    note: 'Integer 0–6. 0 = no rating; higher = harder mountain-bike trail.<br><br><strong>Computed from:</strong> <code>mtb:scale=0..6</code>.<br><br><strong>Why keep:</strong> Upstream <code>bike.json</code> zeroes anything &gt; 2. Relevant in Grunewald/Spandauer Forst singletrack. Cheap.',
  },
  { key: 'hike_rating', kind: 'number', domain: [0, 6], stops: [[0,'#1a9850'],[2,'#fee08b'],[4,'#f46d43'],[6,'#a50026']] },
  {
    key: 'get_off_bike',
    kind: 'boolean',
    trueColor: '#d73027',
    falseColor: '#1a9850',
    directional: true,
    note: 'Boolean. <code>true</code> if a cyclist would typically have to dismount.<br><br><strong>Computed from:</strong> <code>bicycle=dismount</code>, <code>highway=steps</code>, <code>highway=footway</code> without <code>bicycle=yes</code>/<code>designated</code>, etc.<br><br><strong>Why keep:</strong> Cleaner than checking individual conditions in the custom model — one <code>multiply_by: 0.1</code> rule covers all dismount cases. Slightly redundant with <code>bike_road_access == DISMOUNT</code>, but covers the steps/footway cases that aren\'t tagged <code>bicycle=dismount</code>.',
  },

  // Surface / smoothness / cycleway
  {
    key: 'surface',
    kind: 'enum',
    members: enumMembers(['missing','other','paved','asphalt','concrete','paving_stones','cobblestone','unpaved','compacted','fine_gravel','gravel','ground','dirt','grass','sand','wood']),
    note: 'Enum: <code>MISSING, OTHER, PAVED, ASPHALT, CONCRETE, PAVING_STONES, COBBLESTONE, UNPAVED, COMPACTED, FINE_GRAVEL, GRAVEL, GROUND, DIRT, GRASS, SAND, WOOD</code>.<br><br><strong>Computed from:</strong> <code>surface=*</code>. Berlin note: <code>cobblestone</code> (rounded historic Kopfsteinpflaster) is much rougher than <code>paving_stones</code> (modern brick) — both common, both worth penalising at different strengths.<br><br><strong>Caveat:</strong> GraphHopper does not expose <code>sett</code> as a separate value — it\'s mapped to <code>OTHER</code>.',
  },
  {
    key: 'smoothness',
    kind: 'enum',
    members: [
      { value: 'impassable',    color: '#67000d', label: 'impassable' },
      { value: 'very_horrible', color: '#a50026', label: 'very_horrible' },
      { value: 'horrible',      color: '#d73027', label: 'horrible' },
      { value: 'very_bad',      color: '#f46d43', label: 'very_bad' },
      { value: 'bad',           color: '#fdae61', label: 'bad' },
      { value: 'intermediate',  color: '#fee08b', label: 'intermediate' },
      { value: 'good',          color: '#a6d96a', label: 'good' },
      { value: 'excellent',     color: '#1a9850', label: 'excellent' },
      { value: 'other',         color: '#bbbbbb', label: 'other' },
      { value: 'missing',       color: '#666666', label: 'missing' },
    ],
    note: 'Enum: <code>MISSING, OTHER, EXCELLENT, GOOD, INTERMEDIATE, BAD, VERY_BAD, HORRIBLE, VERY_HORRIBLE, IMPASSABLE</code>.<br><br><strong>Computed from:</strong> <code>smoothness=*</code>.<br><br><strong>Why keep:</strong> Sparse but high-signal in Berlin park paths. Where present, a cyclist would much rather take an <code>INTERMEDIATE</code>-rated road than the parallel <code>BAD</code> one. Pair with <code>surface</code>.',
  },
  {
    key: 'cycleway',
    kind: 'enum',
    directional: true,
    members: [
      { value: 'missing',     color: '#666666', label: 'missing' },
      { value: 'other',       color: '#bbbbbb', label: 'other' },
      { value: 'no',          color: '#d73027', label: 'no' },
      { value: 'shoulder',    color: '#fdae61', label: 'shoulder' },
      { value: 'shared_lane', color: '#fee08b', label: 'shared_lane' },
      { value: 'lane',        color: '#a6d96a', label: 'lane' },
      { value: 'track',       color: '#1a9850', label: 'track' },
      { value: 'separate',    color: '#4363d8', label: 'separate' },
    ],
    note: 'Enum: <code>MISSING, OTHER, NO, LANE, TRACK, SHARED_LANE, SHOULDER, SEPARATE</code>.<br><br><strong>Computed from:</strong> <code>cycleway=*</code> and side-specific <code>cycleway:left|right=*</code> collapsed to a single per-edge value.<br><br><strong>Why keep:</strong> Lets the profile prefer <code>LANE</code>/<code>TRACK</code> over <code>MISSING</code>. Particularly relevant for Berlin arterials where the cycleway is part of the road geometry (so <code>road_class != CYCLEWAY</code> even though there is a marked lane).<br><br><strong>Caveat:</strong> GH collapses left+right into one enum — biased toward whichever side it picks first. Acceptable for shaping; not for navigation instructions.',
  },
  {
    key: 'crossing',
    kind: 'enum',
    members: enumMembers(['missing','no','uncontrolled','marked','unmarked','traffic_signals','railway','railway_barrier']),
    note: 'Enum: <code>MISSING, NO, UNCONTROLLED, MARKED, UNMARKED, TRAFFIC_SIGNALS, RAILWAY, RAILWAY_BARRIER</code>.<br><br><strong>Computed from:</strong> <code>crossing=*</code> on <code>highway=crossing</code> nodes, propagated to adjacent edges.<br><br><strong>Why keep:</strong> Enables a future "prefer controlled crossings on big roads" rule.',
  },

  // Road structure
  {
    key: 'road_class',
    kind: 'enum',
    members: enumMembers(['other','motorway','trunk','primary','secondary','tertiary','residential','unclassified','service','road','track','footway','pedestrian','living_street','bridleway','steps','cycleway','path','construction','platform','corridor','busway']),
    note: 'Enum: <code>OTHER, MOTORWAY, TRUNK, PRIMARY, SECONDARY, TERTIARY, RESIDENTIAL, UNCLASSIFIED, SERVICE, ROAD, TRACK, FOOTWAY, PEDESTRIAN, LIVING_STREET, BRIDLEWAY, STEPS, CYCLEWAY, PATH, CONSTRUCTION, PLATFORM, CORRIDOR, BUSWAY</code>.<br><br><strong>Computed from:</strong> <code>highway=*</code>.<br><br><strong>Why keep:</strong> Foundation for per-class shaping — boost <code>LIVING_STREET</code>, <code>CYCLEWAY</code>; penalise <code>PRIMARY</code>/<code>SECONDARY</code> not on a network.',
  },
  {
    key: 'road_environment',
    kind: 'enum',
    members: [
      { value: 'road',   color: '#bbbbbb', label: 'road' },
      { value: 'bridge', color: '#4363d8', label: 'bridge' },
      { value: 'tunnel', color: '#911eb4', label: 'tunnel' },
      { value: 'ferry',  color: '#46f0f0', label: 'ferry' },
      { value: 'ford',   color: '#f58231', label: 'ford' },
      { value: 'other',  color: '#666666', label: 'other' },
    ],
    note: 'Enum: <code>OTHER, ROAD, FERRY, TUNNEL, BRIDGE, FORD</code>.<br><br><strong>Computed from:</strong> <code>tunnel=*</code>, <code>bridge=*</code>, <code>route=ferry</code>, <code>ford=*</code>.<br><br><strong>Why keep:</strong> Profile penalises ferries; useful for snap_preventions and fording avoidance. Cheap.',
  },
  {
    key: 'road_access',
    kind: 'enum',
    members: enumMembers(['yes','destination','delivery','customers','agricultural','forestry','private','military','no']),
    note: 'Enum: <code>YES, DESTINATION, DELIVERY, CUSTOMERS, AGRICULTURAL, FORESTRY, PRIVATE, MILITARY, NO</code>.<br><br><strong>Computed from:</strong> <code>access=*</code> (general, vehicle-agnostic).<br><br><strong>Why keep:</strong> Complements <code>bike_road_access</code> — picks up restrictions affecting all vehicles (gated forestry tracks in the Grunewald, military areas). Sometimes the cheaper signal when bike-specific tagging is missing.',
  },
  {
    key: 'roundabout',
    kind: 'boolean',
    trueColor: '#911eb4',
    falseColor: '#bbbbbb',
    note: 'Boolean. <code>true</code> if the edge is part of a <code>junction=roundabout</code> or <code>junction=circular</code>.<br><br><strong>Why keep:</strong> <code>bike.json</code> uses it to forbid wrong-way entry on roundabouts. Tiny cost.',
  },

  // Speed / slope (numeric, possibly directional → take forward side)
  {
    key: 'max_speed',
    kind: 'number',
    directional: true,
    domain: [0, 130],
    stops: [
      [0,   '#999999'],
      [30,  '#1a9850'],
      [50,  '#fee08b'],
      [70,  '#fdae61'],
      [100, '#d73027'],
      [130, '#67000d'],
    ],
    note: 'Decimal (km/h). The legal speed limit on the edge in the forward direction (<code>max_speed_reverse</code> exists separately). For German edges with no <code>maxspeed</code> tag, GraphHopper falls back to legal defaults via the <code>country</code> value.<br><br><strong>Computed from:</strong> <code>maxspeed=*</code>, then fallbacks per <code>country</code> × <code>road_class</code> × <code>urban_density</code> (<code>legal_default_speeds.json</code>).<br><br><strong>Why keep:</strong> Strong proxy for "scary to ride" — <code>max_speed &gt;= 50 km/h</code> without a separate cycleway is the classic Berlin Hauptverkehrsstraße. Profile rule waiting to be written.<br><br><em>"Infinity" (no legal limit) renders as 0/grey.</em>',
  },
  {
    key: 'average_slope',
    kind: 'number',
    domain: [-15, 15],
    stops: [
      [-15, '#2166ac'],
      [-5,  '#92c5de'],
      [0,   '#f7f7f7'],
      [5,   '#f4a582'],
      [15,  '#b2182b'],
    ],
    note: 'Decimal (%). Average gradient of the edge from elevation samples.<br><br><strong>Computed from:</strong> SRTM elevation data sampled along the way geometry.<br><br><strong>Why keep:</strong> Used by <code>bike_elevation.json</code> to drop speed on climbs and bump it on descents. Berlin is ~flat, so it rarely fires, but cheap to keep.',
  },
  {
    key: 'ferry_speed',
    kind: 'number',
    domain: [0, 30],
    stops: [[0, '#d73027'], [15, '#fee08b'], [30, '#1a9850']],
    note: 'Decimal (km/h). Speed at which to traverse a ferry edge.<br><br><strong>Why keep:</strong> <code>bike.json</code> references it. Cheap. (Almost no ferries inside the Berlin extract — Müggelsee, BVG-Fähre F10–F23 — but still relevant.)',
  },
];

const BY_KEY = new Map(ENCODED_VALUES.map((ev) => [ev.key, ev]));

export function getEncodedValue(key) {
  return BY_KEY.get(key);
}

// MapLibre expression that takes a property like "50.0 | 50.0" and returns
// the forward (left-of-pipe) substring. For non-directional values where the
// raw string has no pipe, returns the raw value.
function forwardPart(getExpr) {
  return [
    'let', 'raw', getExpr,
    [
      'case',
      ['>=', ['index-of', '|', ['var', 'raw']], 0],
      ['slice', ['var', 'raw'], 0, ['-', ['index-of', '|', ['var', 'raw']], 1]],
      ['var', 'raw'],
    ],
  ];
}

const TRANSPARENT = 'rgba(0,0,0,0)';

export function paintExpression(ev, hidden = []) {
  if (!ev) return FALLBACK;
  const get = ['get', ev.key];

  if (ev.kind === 'enum') {
    // Match both "value" and "value | value" (directional pairs where forward
    // == backward, which covers the common case). Hidden members render
    // transparent so toggling acts as a per-value visibility filter.
    const expr = ['match', get];
    for (const m of ev.members) {
      const color = hidden.includes(m.value) ? TRANSPARENT : m.color;
      expr.push([m.value, `${m.value} | ${m.value}`], color);
    }
    expr.push(FALLBACK);
    return expr;
  }

  if (ev.kind === 'boolean') {
    const truths = ev.directional
      ? ['true', 'true | true', 'true | false', 'false | true']
      : ['true'];
    return ['match', get, truths, ev.trueColor, ev.falseColor];
  }

  if (ev.kind === 'number') {
    const valueExpr = ev.directional ? forwardPart(get) : get;
    const expr = ['interpolate', ['linear'], ['to-number', valueExpr, ev.domain[0]]];
    for (const [v, c] of ev.stops) expr.push(v, c);
    return expr;
  }

  return FALLBACK;
}

// ---------- Map source/layer wiring ----------

const SOURCE_ID = 'gh-debug-mvt';
const LAYER_ID = 'gh-debug-edges';
const MIN_ZOOM = 12;
// MVTResource in graphhopper-web encodes one layer named "roads" containing
// every routable edge.
const SOURCE_LAYER = 'roads';

export const debugState = $state({
  /** null = overlay disabled */
  selectedKey: null,
  /** for the legend */
  selected: null,
  /** member values currently toggled off for the active enum overlay */
  hidden: [],
  /** global filter: hide road_class=footway across every overlay */
  hideFootways: false,
});

let currentMap = null;

function tileUrl(key) {
  // MapLibre fills {z}/{x}/{y}; we just need to keep `details` literal.
  // `road_class` is always requested so the global "hide footways" filter
  // can read it regardless of which encoded value is currently visualized.
  const extra = key === 'road_class' ? '' : '&details=road_class';
  return `/api/debug/mvt/{z}/{x}/{y}?details=${encodeURIComponent(key)}${extra}`;
}

function currentFilter() {
  return debugState.hideFootways
    ? ['!=', ['get', 'road_class'], 'footway']
    : ['literal', true];
}

function ensureSource(map, key) {
  // Tile URLs are baked in at addSource time, so we re-create the source
  // whenever the encoded value changes (and `details` along with it).
  removeSource(map);
  map.addSource(SOURCE_ID, {
    type: 'vector',
    tiles: [`${window.location.origin}${tileUrl(key)}`],
    minzoom: MIN_ZOOM,
    maxzoom: 22,
  });
}

function removeSource(map) {
  if (map.getLayer(LAYER_ID)) map.removeLayer(LAYER_ID);
  if (map.getSource(SOURCE_ID)) map.removeSource(SOURCE_ID);
}

function applyLayer(map, ev) {
  if (map.getLayer(LAYER_ID)) map.removeLayer(LAYER_ID);
  map.addLayer({
    id: LAYER_ID,
    type: 'line',
    source: SOURCE_ID,
    'source-layer': SOURCE_LAYER,
    minzoom: MIN_ZOOM,
    filter: currentFilter(),
    paint: {
      'line-color': paintExpression(ev, debugState.hidden),
      'line-width': ['interpolate', ['linear'], ['zoom'], 12, 1, 16, 3, 20, 6],
      'line-opacity': 0.85,
    },
  });
}

export function setHideFootways(value) {
  debugState.hideFootways = !!value;
  if (currentMap?.getLayer(LAYER_ID)) {
    currentMap.setFilter(LAYER_ID, currentFilter());
  }
}

function refreshPaint() {
  if (!currentMap || !debugState.selected) return;
  if (!currentMap.getLayer(LAYER_ID)) return;
  currentMap.setPaintProperty(
    LAYER_ID,
    'line-color',
    paintExpression(debugState.selected, debugState.hidden),
  );
}

export function toggleMember(value) {
  const idx = debugState.hidden.indexOf(value);
  if (idx >= 0) debugState.hidden.splice(idx, 1);
  else debugState.hidden.push(value);
  refreshPaint();
}

export function setAllMembersVisible() {
  debugState.hidden.length = 0;
  refreshPaint();
}

export function setAllMembersHidden() {
  const ev = debugState.selected;
  if (!ev || ev.kind !== 'enum') return;
  debugState.hidden.splice(0, debugState.hidden.length, ...ev.members.map((m) => m.value));
  refreshPaint();
}

export function initDebugOverlay(map) {
  currentMap = map;
}

export function setEncodedValue(key) {
  debugState.hidden.length = 0;
  if (!currentMap) {
    debugState.selectedKey = key;
    debugState.selected = key ? getEncodedValue(key) : null;
    return;
  }
  if (!key) {
    removeSource(currentMap);
    debugState.selectedKey = null;
    debugState.selected = null;
    return;
  }
  const ev = getEncodedValue(key);
  if (!ev) return;
  ensureSource(currentMap, key);
  applyLayer(currentMap, ev);
  debugState.selectedKey = key;
  debugState.selected = ev;
}
