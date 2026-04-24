# syntax=docker/dockerfile:1.7

FROM node:22-bookworm AS web-builder
WORKDIR /app/web
COPY web/package.json web/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY web ./
ARG VITE_FATHOM_URL
RUN npm run build

FROM rust:1.94-bookworm AS backend-builder
WORKDIR /app/backend
COPY backend/Cargo.toml backend/Cargo.lock* ./
COPY backend/src ./src
COPY backend/migrations ./migrations
ENV SQLX_OFFLINE=true
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/app/backend/target \
    cargo build --release --bin beebeebike-backend --bin undo_bench && \
    cp target/release/beebeebike-backend /usr/local/bin/beebeebike-backend && \
    cp target/release/undo_bench /usr/local/bin/undo_bench

FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=backend-builder /usr/local/bin/beebeebike-backend /usr/local/bin/
COPY --from=backend-builder /usr/local/bin/undo_bench /usr/local/bin/
COPY --from=web-builder /app/web/dist /app/web/dist
ENV STATIC_DIR=/app/web/dist
CMD ["beebeebike-backend"]
