# GraphHopper encoded values for bicycle routing

Reference for every built-in encoded value in `graphhopper-web-12.0` that is plausibly relevant for a city-bike profile in Berlin. Each section explains what the value means, how GraphHopper computes it from OSM tags at import time, and a verdict on whether to add it to `graph.encoded_values` in [graphhopper_config.yml](graphhopper_config.yml).

Adding any new value below requires a graph reimport (`rm -rf data/osm/berlin/graphhopper && just preview`).

The current set in this repo is:

```
country, road_class, roundabout, max_speed, road_environment,
bike_access, foot_access, bike_average_speed, bike_priority,
bike_road_access, bike_network,
mtb_rating, hike_rating, average_slope, ferry_speed,
road_access, get_off_bike, surface, smoothness, cycleway, crossing
```

Graph cache stays well below the prior `car`/`foot`/`bike` baseline
despite the expanded bike-shaping set — dropping the `car_*` EVs and
disabling CH preparation more than pay for the additions.

Verdict legend:
- ✅ already in — keep
- ➕ add — concrete win for a Berlin bike profile
- 🤔 maybe — situationally useful, low priority
- ❌ skip — not relevant for bikes

---

## Bike-specific values

### `bike_access` ✅ already in
Boolean per direction. `true` if a bicycle is legally allowed to traverse the edge in the forward direction. `backward_bike_access` is the implicit opposite-direction sibling exposed in custom-model expressions.

**Computed from:** `bicycle=*`, `access=*`, `highway=*` defaults (e.g. `highway=motorway` ⇒ no bike access; `highway=cycleway` ⇒ designated), plus country-specific defaults (Country.GERMANY enables bicycle on `highway=footway` only when `bicycle=yes`).

**Why keep:** Hard prerequisite — the upstream `bike.json` zeroes priority for edges with no bike access in either direction.

---

### `bike_average_speed` ✅ already in
Decimal (km/h). Realistic cycling speed for the edge type and surface, before slope and custom-model speed rules apply.

**Computed from:** `highway=*` table (cycleway ≈ 18, residential ≈ 18, secondary ≈ 16, track ≈ 12, path ≈ 10), then reduced by `surface` and `smoothness` heuristics.

**Why keep:** Drives ETA. `bike_elevation.json` modulates this further by `average_slope`.

---

### `bike_priority` ✅ already in
Decimal in `[0, 1]`. GraphHopper's opinionated "how nice is this for a bike" score. Used as `multiply_by: bike_priority` on the first line of `graphhopper_profile.json`.

**Computed from:** Internal `BikePriorityParser` mixing `road_class`, `cycleway:*`, `bicycle=designated`, `bicycle_road=yes`, `surface`, `smoothness`, `tracktype`, `motor_vehicle=*`. Result is bucketed into ~7 levels (`AVOID_AT_ALL_COSTS` … `BEST`).

**Why keep:** Free baseline shaping. Caveat: opaque — you can layer penalties on top, but you can't *raise* an edge above the bucket GraphHopper assigned.

---

### `bike_road_access` ✅ already in
Enum: `MISSING, YES, NO, PRIVATE, DESTINATION, DELIVERY, CUSTOMERS, MILITARY, DISMOUNT, USE_SIDEPATH, DESIGNATED`.

**Computed from:** `bicycle=*` and `access=*` interpreted with bike-specific semantics. `DISMOUNT` ↔ `bicycle=dismount`; `USE_SIDEPATH` ↔ `bicycle=use_sidepath` (mandatory adjacent cycle path under StVO 2.3.4).

**Why keep:** Lets us zero out roads with `bicycle=no`, penalise `PRIVATE` (already in our profile), and gives a hook to penalise `DISMOUNT`/`USE_SIDEPATH` later.

---

### `bike_network` ✅ already in
Enum: `MISSING, OTHER, INTERNATIONAL, NATIONAL, REGIONAL, LOCAL` (shared `RouteNetwork` enum with `foot_network`, etc.).

**Computed from:** OSM relations of `route=bicycle` with `network=icn|ncn|rcn|lcn`. Each edge inherits the highest-tier network it belongs to.

**Why keep:** Berliner Mauerweg, Radfernweg Berlin–Kopenhagen, Leipzig, the regional RSV/Radschnellverbindungen all show up via this. Profile already gives ×1.4 / ×1.2.

