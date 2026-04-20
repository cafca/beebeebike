<script>
  import {
    preferences,
    formatDistanceInfluence,
    formatRatingWeight,
    setDistanceInfluence,
    setRatingWeight,
  } from '../lib/preferences.svelte.js';
  import { computeRoute, route } from '../lib/routing.svelte.js';

  let recomputeTimer;

  function queueRouteUpdate() {
    if (!route.origin || !route.destination) return;

    window.clearTimeout(recomputeTimer);
    recomputeTimer = window.setTimeout(() => computeRoute({ fitBounds: false }), 220);
  }

  function updateRatingWeight(event) {
    setRatingWeight(event.currentTarget.value);
    queueRouteUpdate();
  }

  function updateDistanceInfluence(event) {
    setDistanceInfluence(event.currentTarget.value);
    queueRouteUpdate();
  }

  $effect(() => {
    return () => window.clearTimeout(recomputeTimer);
  });
</script>

<section class="preferences-panel" aria-label="Preferences">
  <div class="preference-row">
    <div class="preference-copy">
      <label for="rating-weight">Preference strength</label>
      <p>How strongly your painted likes and dislikes should shape the route.</p>
    </div>
    <span>{formatRatingWeight(preferences.ratingWeight)}</span>
  </div>

  <input
    id="rating-weight"
    type="range"
    min="0"
    max="1"
    step="0.05"
    value={preferences.ratingWeight}
    oninput={updateRatingWeight}
  />

  <div class="scale-labels" aria-hidden="true">
    <span>Ignore ratings</span>
    <span>Follow ratings</span>
  </div>

  <div class="preference-row preference-row-spaced">
    <div class="preference-copy">
      <label for="distance-influence">Route directness</label>
      <p>How much shorter trips should win over detours to nicer streets.</p>
    </div>
    <span>{formatDistanceInfluence(preferences.distanceInfluence)}</span>
  </div>

  <input
    id="distance-influence"
    type="range"
    min="0"
    max="100"
    step="5"
    value={preferences.distanceInfluence}
    oninput={updateDistanceInfluence}
  />

  <div class="scale-labels" aria-hidden="true">
    <span>Flexible</span>
    <span>Direct</span>
  </div>

  <div class="credits">
    <p>Built with</p>
    <div class="credit-links">
      <a href="https://www.openstreetmap.org/" target="_blank" rel="noreferrer">OpenStreetMap</a>
      <a href="https://maplibre.org/" target="_blank" rel="noreferrer">MapLibre</a>
      <a href="https://www.graphhopper.com/" target="_blank" rel="noreferrer">GraphHopper</a>
      <a href="https://photon.komoot.io/" target="_blank" rel="noreferrer">Photon service hosted by Komoot</a>
    </div>
  </div>
</section>

<style>
  .preferences-panel {
    margin-top: 8px;
    padding-top: 10px;
    border-top: 1px solid #e5e7eb;
    color: #111827;
  }
  .preference-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 10px;
    font-size: 14px;
  }
  .preference-copy {
    min-width: 0;
    flex: 1;
  }
  .preference-copy label {
    display: block;
    margin: 0;
    font-weight: 600;
    line-height: 1.2;
  }
  .preference-copy p {
    margin: 4px 0 0;
    color: #6b7280;
    font-size: 12px;
    line-height: 1.35;
  }
  .preference-row-spaced {
    margin-top: 16px;
  }
  .preference-row span {
    min-width: 52px;
    text-align: right;
    line-height: 1.2;
    padding-top: 1px;
  }
  input[type='range'] {
    width: 100%;
    accent-color: #059669;
  }
  .scale-labels {
    display: flex;
    justify-content: space-between;
    margin-top: 4px;
    color: #6b7280;
    font-size: 12px;
  }
  .credits {
    margin-top: 18px;
    padding-top: 12px;
    border-top: 1px solid #e5e7eb;
  }
  .credits p {
    margin: 0 0 8px;
    color: #6b7280;
    font-size: 12px;
    line-height: 1.35;
  }
  .credit-links {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 12px;
  }
  .credit-links a {
    color: #2563eb;
    font-size: 12px;
    line-height: 1.35;
    text-decoration: none;
  }
  .credit-links a:hover {
    text-decoration: underline;
  }
  @media (max-width: 640px) {
    .preference-row { font-size: 14px; }
    .preference-copy p { max-width: 28ch; }
  }
</style>
