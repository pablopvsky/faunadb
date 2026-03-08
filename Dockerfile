# Build the tarball first: ./mktarball.sh
# Then: docker build -t faunadb .
FROM eclipse-temurin:17-jre-jammy

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/fauna

# Copy built tarball layout (bin, lib, config)
COPY tarball/bin bin/
COPY tarball/lib lib/
COPY docker/faunadb.yml faunadb.yml
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x bin/faunadb bin/faunadb-admin /docker-entrypoint.sh

# API (coordinator) and admin HTTP
EXPOSE 8443 8444

ENTRYPOINT ["/docker-entrypoint.sh"]
