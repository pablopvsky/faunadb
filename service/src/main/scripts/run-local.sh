#!/bin/bash
# One-shot: start Fauna server, initialize cluster (replica_1). See OPERATING.md.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$ROOT"

if [ ! -f faunadb.yml ]; then
  echo "Run this script from the tarball root (where faunadb.yml is)." 1>&2
  exit 1
fi

# Required dirs (OPERATING.md: storage_data_path, log_path, flags_path)
mkdir -p data log flags
[ -f flags/feature-flags.json ] || echo '{"version": 0, "properties": []}' > flags/feature-flags.json

# Start server in background
echo "Starting Fauna server..."
./bin/faunadb &
PID=$!
cleanup() { kill $PID 2>/dev/null; wait $PID 2>/dev/null; exit 1; }
trap cleanup INT TERM

# Wait for admin port (default 8444)
ADMIN_PORT=8444
WAIT=0
MAX_WAIT=60
until curl -s -o /dev/null --connect-timeout 1 "http://127.0.0.1:$ADMIN_PORT/" 2>/dev/null; do
  sleep 1
  WAIT=$((WAIT + 1))
  if [ "$WAIT" -ge "$MAX_WAIT" ]; then
    echo "Server did not become ready in ${MAX_WAIT}s." 1>&2
    cleanup
  fi
done
trap - INT TERM

echo "Initializing cluster (replica_1)..."
./bin/faunadb-admin init -r replica_1

echo "Done. Server is running in background (PID $PID). To stop: kill $PID"
