# Docker

This document describes how to build and run FaunaDB using the provided Dockerfile. The image is self-contained: it builds the FaunaDB tarball inside the image (same layout as `mktarball.sh` / `scripts/run-local.sh`) and runs a single-node cluster with configurable `auth_root_key`.

## Overview

- **Multi-stage build:** Stage 1 compiles the JAR with sbt and stages `bin/` and `lib/`; stage 2 is a slim runtime with Eclipse Temurin 17 JRE and the tarball.
- **Entrypoint:** `scripts/docker-entrypoint.sh` generates `faunadb.yml` at startup (so you can set `auth_root_key` via env), runs a one-time `faunadb-admin init -r replica_1`, then starts the server in the foreground.
- **Ports:** 8443 (API), 8444 (admin). The server binds to `0.0.0.0` inside the container so it is reachable from the host.

## Building

From the repository root:

```bash
docker build -t faunadb .
```

The first build can take a while while sbt resolves dependencies and compiles the project. The build context is trimmed by `.dockerignore` (e.g. `target/`, `.git`, logs) to keep context small.

## Running

### Basic run (default root key)

```bash
docker run -p 8443:8443 -p 8444:8444 faunadb
```

Uses the default `auth_root_key: secret`. After the first start, the cluster is initialized and the API is available on port 8443.

### Custom root key

Set `AUTH_ROOT_KEY` to override the root key:

```bash
docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret faunadb
```

Use this key when connecting clients to the API (e.g. as the Fauna secret).

### Persistent data

To keep data across container restarts, mount a volume at `/opt/fauna/data`:

```bash
docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret \
  -v faunadb-data:/opt/fauna/data \
  faunadb
```

Logs are under `/opt/fauna/log`; you can mount that too if you want to persist logs:

```bash
docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret \
  -v faunadb-data:/opt/fauna/data \
  -v faunadb-log:/opt/fauna/log \
  faunadb
```

### Health checks

- **API (after init):** `curl http://localhost:8443/ping`
- **Admin:** `curl http://localhost:8444/ping`

## Environment variables

| Variable        | Default    | Description                                      |
|----------------|------------|--------------------------------------------------|
| `AUTH_ROOT_KEY`| `secret`   | Root key used in `faunadb.yml` (auth_root_key).  |
| `FAUNA_DIR`    | `/opt/fauna` | Install directory; data and log paths are under it. |

Config is generated at container startup; changing `AUTH_ROOT_KEY` or `FAUNA_DIR` takes effect on the next run.

## Ports

| Port | Purpose |
|------|--------|
| 8443 | API (FQL, ping, etc.) |
| 8444 | Admin HTTP (e.g. ping, admin tools) |

## Entrypoint behavior

1. **Create dirs:** `$FAUNA_DIR/data`, `$FAUNA_DIR/log`.
2. **Write config:** `$FAUNA_DIR/faunadb.yml` with `auth_root_key` from `AUTH_ROOT_KEY`, paths, and `network_*` set to `0.0.0.0`.
3. **One-time init:** If `$FAUNA_DIR/data/.docker-initialized` does not exist, run `./bin/faunadb-admin init -r replica_1` and create the marker. Subsequent starts skip init.
4. **Start server:** `exec ./bin/faunadb -c faunadb.yml` (foreground).

## Files involved

- **`Dockerfile`** — Multi-stage build and runtime image definition.
- **`scripts/docker-entrypoint.sh`** — Startup script (config generation, init, run).
- **`.dockerignore`** — Reduces build context (targets, git, logs, etc.).

## Production and clustering

This image is intended for local or single-node use with a simple root key. For production, multi-node clusters, and stronger security (e.g. `auth_root_key_hash`), see [OPERATING.md](OPERATING.md).
