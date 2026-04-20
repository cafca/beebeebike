# Deployment

Production runs on a single host (`vars.DEPLOY_HOST`) via `docker compose -f compose.prod.yml`. Images come from GHCR; runtime config is synced from CI on every push to `main`.

## Flow

1. Push to `main` → `.github/workflows/ci.yml` runs.
2. `publish` job builds `ghcr.io/cafca/beebeebike:latest` + `:<sha>` from `backend/Dockerfile`.
3. `deploy` job:
   - `scp`s the files listed below into `~/beebeebike/` on the server.
   - `ssh`es in and runs `docker compose -f compose.prod.yml pull backend && up -d backend`.

The server does **not** `git pull`. Only the files CI scps are authoritative.

## Server layout

`~/beebeebike/` on the prod host should contain exactly:

```
compose.prod.yml                     # synced by CI
backend/graphhopper_config.yml       # synced by CI
data/osm/berlin/berlin.osm.pbf       # local, via scripts/download_berlin_osm.sh
data/osm/berlin/graphhopper/         # runtime cache, built by graphhopper on first run
data/tiles/berlin.versatiles         # local, via scripts/download_berlin_tiles.sh
```

Anything else (`backend/` source, `web/`, `mobile/`, `.github/`, old `compose.yml`, `Dockerfile`, etc.) is stale and should be deleted — it is never read by prod and only creates drift between what's on disk and what the image actually runs.

Rule of thumb: if `compose.prod.yml` does not reference a path, it has no business being on the server.

## First-time provisioning

```bash
ssh <user>@<host>
mkdir -p ~/beebeebike/data/osm/berlin ~/beebeebike/data/tiles
# Place OSM extract + versatiles file (see scripts/download_berlin_*.sh)
```

Then push to `main` — CI will sync compose + graphhopper config and start the stack.

## Editing prod config

Don't SSH in and edit `compose.prod.yml` or `backend/graphhopper_config.yml` on the server — the next deploy overwrites your change. Edit in the repo, merge to `main`, let CI ship it.

## Secrets / vars

Repo-level GitHub settings:

- `vars.DEPLOY_HOST` — SSH host. Deploy job is skipped if unset.
- `vars.DEPLOY_USER` — SSH user.
- `secrets.DEPLOY_SSH_KEY` — private key authorized on the host.
- `vars.VITE_FATHOM_URL` — baked into the web bundle at image-build time.
