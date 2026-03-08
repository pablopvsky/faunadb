#!/usr/bin/env bash
# Stop FaunaDB started by scripts/start-local.sh.
# Usage: ./scripts/stop-local.sh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
PID_FILE="$REPO_ROOT/tarball/faunadb.pid"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  rm -f "$PID_FILE"
  if kill -0 "$PID" 2>/dev/null; then
    echo "==> Stopping FaunaDB (PID $PID)..."
    kill "$PID" 2>/dev/null || true
    # Give it a moment to shut down gracefully
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$PID" 2>/dev/null; then
      echo "==> Forcing kill (PID $PID)"
      kill -9 "$PID" 2>/dev/null || true
    fi
    echo "==> FaunaDB stopped."
  else
    echo "==> FaunaDB was not running (stale PID file removed)."
  fi
else
  # Fallback: try to stop any local faunadb.jar process
  if pgrep -f "faunadb.jar" >/dev/null 2>&1; then
    echo "==> Stopping FaunaDB (no PID file, matching faunadb.jar)..."
    pkill -f "faunadb.jar" || true
    echo "==> FaunaDB stopped."
  else
    echo "==> FaunaDB is not running."
  fi
fi
