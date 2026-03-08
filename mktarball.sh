#!/bin/bash

set -euo pipefail

# Ensure we're using a compatible Java version
# Java 67 corresponds to Java 23, which is likely too new
# Let's set JAVA_HOME to a compatible version (e.g., Java 8 or 11)
export JAVA_HOME=$(/usr/libexec/java_home -v 17)  # macOS
export PATH=$JAVA_HOME/bin:$PATH

# build faunadb.jar
export FAUNADB_RELEASE=true
sbt -batch -no-colors service/assembly

# copy resources
mkdir -p tarball/bin
mkdir -p tarball/lib
cp service/target/scala-2.13/faunadb.jar tarball/lib/
cp service/src/main/scripts/faunadb{,-admin,-backup-s3-upload} tarball/bin/

# default config so extract-and-run works (tarball/ is gitignored so we write it here)
cat > tarball/faunadb.yml << 'FAUNADB_YAML'
# Default config for extract-and-run (relative paths; run with cwd = extracted dir)
storage_data_path: data
log_path: log

cluster_name: local_cluster
auth_root_key: secret

network_listen_address: 127.0.0.1
network_broadcast_address: 127.0.0.1
network_admin_http_address: 127.0.0.1
network_coordinator_http_address: 127.0.0.1

# Required: parent dir must exist (watcher watches the directory)
flags_path: feature-flags.json
FAUNADB_YAML

# make tarball
mkdir -p target
cd tarball
tar czf ../target/fauna-$(date +%Y-%m-%d).tar.gz ./*
