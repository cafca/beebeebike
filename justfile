set shell := ["bash", "-uc"]

IOS_DEVICE_API := env_var_or_default('BEEBEEBIKE_API_BASE_URL', 'https://beebeebike.com')
IOS_DEVICE_TILES := env_var_or_default('BEEBEEBIKE_TILE_SERVER_BASE_URL', 'https://beebeebike.com/tiles')

# Default: list all recipes grouped
default:
    @just --list

# ---------- setup ----------

[group('setup')]
setup: setup-data setup-web setup-mobile

[group('setup')]
setup-data:
    ./scripts/download_berlin_osm.sh
    ./scripts/download_berlin_tiles.sh

[group('setup')]
setup-web:
    cd web && npm ci

[group('setup')]
setup-mobile:
    cd packages/ferrostar_flutter && flutter pub get
    cd mobile && flutter pub get
