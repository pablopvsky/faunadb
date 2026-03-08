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

**Ping / health check:** The API uses HTTP/2. Use **127.0.0.1** (not `localhost`, to avoid IPv6 issues):

```bash
curl --http2-prior-knowledge http://127.0.0.1:8443/ping
# with scope:
curl --http2-prior-knowledge "http://127.0.0.1:8443/ping?scope=node"
```

- You need a curl built with HTTP/2 (e.g. `curl --version` should show **nghttp2**). macOS system curl may be too old; install with `brew install curl` and use that `curl`.
- If it still fails, test from inside the container:  
  `docker exec faunadb curl -s --http2-prior-knowledge http://127.0.0.1:8443/ping`  
  If that returns 200, the server is fine and the issue is host networking or your local curl.
- To inspect startup and errors: `docker logs -f faunadb` (or `docker compose logs -f faunadb`).

To run admin commands:

```bash
docker compose exec faunadb ./bin/faunadb-admin --conf faunadb.yml status
```
