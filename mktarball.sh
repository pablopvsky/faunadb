#!/bin/bash

set -euo pipefail

# Prefer macOS java_home; fall back to Homebrew OpenJDK 17 if not found
if JAVA_HOME_CANDIDATE=$(/usr/libexec/java_home -v 17 2>/dev/null); then
  export JAVA_HOME=$JAVA_HOME_CANDIDATE
else
  export JAVA_HOME="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
    echo "Error: Java 17 not found. Install with: brew install openjdk@17" >&2
    exit 1
  fi
fi
export PATH=$JAVA_HOME/bin:$PATH

echo "Using Java version:"
java -version

# build faunadb.jar
export FAUNADB_RELEASE=true
sbt service/assembly

# copy resources
mkdir -p tarball/bin
mkdir -p tarball/lib
cp service/target/scala-2.13/faunadb.jar tarball/lib/
[ -f service/lib/jamm.jar ] && cp service/lib/jamm.jar tarball/lib/
cp service/src/main/scripts/faunadb{,-admin,-backup-s3-upload} tarball/bin/
# config example and local-run helpers (persisted from source on every build)
cp service/src/main/scripts/faunadb.yml.example tarball/faunadb.yml
cp service/src/main/scripts/faunadb.yml.example tarball/faunadb.yml.example
cp service/src/main/scripts/run-local.sh tarball/
cp service/src/main/scripts/README-tarball.md tarball/README.md
chmod +x tarball/run-local.sh

# make tarball
mkdir -p artifacts
cd tarball
tar czf ../artifacts/fauna-$(date +%Y-%m-%d).tar.gz ./*