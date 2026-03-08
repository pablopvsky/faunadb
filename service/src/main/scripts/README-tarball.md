# Fauna tarball – local run

Per OPERATING.md: start the server, then initialize the cluster.

**One command (recommended):**

```bash
./run-local.sh
```

This starts the Fauna server, waits for it to be ready, runs `faunadb-admin init -r replica_1`, then leaves the server running in the background. To stop the server later, use the `kill` command printed at the end.

**Manual steps (same as OPERATING.md):**

1. Start the server (keep it running in one terminal):
   ```bash
   ./bin/faunadb
   ```
2. In another terminal, from this directory, initialize the cluster:
   ```bash
   ./bin/faunadb-admin init -r replica_1
   ```

Config: `faunadb.yml` (see `faunadb.yml.example`). Data under `data/`, logs under `log/`, flags under `flags/`.
