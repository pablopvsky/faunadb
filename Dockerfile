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

# Install sbt (sbt-extras style)
RUN apt-get update -qq && apt-get install -y --no-install-recommends curl gnupg2 ca-certificates \
    && curl -sL "https://github.com/sbt/sbt/releases/download/v1.10.7/sbt-1.10.7.tgz" | tar xz -C /usr/local \
    && ln -sf /usr/local/sbt/bin/sbt /usr/bin/sbt \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy build definition and source (needed for service/assembly)
COPY build.sbt ./
COPY project/ project/
COPY service/ service/
COPY ext/ ext/

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

# Copy tarball from builder
COPY --from=builder /app/tarball/bin ./bin
COPY --from=builder /app/tarball/lib ./lib

# Entrypoint: write faunadb.yml with AUTH_ROOT_KEY, run one-time init, then start server
COPY scripts/docker-entrypoint.sh /opt/fauna/docker-entrypoint.sh
RUN chmod +x /opt/fauna/docker-entrypoint.sh /opt/fauna/bin/faunadb /opt/fauna/bin/faunadb-admin /opt/fauna/bin/faunadb-backup-s3-upload

# Default root key (override with -e AUTH_ROOT_KEY=...)
ENV AUTH_ROOT_KEY=secret

EXPOSE 8443 8444

ENTRYPOINT ["/opt/fauna/docker-entrypoint.sh"]
