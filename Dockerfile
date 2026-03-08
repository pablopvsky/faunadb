# Multi-stage: build FaunaDB tarball (like mktarball.sh), then runtime image with configurable auth_root_key.
# Set AUTH_ROOT_KEY at run time to override the root key (default: secret).
# Usage:
#   docker build -t faunadb .
#   docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret faunadb
#   # Optional: persist data
#   docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret -v faunadb-data:/opt/fauna/data faunadb

# ------------------------------------------------------------------------------
# Stage 1: build JAR and stage tarball (inlined mktarball logic, no mktarball.sh)
# ------------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk AS builder

WORKDIR /app

# Install sbt and git (GitPlugin runs "git rev-parse" during sbt load)
RUN apt-get update -qq && apt-get install -y --no-install-recommends curl gnupg2 ca-certificates git \
    && curl -sL "https://github.com/sbt/sbt/releases/download/v1.10.7/sbt-1.10.7.tgz" | tar xz -C /usr/local \
    && ln -sf /usr/local/sbt/bin/sbt /usr/bin/sbt \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy build definition and source (needed for service/assembly)
COPY build.sbt ./
COPY project/ project/
COPY service/ service/
COPY ext/ ext/

# GitPlugin expects a git repo (git rev-parse HEAD); .git is not in context, so init and make one commit
RUN git init \
    && git config user.email "docker@faunadb" \
    && git config user.name "Docker Build" \
    && git add -A \
    && git commit -m "docker build" --allow-empty

# Build faunadb.jar (same as mktarball)
ENV FAUNADB_RELEASE=true
RUN sbt service/assembly

# Stage tarball layout (bin + lib; config generated at runtime in entrypoint)
RUN mkdir -p tarball/bin tarball/lib \
    && cp service/target/scala-2.13/faunadb.jar tarball/lib/ \
    && cp service/src/main/scripts/faunadb service/src/main/scripts/faunadb-admin service/src/main/scripts/faunadb-backup-s3-upload tarball/bin/

# ------------------------------------------------------------------------------
# Stage 2: runtime image with tarball + entrypoint (run-local / start-local style)
# ------------------------------------------------------------------------------
FROM eclipse-temurin:17-jre

WORKDIR /opt/fauna

# Copy tarball from builder; jamm.jar as -javaagent silences the "Unsafe" heap-size warning
COPY --from=builder /app/tarball/bin ./bin
COPY --from=builder /app/tarball/lib ./lib
COPY --from=builder /app/service/lib/jamm.jar ./lib/

# Entrypoint: create faunadb.yml (OPERATING.md: not included in release tar), init, then start server
COPY scripts/docker-entrypoint.sh /opt/fauna/docker-entrypoint.sh
RUN chmod +x /opt/fauna/docker-entrypoint.sh /opt/fauna/bin/faunadb /opt/fauna/bin/faunadb-admin /opt/fauna/bin/faunadb-backup-s3-upload

# AUTH_ROOT_KEY is not set here to avoid baking secrets into the image; set at run time with -e AUTH_ROOT_KEY=...
# Entrypoint defaults to "secret" if unset (see scripts/docker-entrypoint.sh).

EXPOSE 8443 8444

ENTRYPOINT ["/opt/fauna/docker-entrypoint.sh"]
