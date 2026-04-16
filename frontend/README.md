# beebeebike frontend

Svelte 5 and Vite app for the beebeebike map UI.

## Development

From this directory:

```sh
npm ci
npm run dev
```

The dev server runs on `http://localhost:5173` and proxies API requests to the backend.

## Build

```sh
npm run build
```

The production build is written to `dist/` and served by the Rust backend container.

## Source layout

- `src/components/` - Svelte UI components.
- `src/lib/` - API clients, map helpers, and Svelte state modules.
- `public/` - Static assets served at the site root.
