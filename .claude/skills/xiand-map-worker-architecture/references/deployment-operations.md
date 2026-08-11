# Deployment and Operations Reference

## Contents

1. Configuration model
2. `.env` migration
3. Local lifecycle
4. Docker lifecycle
5. Ports and process counts
6. Scaling and admin operations
7. Health, logs, and fallback
8. Image/platform cautions

## Configuration model

Use `deploy/map_workers/config.example.json` as schema documentation. The persistent desired configuration is `data_xiand/map_workers/config.json` on the running data volume.

Required schema v2 keys:

```json
{
  "schema_version": 2,
  "enabled": 0,
  "traffic_mode": "shadow",
  "worker_count": 3,
  "worker_capacity": 100,
  "placement": "load_aware_rendezvous",
  "coordinator_http_port": 18880,
  "worker_http_base_port": 18881,
  "worker_mud_base_port": 14801,
  "gateway_port": 8888
}
```

Validate:

- `worker_count`: 1..16;
- `worker_capacity`: 10..10000;
- all derived ports: 1024..65535 and non-overlapping;
- placement: exactly `load_aware_rendezvous`;
- active mode: explicit acknowledgement, a complete healthy topology, and no fallback latch.

Admin UI saves desired configuration only. It must not create or kill processes from the game thread. Apply it with the orchestrator after a safe stop/restart.

## `.env` migration

`restart-docker.sh` always invokes `scripts/setup_deploy_env.sh` before reading configuration.

For an existing legacy `.env`, the intended one-click flow is:

1. Read `MYSQL_PASSWORD` from the old restricted file without printing it.
2. Copy the current `.env.example` to a same-directory temporary file.
3. Write the saved password into the new template with shell-safe quoting.
4. Validate shell syntax, preserve the old file's uid/gid, set mode `600`, and atomically replace `.env`.
5. Generate fresh `XIAND_WORKER_TOKEN` and `XIAND_HEALTH_TOKEN` if the new template leaves them empty.

This deliberately removes old custom variables and resets deploy defaults to the current template. Persistent `data_xiand/map_workers/config.json` remains authoritative for an existing worker topology; bootstrap writes its effective values back into `.env`.

If no `.env` exists, copy `.env.example`, use exported `MYSQL_PASSWORD` or prompt silently in a terminal, then generate tokens. Non-interactive startup without a password must fail.

Never commit `.env`, print credentials, pass MySQL password on a visible command line, or reuse the MySQL password as the internal worker token.

## Local lifecycle

Use:

```bash
./restart-local-workers.sh --workers 3
```

The wrapper:

1. sets the isolated active acknowledgement;
2. safely stops any previous topology;
3. starts standalone once and runs the complete real TestUnit suite with stop-after-test;
4. starts the configured worker topology;
5. runs cluster health checks.

The persisted `config.json` still determines `shadow` versus `active`. The acknowledgement alone does not change the mode.

Direct operations:

```bash
scripts/map_worker_cluster.sh validate
scripts/map_worker_cluster.sh status
scripts/map_worker_cluster.sh health
scripts/map_worker_cluster.sh start --workers 3
scripts/map_worker_cluster.sh stop
scripts/map_worker_cluster.sh restart --workers 5
scripts/map_worker_cluster.sh recover-gateway
```

`recover-gateway` is allowed only when validated `topology.json` exists and every worker process/port is alive. It inventories workers before reopening routing.

## Docker lifecycle

Production wrapper:

```text
restart-all-docker.sh
  -> restart-docker.sh xd01-02 2002 2003 [--workers N]
     -> setup_deploy_env.sh
     -> initialize/verify MySQL
     -> pull selected image
     -> safely stop old cluster/container
     -> persist worker config on host
     -> docker run unified container
        -> docker/start-unified.sh
           -> Tomcat
           -> legacy main and/or coordinator + workers
           -> supervisor
     -> verify logical zones and worker health
```

`restart-docker.sh --workers N` is a deliberate one-shot topology override that persists only `worker_count` into the host config. Existing admin mode/capacity remain authoritative.

Host persistent mounts:

| Host | Container |
|---|---|
| `/usr/local/games/allxd/<area>/data_xiand` | `/app/xiand/data_xiand` |
| `/usr/local/games/allxd/<area>/etc` | `/app/xiand/gamelib/etc` |
| `/usr/local/games/allxd/item` | `/app/xiand/gamelib/clone/item` |
| `/usr/local/games/allxd/log/<area>` | `/app/xiand/log` |
| `/usr/local/games/allxd/log/<area>/db_log` | `/app/xiand/db_log` |

Do not publish coordinator or worker ports from Docker. Public mappings remain the historical Tomcat/API/MUD mappings.

Optional gateway pressure controls are passed by both `docker run` and Compose:

- `XIAND_GATEWAY_MAX_REQUESTS` (default `128`) for total accepted work;
- `XIAND_GATEWAY_MAX_REQUESTS_PER_WORKER` for one worker's RPC bulkhead. When unset, Pike derives `max(8, ceil(total/workers)+4)` from the actual topology.

Keep the per-worker limit below the total limit. Raising it does not fix a slow world process; inspect command queue, backend lag, CPU, call-outs, and save latency first.

## Ports and process counts

Default internal ports:

| Component | MUD | HTTP | Published? |
|---|---:|---:|---|
| legacy standalone | 13800 | 8888 | yes in legacy/shadow |
| coordinator | 14800 | 18880 | no |
| w01 | 14801 | 18881 | no |
| w02 | 14802 | 18882 | no |
| w03 | 14803 | 18883 | no |
| embedded active gateway | same coordinator process | 8888 | yes |

