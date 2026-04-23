<script>
  let { onclose = () => {} } = $props();
</script>

<div class="overlay">
  <div class="modal">
    <video
      class="route-preview"
      autoplay
      loop
      muted
      playsinline
      preload="auto"
      disablepictureinpicture
      disableremoteplayback
      aria-label="Intro video showing how to paint map areas and plan a route in BeeBeeBike"
    >
      <source src="/assets/welcome-intro.mp4" type="video/mp4" />
    </video>
    <h2>Welcome to BeeBeeBike</h2>
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
    <p class="muted">Your rated areas and any saved places are stored and processed on BeeBeeBike servers only. Address searches are sent context-free to Komoot's hosted Photon service. Message beebeebike@vincentahrend.com to request data removal.</p>
    <button onclick={onclose}>Start exploring</button>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(20, 40, 50, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }
  .modal {
    background: var(--panel);
    padding: 24px;
    border-radius: var(--radius-panel);
    max-width: min(520px, calc(100vw - 32px));
    max-height: calc(100vh - 32px);
    overflow: auto;
    box-shadow: var(--shadow-panel);
    color: var(--ink);
    font-family: var(--font-sans);
  }
  .route-preview {
    display: block;
    width: 100%;
    aspect-ratio: 5 / 3;
    object-fit: cover;
    border-radius: var(--radius-ctrl);
    margin: 0 0 20px;
  }
  h2 {
    margin: 0 0 12px;
    font: 700 20px/1.2 var(--font-sans);
    color: var(--ink);
  }
  p {
    margin: 0 0 16px;
    font: 500 15px/1.5 var(--font-sans);
    color: var(--ink-muted);
  }
  ol {
    margin: 0 0 24px;
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  li {
    font: 500 14px/1.4 var(--font-sans);
    color: var(--ink-muted);
  }
  button {
    width: 100%;
    padding: 12px 14px;
    background: var(--ink);
    color: var(--panel);
    border: none;
    border-radius: var(--radius-ctrl);
    cursor: pointer;
    font: 700 15px/1.3 var(--font-sans);
  }
  button:hover { opacity: 0.92; }
  .muted {
    color: var(--ink-faint);
    font: 500 12px/1.4 var(--font-sans);
  }

  @media (max-width: 640px) {
    .overlay { align-items: flex-end; }
    .modal {
      width: 100%;
      max-width: 100%;
      border-radius: var(--radius-sheet-top) var(--radius-sheet-top) 0 0;
      padding: 24px 20px 32px;
      max-height: calc(100vh - 24px);
    }
  }
</style>
