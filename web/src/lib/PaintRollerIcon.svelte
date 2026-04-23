<script>
  let { size = 24, class: className = '' } = $props();
</script>

<svg
  xmlns="http://www.w3.org/2000/svg"
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  class={className}
  aria-hidden="true"
>
  <!-- Roller head: yellow accent with ink outline -->
  <rect
    x="3"
    y="4"
    width="14"
    height="5"
    rx="1.2"
    fill="var(--accent-yellow)"
    stroke="var(--ink)"
    stroke-width="1.6"
    stroke-linejoin="round"
  />
  <!-- Frame arm from roller to handle top -->
  <path
    d="M17 6.5 H19.5 V11 H12"
    stroke="var(--ink)"
    stroke-width="1.6"
    stroke-linecap="round"
    stroke-linejoin="round"
  />
  <!-- Handle -->
  <path
    d="M12 11 V20"
    stroke="var(--ink)"
    stroke-width="1.6"
    stroke-linecap="round"
  />
</svg>
