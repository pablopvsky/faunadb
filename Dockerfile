# Multi-stage: stage a tarball from a locally-built JAR (no compile in Docker), then runtime image.
# Build the JAR locally first, then copy it into the image:
#   FAUNADB_RELEASE=true sbt service/assembly
#   cp service/target/scala-2.13/faunadb.jar faunadb.jar
#   docker build -t faunadb .
# Or pass the JAR path: docker build --build-arg JAR_PATH=/path/to/faunadb.jar -t faunadb .
#
# Set AUTH_ROOT_KEY at run time to override the root key (default: secret).
#   docker run -p 8443:8443 -p 8444:8444 -e AUTH_ROOT_KEY=your-secret faunadb

# ------------------------------------------------------------------------------
# Stage 1: stage tarball from local JAR + scripts (no sbt/compile)
# ------------------------------------------------------------------------------
FROM alpine:3.19 AS prep

WORKDIR /app

# JAR: from build context (default faunadb.jar at repo root; target/ is in .dockerignore)
ARG JAR_PATH=faunadb.jar
COPY ${JAR_PATH} tarball/lib/faunadb.jar

# Bin scripts
COPY service/src/main/scripts/faunadb service/src/main/scripts/faunadb-admin service/src/main/scripts/faunadb-backup-s3-upload tarball/bin/

# jamm.jar (optional agent to silence "Unsafe" heap-size warning); download from Maven Central
RUN apk add --no-cache curl \
    && curl -sL -o tarball/lib/jamm.jar \
       "https://repo1.maven.org/maven2/com/github/jbellis/jamm/0.3.0/jamm-0.3.0.jar" \
    && apk del curl

# ------------------------------------------------------------------------------
# Stage 2: runtime image with tarball + entrypoint (run-local / start-local style)
# ------------------------------------------------------------------------------
FROM eclipse-temurin:17-jre

WORKDIR /opt/fauna

# Copy tarball from prep stage
COPY --from=prep /app/tarball/bin ./bin
COPY --from=prep /app/tarball/lib ./lib

# Entrypoint: create faunadb.yml (OPERATING.md: not included in release tar), init, then start server
COPY scripts/docker-entrypoint.sh /opt/fauna/docker-entrypoint.sh
RUN chmod +x /opt/fauna/docker-entrypoint.sh /opt/fauna/bin/faunadb /opt/fauna/bin/faunadb-admin /opt/fauna/bin/faunadb-backup-s3-upload

# AUTH_ROOT_KEY is not set here to avoid baking secrets into the image; set at run time with -e AUTH_ROOT_KEY=...
# Entrypoint defaults to "secret" if unset (see scripts/docker-entrypoint.sh).

EXPOSE 8443 8444

ENTRYPOINT ["/opt/fauna/docker-entrypoint.sh"]
