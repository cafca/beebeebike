<script>
  import {
    preferences,
    formatDistanceInfluence,
    formatRatingWeight,
    setDistanceInfluence,
    setRatingWeight,
  } from '../lib/preferences.svelte.js';
  import { computeRoute, route } from '../lib/routing.svelte.js';
  import {
    ENCODED_VALUES,
    debugState,
    setEncodedValue,
    toggleMember,
    setAllMembersVisible,
    setAllMembersHidden,
    setHideFootways,
  } from '../lib/debugOverlay.svelte.js';

  let recomputeTimer;

  const sortedEncodedValues = [...ENCODED_VALUES].sort((a, b) => a.key.localeCompare(b.key));

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

  <div class="debug-section">
    <div class="preference-row">
      <div class="preference-copy">
        <label for="debug-ev">Debug: encoded value overlay</label>
        <p>Internal tool. Visualises a GraphHopper edge attribute on the map.</p>
      </div>
    </div>
    <select
      id="debug-ev"
      value={debugState.selectedKey ?? ''}
      onchange={(e) => setEncodedValue(e.currentTarget.value || null)}
    >
      <option value="">Off</option>
      {#each sortedEncodedValues as ev (ev.key)}
        <option value={ev.key}>{ev.key}</option>
      {/each}
    </select>

    {#if debugState.selected}
      {@const ev = debugState.selected}
      <div class="legend">
        {#if ev.kind === 'enum'}
          <div class="legend-actions">
            <button type="button" onclick={setAllMembersVisible}>All</button>
            <button type="button" onclick={setAllMembersHidden}>None</button>
          </div>
          {#each ev.members as m (m.value)}
            {@const hidden = debugState.hidden.includes(m.value)}
            <label class="legend-row legend-row-toggle" class:dimmed={hidden}>
              <input
                type="checkbox"
                checked={!hidden}
                onchange={() => toggleMember(m.value)}
              />
              <span class="swatch" style="background: {m.color}"></span>
              <span class="legend-label">{m.label}</span>
            </label>
          {/each}
        {:else if ev.kind === 'boolean'}
          <div class="legend-row">
            <span class="swatch" style="background: {ev.trueColor}"></span>
            <span class="legend-label">true</span>
          </div>
          <div class="legend-row">
            <span class="swatch" style="background: {ev.falseColor}"></span>
            <span class="legend-label">false</span>
          </div>
        {:else if ev.kind === 'number'}
          <div
            class="legend-gradient"
            style="background: linear-gradient(to right, {ev.stops.map(([, c]) => c).join(', ')})"
          ></div>
          <div class="legend-axis">
            {#each ev.stops as [v] (v)}
              <span class="legend-tick">{v}</span>
            {/each}
          </div>
        {/if}
        {#if ev.note}
          <p class="legend-note">{@html ev.note}</p>
        {/if}
        <label class="legend-row legend-row-toggle global-toggle">
          <input
            type="checkbox"
            checked={debugState.hideFootways}
            onchange={(e) => setHideFootways(e.currentTarget.checked)}
          />
          <span class="legend-label">Hide <code>road_class=footway</code></span>
        </label>
      </div>
    {/if}
  </div>

  <div class="credits">
    <p>Legal</p>
    <div class="credit-links">
      <a href="/impressum/" target="_blank" rel="noreferrer">Impressum</a>
      <a href="/datenschutz/" target="_blank" rel="noreferrer">Datenschutz</a>
    </div>
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
    border-top: 1px solid var(--divider);
    color: var(--ink);
    font-family: var(--font-sans);
  }
  .preference-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 10px;
    font: 500 14px/1.3 var(--font-sans);
  }
  .preference-copy {
    min-width: 0;
    flex: 1;
  }
  .preference-copy label {
    display: block;
    margin: 0;
    font: 600 14px/1.3 var(--font-sans);
    color: var(--ink);
  }
  .preference-copy p {
    margin: 4px 0 0;
    color: var(--ink-muted);
    font: 500 12px/1.35 var(--font-sans);
  }
  .preference-row-spaced {
    margin-top: 16px;
  }
  .preference-row span {
    min-width: 52px;
    text-align: right;
    font: 600 12px/1.2 var(--font-mono);
    color: var(--ink-muted);
    padding-top: 1px;
  }
  input[type='range'] {
    width: 100%;
    accent-color: var(--brand);
  }
  .scale-labels {
    display: flex;
    justify-content: space-between;
    margin-top: 4px;
    color: var(--ink-faint);
    font: 500 12px/1.3 var(--font-sans);
  }
  .debug-section {
    margin-top: 18px;
    padding-top: 12px;
    border-top: 1px dashed var(--divider);
  }
  .debug-section select {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid var(--divider);
    border-radius: var(--radius-ctrl, 6px);
    font: 500 13px/1.3 var(--font-mono);
    background: var(--panel);
    color: var(--ink);
  }
  .legend {
    margin-top: 10px;
    display: flex;
    flex-direction: column;
    gap: 4px;
    font: 500 12px/1.3 var(--font-mono);
    color: var(--ink-muted);
  }
  .legend-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .legend-row-toggle {
    cursor: pointer;
    user-select: none;
  }
  .legend-row-toggle input[type='checkbox'] {
    margin: 0;
    accent-color: var(--brand);
  }
  .legend-row-toggle.dimmed .swatch,
  .legend-row-toggle.dimmed .legend-label {
    opacity: 0.4;
  }
  .legend-actions {
    display: flex;
    gap: 6px;
    margin-bottom: 4px;
  }
  .legend-actions button {
    padding: 2px 8px;
    border: 1px solid var(--divider);
    border-radius: var(--radius-ctrl, 6px);
    background: var(--panel);
    color: var(--ink);
    font: 500 11px/1.3 var(--font-sans);
    cursor: pointer;
  }
  .legend-actions button:hover {
    background: var(--divider);
  }
  .global-toggle {
    margin-top: 10px;
    padding-top: 8px;
    border-top: 1px dashed var(--divider);
  }
  .global-toggle code {
    font-family: var(--font-mono);
    font-size: 11px;
  }
  .swatch {
    display: inline-block;
    width: 14px;
    height: 14px;
    border: 1px solid var(--divider);
    border-radius: 2px;
    flex-shrink: 0;
  }
  .legend-label {
    font-family: var(--font-mono);
  }
  .legend-gradient {
    height: 12px;
    border-radius: 2px;
    border: 1px solid var(--divider);
  }
  .legend-axis {
    display: flex;
    justify-content: space-between;
    color: var(--ink-faint);
  }
  .legend-note {
    margin: 8px 0 0;
    color: var(--ink-muted);
    font: 400 12px/1.55 var(--font-sans);
  }
  .legend-note :global(strong) { font-weight: 600; }
  .legend-note :global(code) {
    font-family: var(--font-mono);
    font-size: 11px;
    background: var(--divider);
    padding: 1px 3px;
    border-radius: 3px;
  }
  .credits {
    margin-top: 18px;
    padding-top: 12px;
    border-top: 1px solid var(--divider);
  }
  .credits p {
    margin: 0 0 8px;
    color: var(--ink-muted);
    font: 500 12px/1.35 var(--font-sans);
  }
  .credit-links {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 12px;
  }
  .credit-links a {
    color: var(--brand);
    font: 500 12px/1.35 var(--font-sans);
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
