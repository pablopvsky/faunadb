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

**Build from source, not the release tarball:** This image is built from the repo (compile in the image). Script fixes and changes in `service/src/main/scripts/` (e.g. optional `JAVA_OPTS`) are included. The published release tarball (e.g. fauna-YYYY-MM.tar.gz) does not include those fixes until a new release is cut.

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

| Variable          | Default     | Description                                      |
|-------------------|-------------|--------------------------------------------------|
| `AUTH_ROOT_KEY`   | `secret`    | Root key used in `faunadb.yml` (auth_root_key).  |
| `FAUNA_DIR`       | `/opt/fauna`| Install directory; data and log paths are under it. |
| `MAX_HEAP_SIZE`   | `512m`      | JVM max heap (container-friendly default; script would use half of host RAM otherwise and can OOM). |
| `MAX_DIRECT_SIZE` | `256m`      | JVM max direct memory. Override with `-e MAX_HEAP_SIZE=1G` etc. if you give the container more memory. |
| `FAUNADB_KEEP_ALIVE_ON_EXIT` | `0` | Set to `1` so that when the server exits, the container stays running so you can inspect logs and data: `docker exec -it <container> sh`. Logs: `/opt/fauna/log`, data: `/opt/fauna/data`, config: `/opt/fauna/faunadb.yml`. |

Config is generated at container startup; changing `AUTH_ROOT_KEY` or `FAUNA_DIR` takes effect on the next run.

## Ports

| Port | Purpose |
|------|--------|
| 8443 | API (FQL, ping, etc.) |
| 8444 | Admin HTTP (e.g. ping, admin tools) |

## Entrypoint behavior

As in [OPERATING.md](OPERATING.md), the release tarball does **not** include `faunadb.yml`; you must add it. The entrypoint does that at container start:

1. **Create dirs:** `$FAUNA_DIR/data`, `$FAUNA_DIR/log`.
2. **Write config:** Create `$FAUNA_DIR/faunadb.yml` (same structure as OPERATING.md “Configure the first node”): `auth_root_key` from `AUTH_ROOT_KEY`, `cluster_name`, `storage_data_path`, `log_path`, and `network_*` set to `0.0.0.0` for Docker.
3. **One-time init:** If `$FAUNA_DIR/data/.docker-initialized` does not exist, run `./bin/faunadb-admin init -r replica_1` and create the marker. Subsequent starts skip init.
4. **Start server:** `exec ./bin/faunadb -c faunadb.yml` (foreground).

## Files involved

- **`Dockerfile`** — Multi-stage build and runtime image definition.
- **`scripts/docker-entrypoint.sh`** — Startup script (config generation, init, run).
- **`.dockerignore`** — Reduces build context (targets, git, logs, etc.).

## Inspecting logs and data when the server exits

You cannot `docker exec` into a **stopped** container. Use one of these approaches.

**Option A — Keep container running after exit (then exec in):**  
Run with `FAUNADB_KEEP_ALIVE_ON_EXIT=1` and a fixed name. When the server exits, the container stays up so you can exec in:

```bash
docker run -p 8443:8443 -p 8444:8444 \
  -e MAX_HEAP_SIZE=1G -e MAX_DIRECT_SIZE=512m \
  -e FAUNADB_KEEP_ALIVE_ON_EXIT=1 \
  --name faunadb-inspect \
  faunadb
# After the server exits, in another terminal:
docker exec -it faunadb-inspect sh
# Inside: cat /opt/fauna/log/core.log  ls /opt/fauna/data  cat /opt/fauna/faunadb.yml
docker stop faunadb-inspect
```

**Option B — Container already stopped:**  
Copy logs and data out using the container ID (from `docker ps -a`):

```bash
# List containers (including stopped); note the CONTAINER ID
docker ps -a

# Copy logs and data to the current directory (replace <container_id> with the ID)
docker cp <container_id>:/opt/fauna/log ./fauna-log
docker cp <container_id>:/opt/fauna/data ./fauna-data
docker cp <container_id>:/opt/fauna/faunadb.yml ./faunadb.yml

# Inspect on the host
cat fauna-log/core.log
ls -la fauna-data
```

**Option C — Use a volume so data survives:**  
Run with a named volume; then even if the container is removed, the volume keeps the data and you can mount it in a new container to inspect:

```bash
docker run -p 8443:8443 -p 8444:8444 \
  -e MAX_HEAP_SIZE=1G -e FAUNADB_KEEP_ALIVE_ON_EXIT=1 \
  -v faunadb-data:/opt/fauna/data \
  -v faunadb-log:/opt/fauna/log \
  --name faunadb-inspect \
  faunadb
# After exit, inspect by mounting the same volumes:
docker run --rm -it -v faunadb-log:/log -v faunadb-data:/data alpine sh
# Inside: cat /log/core.log  ls /data
```

## Notes

- **Jamm warning:** The image loads `service/lib/jamm.jar` as a Java agent so you should not see the "jamm will use sun.misc.Unsafe..." message. If you do (e.g. an older image), the server still runs; the warning is about heap-size estimation and can be ignored for local use.

## Production and clustering

This image is intended for local or single-node use with a simple root key. For production, multi-node clusters, and stronger security (e.g. `auth_root_key_hash`), see [OPERATING.md](OPERATING.md).
