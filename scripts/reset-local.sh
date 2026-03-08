#!/usr/bin/env bash
# Stop FaunaDB from either method (script or launchd) and clean state.
# Usage: ./scripts/reset-local.sh [--wipe-data]
#
# Without options: stops any running FaunaDB, removes PID file and unloads
#   launchd job so there is no conflict between start-local.sh and
#   start-local-launchd.sh.
#
# With --wipe-data: same as above, then deletes tarball/data and tarball/log
#   so the next start is a fresh cluster (you must run faunadb-admin init again).

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
TARBALL_DIR="$REPO_ROOT/tarball"
PID_FILE="$TARBALL_DIR/faunadb.pid"
LABEL="com.faunadb.faunadb.local"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"

WIPE_DATA=false
for arg in "$@"; do
  case "$arg" in
    --wipe-data) WIPE_DATA=true ;;
    -h|--help)
      echo "Usage: $0 [--wipe-data]"
      echo "  Stop FaunaDB (script or launchd) and clean state."
      echo "  --wipe-data  Also remove tarball/data and tarball/log (fresh cluster)."
      exit 0
      ;;
  esac
done

echo "==> Resetting local FaunaDB state..."

# 1. Unload launchd job if loaded
if launchctl list "$LABEL" &>/dev/null; then
  echo "==> Unloading launchd job ($LABEL)..."
  launchctl unload -w "$PLIST_PATH"
  echo "    Unloaded."
else
  echo "==> launchd: not loaded."
fi

# 2. Remove launchd plist so next start-local-launchd.sh is clean
if [ -f "$PLIST_PATH" ]; then
  rm -f "$PLIST_PATH"
  echo "==> Removed plist: $PLIST_PATH"
fi

# 3. Stop process started by start-local.sh (PID file or faunadb.jar)
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  rm -f "$PID_FILE"
  if kill -0 "$PID" 2>/dev/null; then
    echo "==> Stopping FaunaDB (PID $PID)..."
    kill "$PID" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$PID" 2>/dev/null; then
      kill -9 "$PID" 2>/dev/null || true
    fi
    echo "    Stopped."
  else
    echo "==> Stale PID file removed."
  fi
else
  if pgrep -f "faunadb.jar" >/dev/null 2>&1; then
    echo "==> Stopping FaunaDB (faunadb.jar process)..."
    pkill -f "faunadb.jar" || true
    echo "    Stopped."
  else
    echo "==> No PID file and no faunadb.jar process."
  fi
fi

# 4. Optional: wipe data and log
if [ "$WIPE_DATA" = true ]; then
  echo "==> Wiping data and log..."
  rm -rf "$TARBALL_DIR/data" "$TARBALL_DIR/log"
  mkdir -p "$TARBALL_DIR/data" "$TARBALL_DIR/log"
  echo "    Done. Next start needs: cd tarball && ./bin/faunadb-admin init -r replica_1"
fi

echo "==> Reset complete. You can run ./scripts/start-local.sh or ./scripts/start-local-launchd.sh"