With `N=3`:

- disabled/legacy: one Pike;
- shadow: five Pike (legacy + coordinator + three workers);
- active: four Pike (coordinator + three workers);
- plus Tomcat and small socat helpers in Docker.

Do not count the embedded gateway as another process.

## Scaling and admin operations

Use 1..16 workers. Scaling changes the topology and currently requires a safe cluster stop/restart; do not start extra workers beside a running topology.

Safe sequence:

1. Verify current health and record topology/status.
2. Stop through the coordinator quiesce barrier.
3. Update count using `--workers N` or the admin desired config.
4. Start/apply the full topology.
5. Wait for every worker registration, one catalog generation, and routing ready.
6. Verify users in different source workers converge to the same worker when entering one shared map.
7. Verify the cluster online snapshot contains every exact owner once and remote friend teleport crosses through the normal handoff.
8. Verify saves/reloads and duplicate-owner absence.

Admin commands:

- `mgr_map_workers`: status/configuration;
- drain/resume: stop/resume new placement on a worker without force-moving active players;
- rebalance: move only idle affinities;
- online view: aggregate exact worker/epoch ownership;
- recharge: route to online owner or safely load on the chosen primary path, with idempotency.

Do not interpret a saved admin count as running process count. Compare `config.json`, runtime `topology.json`, PID files, listening ports, and coordinator status.

## Health, logs, and fallback

Runtime files:

- `log/map-workers/<area>/topology.json`: validated running topology;
- `log/map-workers/<area>/coordinator.pid`, `wNN.pid`: process identity;
- `log/map-workers/<area>/runtime.coordinator.log`, `runtime.wNN.log`: process startup/runtime;
- `data_xiand/map_workers/runtime-mode`: `shadow`, `active`, `legacy-main`, `legacy-fallback`, or `shadow-degraded`;
- `data_xiand/map_workers/fallback-latched`: persistent active circuit breaker;
- `log/map-worker-monitor.log`: supervisor health failures;
- `log/map_worker_admin.log`: configuration/drain/rebalance audit;
- `log/stderr.<port>` and `log/pike.log`: Pike errors;
- `log/tomcat.log`: JSP/Tomcat errors.

Health must prove:

- coordinator PID and internal ports alive;
- exactly the configured workers alive on both internal ports;
- every worker registered healthy;
- controller ready and routing ready;
- active public listener ready only in active mode;
- no uncertain requests, pending reconciliation, background arrivals, or maintenance operations before shutdown;
- per-worker request active/peak/rejected/failure/circuit metrics are bounded and explainable;
- control persistence is healthy and its latency/failure counters are not increasing unexpectedly.

During a one-version rolling script upgrade, the immediately previous coordinator may omit the new `shutdown_state` field. Accept that legacy response only when every historical quiescence counter is explicitly zero. When the field is present it must be exactly `prepared`; never treat an unknown non-empty state as compatible.

The Docker supervisor probes every five seconds. After three failures it opens the circuit. Active fallback is permitted only after the safe failover shutdown protocol accounts for failed and reachable workers. If quiescence or save fencing cannot be proven, preserve the old container/processes and stop deployment.

`restart-all-docker.sh` may recover a historical active fallback latch after it safely stops the old container. `scripts/recover_map_worker_fallback_latch.sh` must validate the current schema, require the active acknowledgement, and audit both primary/backup control-plane snapshots before atomically moving the latch into `fallback-history/`. Permit recovery only when all leases are active-but-expired, every handoff is terminal and expired, no coordinator envelope/escrow/PK mutation remains, and all durable social-outbox events are expired. Missing, malformed, future-version, symlinked, live, frozen, prepared, or unsettled state must retain the latch.

The container creates `fallback-latched` as root-owned mode `0600`, while the host deployment account owns the parent data directory. Inspect latch size and mode with `stat`; never open it with shell input redirection or require the host account to `chmod` it. A same-filesystem `mv` into the mode-`0700` history directory preserves the secure root ownership and mode without reading the file.

The control-plane snapshots and durable social-outbox files may also be root-owned mode `0600`. If the host deployment account cannot read them, rerun the identical ownership audit in a short-lived helper based on the already selected Xiand image. The helper must have no network, a read-only root filesystem, a read-only bind of only `data_xiand/map_workers`, all Linux capabilities dropped, `no-new-privileges`, and strict PID/memory limits. It may run as container root solely to read those files; it must never relabel, chmod, rewrite, delete, or print their payloads. Failure to start the helper or any audit failure retains the latch.

Use `./restart-all-docker.sh --force-active` when the operator requires active mode as the deployment outcome. This flag does not bypass safe stop or ownership/mutation audits. It archives a safe historical latch and attempts a cold active start; if startup reopens the circuit, keep the legacy fallback serving traffic but make the deployment command fail visibly instead of reporting success.

## Image/platform cautions

`restart-docker.sh` first tries `${DOCKER_USER}/xiand-all:latest`. If pull succeeds, it runs that remote image, not a locally built branch image. If pull fails, it may use local `xiand-all:latest`.

Before claiming one-click branch deployment:

- build/push the branch image under the exact selected tag, or explicitly select a local tag;
- inspect the resulting image architecture;
- on Apple Silicon build CentOS x86_64 images with:

```bash
docker buildx build --platform linux/amd64 --load \
  -t xiand-all:latest -f docker/Dockerfile.all .
```

Building natively on the x86_64 test server is also valid. Validate the final container entrypoint, not only the Dockerfile build.
