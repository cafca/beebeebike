<script>
  let { onclose = () => {} } = $props();
</script>

<div class="overlay">
  <div class="modal">
    <h2>Welcome to BeeByBike</h2>
    <p>
      A bicycle routing app for Berlin that learns your preferences. Paint areas on the map
      to mark roads and neighbourhoods you love or want to avoid, then get custom bike routes
      tailored to how you like to ride.
    </p>
    <ol>
      <li>Use the brush tool to paint areas green (prefer) or red (avoid)</li>
      <li>Enter a start and destination in the search bar or click two points on the map.</li>
      <li>Get a bicycle route tailored to your preferences</li>
    </ol>
    <p><em>Sign up to access your custom map across devices!</em></p> 
    <p class="muted">Your rated areas and any saved places are stored and processed on BeeByBike servers only. Message beebybike@vincentahrend.com to request data removal.</p>
    <button onclick={onclose}>Start exploring</button>
  </div>
</div>

<style>
  .overlay {
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal {
    background: white; padding: 32px; border-radius: 12px; max-width: min(420px, calc(100vw - 32px));
    box-shadow: 0 4px 24px rgba(0,0,0,0.2);
  }
  h2 { margin: 0 0 12px; }
  p { margin: 0 0 16px; font-size: 14px; line-height: 1.5; color: #444; }
  ol { margin: 0 0 24px; padding-left: 20px; display: flex; flex-direction: column; gap: 8px; }
  li { font-size: 14px; line-height: 1.4; color: #444; }
  button {
    width: 100%; padding: 10px; background: #2563eb; color: white; border: none;
    border-radius: 6px; cursor: pointer; font-size: 14px;
  }
  button:hover { background: #1d4ed8; }
  .muted { color: #999; font-size: 12px; }

  @media (max-width: 640px) {
    .overlay { align-items: flex-end; }
    .modal {
      width: 100%;
      max-width: 100%;
      border-radius: 16px 16px 0 0;
      padding: 24px 20px 32px;
    }
  }
</style>