---

### `bike_temporal_access` 🤔 maybe
Captures conditional bike access — `bicycle:conditional=yes @ (Mo-Fr 08:00-18:00)`, etc.

**Computed from:** `*:conditional=*` tags evaluated against route-time.

**Why maybe:** Useful for Berlin's Sommer-fußgängerzonen and a handful of timed accesses (Tiergarten Lichtensteinallee, parts of the Mauerpark). Tiny coverage; not worth it until we add time-aware routing.

---

### `mtb_rating` ✅ already in
Integer `0..6`. `0` = no rating; higher = harder mountain-bike trail.

**Computed from:** `mtb:scale=0..6`.

**Why keep:** Upstream `bike.json` zeroes anything `> 2`. Relevant in Grunewald/Spandauer Forst singletrack. Cheap.

---

### `mtb_network` ❌ skip
Mirror of `bike_network` for `route=mtb` relations. Negligible coverage in the Berlin pbf and we already prefer `bike_network`. Skip.

---

### `get_off_bike` ✅ already in
Boolean. `true` if a cyclist would typically have to dismount.

**Computed from:** `bicycle=dismount`, `highway=steps`, `highway=footway` without `bicycle=yes`/`designated`, etc.

**Why add:** Cleaner than checking individual conditions in the custom model — one `multiply_by: 0.1` rule covers all dismount cases. Slightly redundant with `bike_road_access == DISMOUNT`, but covers the steps/footway cases that aren't tagged `bicycle=dismount`.

---

## Road structure

### `road_class` ✅ already in
Enum: `OTHER, MOTORWAY, TRUNK, PRIMARY, SECONDARY, TERTIARY, RESIDENTIAL, UNCLASSIFIED, SERVICE, ROAD, TRACK, FOOTWAY, PEDESTRIAN, LIVING_STREET, BRIDLEWAY, STEPS, CYCLEWAY, PATH, CONSTRUCTION, PLATFORM, CORRIDOR, BUSWAY`.

**Computed from:** `highway=*`.

**Why keep:** Foundation for any future per-class shaping (e.g. boost `LIVING_STREET`, `CYCLEWAY`, penalise `PRIMARY`/`SECONDARY` not on a network).

---

### `road_class_link` 🤔 maybe
Boolean. `true` for `*_link` highway types (motorway_link, primary_link, etc.).

**Why maybe:** Useless on bikes — we don't ride motorway links. Skip.

---

### `road_environment` ✅ already in
Enum: `OTHER, ROAD, FERRY, TUNNEL, BRIDGE, FORD`.

**Computed from:** `tunnel=*`, `bridge=*`, `route=ferry`, `ford=*`.

**Why keep:** Profile penalises ferries; useful for snap_preventions and for fording avoidance. Cheap.

---

### `road_access` ✅ already in
Enum: `YES, DESTINATION, DELIVERY, CUSTOMERS, AGRICULTURAL, FORESTRY, PRIVATE, MILITARY, NO`.

**Computed from:** `access=*` (general, vehicle-agnostic).

**Why add:** Complements `bike_road_access` — picks up restrictions that affect all vehicles (gated forestry tracks in the Grunewald, military areas). Sometimes the cheaper signal when bike-specific tagging is missing. Small graph cost.

---

### `surface` ✅ already in
Enum: `MISSING, OTHER, PAVED, ASPHALT, CONCRETE, PAVING_STONES, COBBLESTONE, UNPAVED, COMPACTED, FINE_GRAVEL, GRAVEL, GROUND, DIRT, GRASS, SAND, WOOD`.

**Computed from:** `surface=*`. Berlin-specific note: `cobblestone` (rounded historic Kopfsteinpflaster) is much rougher than `paving_stones` (modern brick) — both common, both worth penalising at different strengths.

**Why add:** Highest-impact addition for a Berlin profile. Side streets in Mitte/Prenzlauer Berg are full of `sett` and `cobblestone` (note: GH folds `sett` into… see caveat below). Cyclists strongly prefer asphalt detours.

**Caveat:** GraphHopper does *not* expose `sett` as a separate enum value — it's mapped to `OTHER`. To penalise `sett` specifically, we'd need to also encode `paving_stones` separately and accept the loss of granularity, or write a custom parser. For a first pass, treating `COBBLESTONE` and `PAVING_STONES` as "rough" is enough.

