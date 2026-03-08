# Docker

Build the tarball first, then build and run the image.

**Build and run (Compose):**

```bash
./mktarball.sh
docker compose build
docker compose up -d
```

**Build and run (plain Docker):**

```bash
./mktarball.sh
docker build -t faunadb .
docker run -d -p 8443:8443 -p 8444:8444 --name faunadb faunadb
```

- **8443** – coordinator / API
- **8444** – admin HTTP

The cluster is initialized automatically on first start (replica_1). Data and log are stored in Docker volumes when using Compose.

To run admin commands:

```bash
docker compose exec faunadb ./bin/faunadb-admin --conf faunadb.yml status
```
