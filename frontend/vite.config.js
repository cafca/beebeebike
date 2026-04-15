import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  server: {
    port: 5173,
    proxy: {
      '/api': process.env.VITE_API_PROXY_TARGET || 'http://localhost:3000',
      '/tiles': {
        target: process.env.VITE_TILES_PROXY_TARGET || 'http://localhost:8080',
        rewrite: (path) => path.replace(/^\/tiles/, ''),
      },
    },
  },
});
