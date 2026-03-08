#!/usr/bin/env bash
# Docker entrypoint: generate config with AUTH_ROOT_KEY, run one-time init, then start FaunaDB (foreground).
# Usage: set AUTH_ROOT_KEY (default: secret); optionally FAUNADB_CONFIG_PATH, data/log paths via env.

set -euo pipefail

FAUNA_DIR="${FAUNA_DIR:-/opt/fauna}"
DATA_DIR="${FAUNA_DIR}/data"
LOG_DIR="${FAUNA_DIR}/log"
CONFIG_PATH="${FAUNA_DIR}/faunadb.yml"
INIT_MARKER="${DATA_DIR}/.docker-initialized"
AUTH_ROOT_KEY="${AUTH_ROOT_KEY:-secret}"

mkdir -p "$DATA_DIR" "$LOG_DIR"
cd "$FAUNA_DIR"

# Generate faunadb.yml so we can set auth_root_key from env (and bind to 0.0.0.0 in Docker)
cat > "$CONFIG_PATH" << EOF
storage_data_path: ${DATA_DIR}
log_path: ${LOG_DIR}

cluster_name: local_cluster
auth_root_key: ${AUTH_ROOT_KEY}

network_listen_address: 0.0.0.0
network_broadcast_address: 0.0.0.0
network_admin_http_address: 0.0.0.0
network_coordinator_http_address: 0.0.0.0

flags_path: ${FAUNA_DIR}/feature-flags.json
EOF
touch "${FAUNA_DIR}/feature-flags.json" 2>/dev/null || true

# One-time init (idempotent)
if [ ! -f "$INIT_MARKER" ]; then
  echo "==> First run: initializing cluster replica_1..."
  ./bin/faunadb-admin init -r replica_1
  touch "$INIT_MARKER"
fi

echo "==> Starting FaunaDB (auth_root_key from AUTH_ROOT_KEY)"
exec ./bin/faunadb -c "$CONFIG_PATH"
