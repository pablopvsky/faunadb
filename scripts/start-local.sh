#!/usr/bin/env bash
# Start FaunaDB from the local tarball in the background.
# Usage: ./scripts/start-local.sh
# Stop with: ./scripts/stop-local.sh
# If launchd was used before: ./scripts/reset-local.sh then start again.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
TARBALL_DIR="$REPO_ROOT/tarball"
PID_FILE="$TARBALL_DIR/faunadb.pid"

if [ ! -f "$TARBALL_DIR/bin/faunadb" ]; then
  echo "Tarball not found at $TARBALL_DIR" 1>&2
  echo "Build it first, e.g.: ./mktarball.sh" 1>&2
  exit 1
fi

if [ ! -f "$TARBALL_DIR/lib/faunadb.jar" ]; then
  echo "faunadb.jar not found in $TARBALL_DIR/lib" 1>&2
  echo "Build the JAR first, e.g.: sbt service/assembly" 1>&2
  exit 1
fi

if ! command -v java &>/dev/null; then
  echo "Java not found. Install Java 17, e.g.: brew install openjdk@17" 1>&2
  exit 1
fi

if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "FaunaDB is already running (PID $OLD_PID). Stop it first: ./scripts/stop-local.sh" 1>&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi

echo "==> Ensuring data and log directories exist..."
mkdir -p "$TARBALL_DIR/data" "$TARBALL_DIR/log"

echo "==> Starting FaunaDB in the background..."
cd "$TARBALL_DIR"
nohup ./bin/faunadb -c faunadb-local.yml >> "$TARBALL_DIR/faunadb.log" 2>> "$TARBALL_DIR/faunadb.err" &
echo $! > "$PID_FILE"

echo "==> FaunaDB started (PID $(cat "$PID_FILE"))."
echo "    Stop: ./scripts/stop-local.sh"
echo "    One-time init (required for port 8443): cd tarball && ./bin/faunadb-admin init -r replica_1"
echo "    Health (8443 = after init): curl http://127.0.0.1:8443/ping"
echo "    Admin ping (8444 = before init): curl http://127.0.0.1:8444/ping"
echo "    Logs: tail -f tarball/faunadb.log"
