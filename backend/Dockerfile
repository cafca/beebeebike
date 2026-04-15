# syntax=docker/dockerfile:1.7

FROM node:22-bookworm AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY frontend ./
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
    cargo build --release && \
    cp target/release/beebeebike-backend /usr/local/bin/beebeebike-backend

FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=backend-builder /usr/local/bin/beebeebike-backend /usr/local/bin/
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist
ENV STATIC_DIR=/app/frontend/dist
CMD ["beebeebike-backend"]
