import { defineConfig, loadEnv } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const fathomUrl = env.VITE_FATHOM_URL;

  return {
  plugins: [
    svelte(),
    fathomUrl && {
      name: 'inject-fathom',
      transformIndexHtml: () => [{
        tag: 'script',
        attrs: { src: fathomUrl, defer: true },
        injectTo: 'head',
      }],
    },
  ].filter(Boolean),
  server: {
    port: 5173,
    proxy: {
      '/api': process.env.VITE_API_PROXY_TARGET || 'http://localhost:3000',
      '/tiles': {
        target: process.env.VITE_TILES_PROXY_TARGET || process.env.VITE_TILE_PROXY_TARGET || 'http://localhost:8080',
        rewrite: (path) => path.replace(/^\/tiles/, ''),
      },
    },
  },
  };
});
