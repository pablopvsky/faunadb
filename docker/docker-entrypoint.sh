#!/bin/bash
# Start Fauna in Docker: auto-init cluster on first run, then run server (OPERATING.md).
set -euo pipefail

cd /opt/fauna
mkdir -p data log flags
[ -f flags/feature-flags.json ] || echo '{}' > flags/feature-flags.json

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

echo "Cluster initialized. Starting Fauna..."
exec ./bin/faunadb -c faunadb.yml
