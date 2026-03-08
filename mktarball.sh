#!/bin/bash

set -euo pipefail

export JAVA_HOME=$(/usr/libexec/java_home -v 17)  # macOS
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
cp service/src/main/scripts/faunadb{,-admin,-backup-s3-upload} tarball/bin/

# make tarball
cd tarball
tar czf ../artifacts/fauna-$(date +%Y-%m-%d).tar.gz ./*