/// <reference types="vitest" />
import { defineConfig, loadEnv } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const fathomUrl = env.VITE_FATHOM_URL;
  const devPort = Number(process.env.VITE_DEV_PORT || env.VITE_DEV_PORT || 5173);

  return {
  plugins: [
    svelte(),
    fathomUrl && {
      name: 'inject-fathom',
      transformIndexHtml: () => [
        // Pre-init: window.fathom as a queuing function so calls before
        // tracker.js loads are buffered and replayed once it runs.
        {
          tag: 'script',
          children: "window.fathom=window.fathom||function(){(window.fathom.q=window.fathom.q||[]).push(arguments)};fathom('trackPageview');",
          injectTo: 'head-prepend',
        },
        // id="fathom-script" is required: tracker.js uses it to auto-discover
        // the /collect endpoint URL. async (not defer) matches the IIFE pattern.
        {
          tag: 'script',
          attrs: { src: fathomUrl, id: 'fathom-script', async: true },
          injectTo: 'head',
        },
      ],
    },
  ].filter(Boolean),
  server: {
    port: devPort,
    proxy: {
      '/api': process.env.VITE_API_PROXY_TARGET || 'http://localhost:3000',
      '/tiles': {
        target: process.env.VITE_TILES_PROXY_TARGET || process.env.VITE_TILE_PROXY_TARGET || 'http://localhost:8080',
        rewrite: (path) => path.replace(/^\/tiles/, ''),
      },
    },
  },
  test: {
    environment: 'happy-dom',
    globals: false,
    setupFiles: ['./vitest.setup.js'],
    include: ['src/**/*.{test,spec}.{js,svelte.js}'],
    exclude: ['node_modules', 'dist', 'tests/e2e/**'],
    clearMocks: true,
  },
  };
});
