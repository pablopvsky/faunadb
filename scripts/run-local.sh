#!/usr/bin/env bash
# Run FaunaDB from the local tarball (in-place, development).
# Usage: ./scripts/run-local.sh
#
# Prerequisites: Java 17, and a built tarball (e.g. mktarball.sh).
# One-time: initialize the cluster with:
#   cd tarball && ./bin/faunadb-admin init -r replica_1

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
TARBALL_DIR="$REPO_ROOT/tarball"

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

echo "==> Ensuring data and log directories exist..."
mkdir -p "$TARBALL_DIR/data" "$TARBALL_DIR/log"

echo "==> Starting FaunaDB from $TARBALL_DIR"
echo "    Config: faunadb.yml"
echo "    Stop with Ctrl+C. One-time: cd tarball && ./bin/faunadb-admin init -r replica_1"
echo "    Health (after init): curl http://127.0.0.1:8443/ping  |  Admin: curl http://127.0.0.1:8444/ping"
echo ""

cd "$TARBALL_DIR"
exec ./bin/faunadb -c faunadb-local.yml
