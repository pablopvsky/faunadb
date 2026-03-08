#!/usr/bin/env bash
# Install dependencies to compile the FaunaDB JAR (macOS with Homebrew).
# Usage: ./scripts/setup-build-env.sh

set -euo pipefail

echo "==> Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "Homebrew is required. Install from https://brew.sh"
  exit 1
fi

echo "==> Installing OpenJDK 17..."
brew install openjdk@17

echo "==> Installing sbt..."
brew install sbt

# Set JAVA_HOME for this session so 'java' and 'sbt' work
JAVA_HOME_CANDIDATE="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
if [ -d "$JAVA_HOME_CANDIDATE" ]; then
  export JAVA_HOME="$JAVA_HOME_CANDIDATE"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "==> JAVA_HOME set to $JAVA_HOME (this session only)"
fi

echo ""
echo "==> Verifying..."
java -version
echo ""
sbt -v sbtVersion
echo ""
echo "==> Done. To compile the JAR from the project root:"
echo "    sbt service/assembly"
echo ""
echo "For a production JAR:"
echo "    FAUNADB_RELEASE=true sbt service/assembly"
echo ""
echo "To make Java 17 the default in new shells, add to ~/.zshrc:"
echo '  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"'
echo '  export PATH="$JAVA_HOME/bin:$PATH"'
