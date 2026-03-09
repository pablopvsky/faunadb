#!/bin/bash
# Start Fauna in Docker: auto-init cluster on first run, then run server (OPERATING.md).
set -euo pipefail

cd /opt/fauna
mkdir -p data log flags
# Feature flags file must have "version" and "properties" (see ext/flags FileService)
[ -f flags/feature-flags.json ] || echo '{"version": 0, "properties": []}' > flags/feature-flags.json

# Override auth_root_key from environment if set (escape for sed: \ and &)
if [ -n "${FAUNADB_AUTH_ROOT_KEY:-}" ]; then
  SAFE_KEY=$(printf '%s' "$FAUNADB_AUTH_ROOT_KEY" | sed 's/[\\&]/\\&/g')
  sed -i "s|^auth_root_key:.*|auth_root_key: \"${SAFE_KEY}\"|" faunadb.yml
fi

# Already initialized (marker in data dir so it persists with the volume)
if [ -f data/.initialized ]; then
  exec ./bin/faunadb -c faunadb.yml
fi

# First run: start server, init replica_1, then run server in foreground
echo "First run: initializing cluster (replica_1)..."
./bin/faunadb -c faunadb.yml &
PID=$!
cleanup() { kill $PID 2>/dev/null; wait $PID 2>/dev/null; exit 1; }
trap cleanup INT TERM

ADMIN_PORT=8444
WAIT=0
MAX_WAIT=90
until curl -s -o /dev/null --connect-timeout 2 "http://127.0.0.1:$ADMIN_PORT/" 2>/dev/null; do
  sleep 2
  WAIT=$((WAIT + 2))
  if [ "$WAIT" -ge "$MAX_WAIT" ]; then
    echo "Server did not become ready in ${MAX_WAIT}s." 1>&2
    cleanup
  fi
done
trap - INT TERM

./bin/faunadb-admin --conf faunadb.yml init -r replica_1
touch data/.initialized
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true
# Let the OS release ports before starting the server again
sleep 3

echo "Cluster initialized. Starting Fauna..."
exec ./bin/faunadb -c faunadb.yml
