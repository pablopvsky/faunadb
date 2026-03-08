#!/usr/bin/env bash
# Docker entrypoint: create faunadb.yml (as in OPERATING.md — release tarball does not include it),
# set auth_root_key from AUTH_ROOT_KEY, run one-time init, then start FaunaDB (foreground).
# Usage: set AUTH_ROOT_KEY (default: secret); optionally FAUNA_DIR.

set -euo pipefail

FAUNA_DIR="${FAUNA_DIR:-/opt/fauna}"
DATA_DIR="${FAUNA_DIR}/data"
LOG_DIR="${FAUNA_DIR}/log"
CONFIG_PATH="${FAUNA_DIR}/faunadb.yml"
INIT_MARKER="${DATA_DIR}/.docker-initialized"
AUTH_ROOT_KEY="${AUTH_ROOT_KEY:-secret}"

mkdir -p "$DATA_DIR" "$LOG_DIR"
cd "$FAUNA_DIR"

# OPERATING.md: "Configure the first node" — create faunadb.yml (not included in release tarball).
# We generate it at startup so AUTH_ROOT_KEY can be set via env; network_* set to 0.0.0.0 for Docker.
cat > "$CONFIG_PATH" << EOF
auth_root_key: ${AUTH_ROOT_KEY}
cluster_name: local_cluster
storage_data_path: ${DATA_DIR}
log_path: ${LOG_DIR}

network_listen_address: 0.0.0.0
network_broadcast_address: 0.0.0.0
network_admin_http_address: 0.0.0.0
network_coordinator_http_address: 0.0.0.0

flags_path: ${FAUNA_DIR}/feature-flags.json
EOF
touch "${FAUNA_DIR}/feature-flags.json" 2>/dev/null || true

# Container-friendly JVM memory (script defaults use half of /proc/meminfo, which can OOM-kill in Docker)
export MAX_HEAP_SIZE="${MAX_HEAP_SIZE:-512m}"
export MAX_DIRECT_SIZE="${MAX_DIRECT_SIZE:-256m}"

# Load jamm as Java agent before any Java process (init and server) to avoid "jamm will use sun.misc.Unsafe..." warning
if [ -f "${FAUNA_DIR}/lib/jamm.jar" ]; then
  export JAVA_OPTS="-javaagent:${FAUNA_DIR}/lib/jamm.jar ${JAVA_OPTS:-}"
fi

# One-time init (idempotent); faunadb-admin also benefits from JAVA_OPTS above
if [ ! -f "$INIT_MARKER" ]; then
  echo "==> First run: initializing cluster replica_1..."
  ./bin/faunadb-admin init -r replica_1
  touch "$INIT_MARKER"
fi

echo "==> Starting FaunaDB (auth_root_key from AUTH_ROOT_KEY)"
# Run (no exec) so we can keep container alive for inspection when server exits
env JAVA_OPTS="${JAVA_OPTS:-}" ./bin/faunadb -c "$CONFIG_PATH"
EXIT_CODE=$?
if [ "${FAUNADB_KEEP_ALIVE_ON_EXIT:-0}" = "1" ]; then
  echo "==> FaunaDB exited with code $EXIT_CODE; container kept alive for inspection."
  echo "    Inspect: docker exec -it <container> sh"
  echo "    Logs: $LOG_DIR  Data: $DATA_DIR  Config: $CONFIG_PATH"
  echo "    Stop: docker stop <container>"
  exec sleep infinity
fi
exit "$EXIT_CODE"
