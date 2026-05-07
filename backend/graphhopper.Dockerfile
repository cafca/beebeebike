# syntax=docker/dockerfile:1.7
#
# Thin layer over upstream GraphHopper that bakes in our routing rules.
# Built and pushed by .github/workflows/cd.yml so prod doesn't depend on
# host-side custom_models files.

FROM israelhikingmap/graphhopper:latest
COPY backend/custom_models/ /custom_models/
