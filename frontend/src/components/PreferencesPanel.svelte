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
    recomputeTimer = window.setTimeout(() => computeRoute(), 220);
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
  <h2>Options</h2>

  <div class="preference-row">
    <label for="rating-weight">Preference strength</label>
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
    <span>Off</span>
    <span>Full</span>
  </div>

  <div class="preference-row preference-row-spaced">
    <label for="distance-influence">Distance influence</label>
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
</section>

<style>
  .preferences-panel {
    margin-top: 8px;
    padding-top: 10px;
    border-top: 1px solid #e5e7eb;
    color: #111827;
  }
  h2 {
    margin: 0 0 10px;
    font-size: 13px;
    font-weight: 650;
    line-height: 1.2;
  }
  .preference-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 10px;
    font-size: 14px;
  }
  .preference-row-spaced {
    margin-top: 16px;
  }
  .preference-row span {
    min-width: 44px;
    text-align: right;
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
  @media (max-width: 640px) {
    .preference-row { font-size: 14px; }
  }
</style>