---

### `smoothness` ✅ already in
Enum: `MISSING, OTHER, EXCELLENT, GOOD, INTERMEDIATE, BAD, VERY_BAD, HORRIBLE, VERY_HORRIBLE, IMPASSABLE`.

**Computed from:** `smoothness=*`.

**Why add:** Sparse but high-signal in Berlin park paths. Where present, a cyclist would much rather take an `INTERMEDIATE`-rated road than the parallel `BAD` one. Pair with `surface`.

---

### `track_type` 🤔 maybe
Enum: `MISSING, GRADE1, GRADE2, GRADE3, GRADE4, GRADE5`. Firmness of `highway=track`.

**Computed from:** `tracktype=grade1..grade5`.

**Why maybe:** Berlin city core has very few `highway=track`s. Useful around Grunewald/Müggelsee for casual riding, not worth the encoded-value slot until we add a "gravel" profile.

---

### `cycleway` ✅ already in
Enum: `MISSING, OTHER, NO, LANE, TRACK, SHARED_LANE, SHOULDER, SEPARATE`.

**Computed from:** `cycleway=*` and side-specific `cycleway:left|right=*` collapsed to a single per-edge value.

**Why add:** Lets the profile prefer `LANE`/`TRACK` over `MISSING`. Particularly relevant for the many Berlin arterials where the cycleway is *part of* the road geometry (so `road_class != CYCLEWAY` even though there is a marked lane).

**Caveat:** GH collapses left+right into one enum — biased toward whichever side it picks first. Acceptable for shaping; not for navigation instructions.

---

### `footway` ❌ skip
Enum: `MISSING, SIDEWALK, CROSSING, ACCESS_AISLE, TRAFFIC_ISLAND, ALLEY, LINK`. Sub-category of `highway=footway`.

**Why skip:** We're filtering footways via `bike_access`/`get_off_bike`. Per-sub-type shaping doesn't justify a graph-byte slot.

---

### `sidewalk` ❌ skip
Enum: `MISSING, NO, YES, SEPARATE`. Whether a sidewalk runs alongside a road. Used in the foot profile.

**Why skip:** Pedestrian concern, not bike.

---

### `crossing` ✅ already in
Enum: `MISSING, NO, UNCONTROLLED, MARKED, UNMARKED, TRAFFIC_SIGNALS, RAILWAY, RAILWAY_BARRIER`.

**Computed from:** `crossing=*` on `highway=crossing` nodes, propagated to adjacent edges.

**Why keep:** Included to enable a future "prefer controlled crossings on big roads" rule. Visible in the debug overlay today.

---

### `roundabout` ✅ already in
Boolean. `true` if the edge is part of a `junction=roundabout` or `junction=circular`.

**Why keep:** `bike.json` uses it to forbid wrong-way entry on roundabouts. Tiny cost.

---

### `lanes` ❌ skip
Integer count of lanes from `lanes=*`. Useful for cars, mostly redundant for bikes (we already have `road_class` and `max_speed`). Skip.

---

### `lit` 🤔 maybe
Boolean. `true` if the way is lit (`lit=yes`).

**Computed from:** `lit=*`.

**Why maybe:** Worth adding the day we expose a "prefer lit at night" toggle. Coverage in Berlin parks is patchy — Tiergarten paths are well tagged, side streets often `lit=missing`. Defer.

---

## Speed and slope

### `max_speed` ✅ already in
Decimal (km/h). The legal speed limit on the edge in the forward direction (`max_speed_reverse` exists separately). For German edges with no `maxspeed` tag, GraphHopper falls back to legal defaults via the `country` value.

**Computed from:** `maxspeed=*`, then fallbacks per `country` × `road_class` × `urban_density` (`legal_default_speeds.json`).

**Why keep:** Strong proxy for "scary to ride" — `max_speed >= 50 km/h` without a separate cycleway is the classic Berlin Hauptverkehrsstraße. Profile rule waiting to be written.

---

### `country` ✅ already in
Enum (3-letter ISO codes, e.g. `DEU`, `POL`).

**Why keep:** Required at import time for legal default speed lookup, and for any country-specific custom rule (we won't need many in a Berlin-only deployment, but it's cheap).

---

### `urban_density` ❌ skip
Enum: `RURAL, RESIDENTIAL, CITY`. Computed by GraphHopper post-import based on the density of the surrounding road network.

