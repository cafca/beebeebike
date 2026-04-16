# beebeebike

beebeebike is a cycling-oriented Berlin routing app. I like thinking about map ux and this is an experiment where I wondered: what if you could just draw on the map where you love and hate to cycle? 

The app uses those personal ratings when calculating routes, so your trips can bend toward your favorite segments and away from the ones you would rather never see again. It is a Svelte frontend, Rust/Axum backend, PostgreSQL/PostGIS database, MapLibre map, and GraphHopper routing stack.

## Quickstart

You will need Docker and Docker Compose. The local stack expects Berlin OSM and tile data under `data/`; the helper scripts in `scripts/` are there to fetch those.

```sh
./scripts/download_berlin_osm.sh
./scripts/download_berlin_tiles.sh
docker compose -f compose.yml -f compose.dev.yml up --build
```

Then open the app at `http://localhost:5173`.

## Repository layout

- `frontend/` - Svelte/Vite map UI.
- `backend/` - Rust/Axum API, migrations, and integration tests.
- `infra/` - Deployment and infrastructure support files, including GraphHopper config and nginx helpers.
- `scripts/` - Local data download helpers.
- `data/` - Local map data and generated routing/tile artifacts used by Docker Compose.

Docker Compose files live at the project root and are meant to be run from there.

## Contributing

Contributions are welcome. Please open an issue first so we can talk through the idea, the shape of the change, and any bike-brain edge cases before you start building.