**Computed from:** local way density via a sliding window — no OSM tag involved.

**Why skip:** Berlin coverage is too coarse to be useful — the sliding-window heuristic flags virtually the entire ring-bahn area as `CITY`, leaving `RESIDENTIAL` only for a thin outer fringe. Not worth the encoded-value slot or the extra import time. GraphHopper still computes urban density internally for the `legal_default_speeds.json` `max_speed` fallback.

---

### `average_slope` ✅ already in
Decimal (%). Average gradient of the edge from elevation samples.

**Computed from:** SRTM elevation data sampled along the way geometry.

**Why keep:** Used by `bike_elevation.json` to drop speed on climbs and bump it on descents. Berlin is ~flat, so it rarely fires, but cheap to keep.

---

### `max_slope` 🤔 maybe
Decimal (%). Steepest section of the edge.

**Why maybe:** More precise than `average_slope` for bridges/ramps (Warschauer/Oberbaum, etc.). Marginal in Berlin. Defer.

---

### `curvature` ❌ skip
Decimal `[0, 1]`. Edge-length-divided-by-straight-line ratio.

**Why skip:** Used for motorcycle "fun routing". Not relevant.

---

### `ferry_speed` ✅ already in
Decimal (km/h). Speed at which to traverse a ferry edge.

**Why keep:** `bike.json` references it. Cheap. (Almost no ferries inside the Berlin extract — Müggelsee, BVG-FähreF10–F23 — but still relevant.)

---

## Vehicle restrictions (mostly N/A)

### `max_height`, `max_width`, `max_length`, `max_weight`, `max_axle_load` ❌ skip
All physical restrictions for trucks/buses. Bikes don't care.

### `hgv` ❌ skip
Heavy goods vehicle access. N/A.

### `toll` ❌ skip
Enum: `MISSING, NO, ALL, HGV`. Tolls almost never apply to bikes.

### `hazmat`, `hazmat_tunnel`, `hazmat_water` ❌ skip
Hazardous-material restrictions. N/A.

### `bus_access`, `hov_access` ❌ skip
Bus/HOV-lane access. N/A.

### `car_temporal_access`, `foot_temporal_access` ❌ skip
We don't run those profiles.

### `foot_*`, `horse_*`, `mtb_network` ❌ skip
Other modes' values. We deleted the foot profile.

### `orientation` ❌ skip
Edge bearing. Only useful with `turn_costs` on profiles like `bike_tc`. Defer until we want turn-cost routing.

---

## Identifiers / debug

### `osm_way_id` 🤔 maybe
Long. The original OSM way ID. Useful for "show me the OSM tag for this edge" debugging via `?details=osm_way_id` in the response.

**Why maybe:** Pure dev convenience. Adds 8 bytes per edge.

---

## Custom-model rule ideas (next steps)

With the values above in the graph, the following rules can be added to
[graphhopper_profile.json](graphhopper_profile.json) without another reimport:

- penalise `cycleway == MISSING && max_speed >= 50` on `urban_density == CITY` arterials,
- soft-block `surface ∈ {COBBLESTONE, GRAVEL, SAND, GROUND}`,
- prefer `cycleway ∈ {LANE, TRACK, SEPARATE}` regardless of `road_class`,
- hard-down-weight `get_off_bike == true` instead of relying on `bike_priority`'s opaque verdict,
- penalise `crossing == NO || crossing == UNMARKED` on big roads.

Validate visually first via the debug overlay (Preferences → "Debug: encoded
value overlay" dropdown) before promoting rules into the profile.

Sources: enum members extracted directly from `graphhopper-web-12.0-SNAPSHOT.jar` (`com/graphhopper/routing/ev/*.class`); semantics cross-referenced with [GraphHopper road attributes docs](https://docs.graphhopper.com/openapi/custom-model/road-attributes), the upstream `com/graphhopper/custom_models/bike.json`, and OSM wiki ([Key:cycleway](https://wiki.openstreetmap.org/wiki/Key:cycleway), [Key:smoothness](https://wiki.openstreetmap.org/wiki/Key:smoothness), [Key:surface](https://wiki.openstreetmap.org/wiki/Key:surface), [DE:Key:tracktype](https://wiki.openstreetmap.org/wiki/DE:Key:tracktype)).
