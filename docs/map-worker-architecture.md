# Multi-Worker Map Architecture / 多Worker地图架构

> **A major architectural evolution of the Xiandao engine — from single-process Pike to a horizontally scalable multi-worker cluster.**

## Overview / 概述

The original Xiandao engine ran as a single Pike process handling all players, rooms, NPCs, and combat. As the game grew, this single-process model became the bottleneck: one slow room could block every player, and a crash took down the entire world.

Starting in August 2026, we redesigned the engine into a **coordinator + multi-worker** architecture where game rooms are distributed across multiple Pike processes, each owning a subset of the world's maps. Players transparently move between workers as they traverse the game world.

This document describes the full architecture in detail: topology, routing, placement, movement, persistence, anti-cloning fences, cross-worker social features, failure recovery, and the compatibility contract that preserves every existing public URL, TXD encoding, and legacy JSP behavior.

---

## 1. Runtime Topology / 运行时拓扑

The architecture uses **process isolation**, not threaded world mutation. Each worker is a full Pike process with its own memory space, garbage collector, and event loop.

```
Browser / old JSP / Vue
          |
          | public HTTP :8888 (active mode)
          v
Coordinator Pike process
  ├── map_workerd control plane
  ├── embedded pike_gateway (public proxy)
  ├── internal HTTP :18880
  └── internal MUD :14800
          |
          | loopback HTTP + XIAND_WORKER_TOKEN auth
          +------------------+------------------+
          v                  v                  v
      worker w01         worker w02         worker w03
      HTTP :18881        HTTP :18882        HTTP :18883
      MUD  :14801        MUD  :14802        MUD  :14803
```

For `N` workers:
- **Active mode**: 1 coordinator + N workers = N+1 Pike processes
- **Shadow mode**: workers run but serve no player traffic (observation only)
- **Legacy mode**: single-process fallback (the pre-architecture behavior)

### Process roles

| Process | Role | Ports |
|---------|------|-------|
| Coordinator | Control plane, gateway, placement, lease management | HTTP :18880 (internal), MUD :14800 |
| Worker w01..wN | Owns room affinities, hosts players, runs combat | HTTP :18881+, MUD :14801+ |
| Legacy main | Single-process fallback when workers unavailable | HTTP :8888, MUD :13800 |

### Key files

| Concern | Source |
|---------|--------|
| Control plane, affinity, leases, handoff | `gamelib/single/daemons/map_workerd.pike` |
| Embedded coordinator/public proxy | `gamelib/single/daemons/_http_api_mod/pike_gateway.pike` |
| Authenticated loopback worker RPC | `gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike` |
| HTTP role initialization | `gamelib/single/daemons/http_api_daemon.pike` |
| Player move/save/arrival fences | `gamelib/clone/user.pike` |
| Process lifecycle | `scripts/map_worker_cluster.sh` |
| Docker lifecycle | `restart-all-docker.sh`, `restart-docker.sh`, `docker/start-unified.sh` |
| Persistent desired configuration | `data_xiand/map_workers/config.json` |

---

## 2. Request Routing and Concurrency / 请求路由与并发

### The gateway pipeline

Every public HTTP request flows through the embedded gateway:

```
Client request (TXD token)
    → pike_gateway validates token
    → resolves player's worker via lease table
    → forwards to worker's internal HTTP via authenticated RPC
    → worker executes game logic
    → response returns through gateway to client
```

### Concurrency bounds

- **Public total request bound**: configured maximum concurrent requests across all workers
- **Per-worker bulkhead**: smaller limit per worker; a hot/slow worker rejects new work locally
- **Quarantine**: a request that may have already executed is quarantined globally and reconciled; it is never simply rerouted

### Worker RPC authentication

All coordinator-to-worker communication uses loopback HTTP with a shared `XIAND_WORKER_TOKEN` (minimum 32 characters). Worker control ports bind only to `127.0.0.1`.

---

## 3. Room Placement / 房间放置

### Affinity keys

Every room belongs to exactly one **affinity** — a consistency domain that maps to exactly one worker:

- Static rooms derive affinity from their directory path (e.g., `/gamelib/d/kunlunshan/` → `kunlunshan`)
- Dynamic rooms (homes, dungeons, event spaces) use special affinity blocks
- All rooms sharing an affinity are guaranteed to live in the same worker

### Placement rules

1. **One affinity → one worker**: rooms in the same affinity never split across processes
2. **Cold-start distribution**: affinities are distributed round-robin across workers on first boot
3. **Heat-based rebalancing**: the coordinator tracks per-affinity load and can migrate hot affinities to cooler workers
4. **Special affinities**: homes (`home`), dungeons (`fb_runtime`), seasonal content (`illusion_s1:*`) use dedicated affinity blocks

### Map affinity example

```
/gamelib/d/kunlunshan/yuxugong.pike    → affinity: kunlunshan
/gamelib/d/jinaodao/biyougong.pike     → affinity: jinaodao
/gamelib/d/illusion_s1/moon_gate.pike  → affinity: illusion_s1:hub
```

---

## 4. Character Movement / 人物移动

### Same-worker movement

When a player moves between rooms in the same affinity (same worker), movement is a simple in-process `move()` call — identical to the original single-process behavior.

### Cross-worker movement (handoff)

When a player moves to a room owned by a different worker:

```
1. Source worker: guard_local_player_move() detects affinity change
2. Source worker: saves player atomically, registers pending redirect
3. Gateway: reads redirect, coordinates the handoff
4. Target worker: receives archive, restores player object
5. Target worker: confirms arrival, installs room position
6. Source worker: releases lease (retires old copy)
```

### Movement fences

- **Static-room redirects**: report logical success so the original command completes durable costs/cooldowns on the sole source object
- **Dynamic clone rooms**: have no reconstructable path and fail closed (with planned durable escrow for future support)
- **Arrival validation**: the target must confirm the exact userid/epoch/room capability before the player becomes active

### Background handoff

Non-critical movements (idle drift, autofight routing) use background handoff — the player's next request resolves the movement without blocking the current request.

---

## 5. Persistence and Anti-Clone Fences / 持久化与防克隆围栏

### The lease system

Every online player has a **lease** on exactly one worker:

```
(worker_id, lease_epoch) → exclusive right to load/save this character
```

- A new handoff increments the epoch, invalidating all older copies
- Any save from a stale epoch is rejected by the persistence layer
- The lease is persisted before authority is granted to load or save

### Save fencing

```
1. Player object marked for save
2. Atomic write: temp file → fsync → rename to final path
3. Backup: previous save copied to .bak
4. Only after durable write: lease epoch advanced
```

### Anti-cloning invariants

1. **One archive per character**: exactly one `.o` file per character ID
2. **One live owner**: only the worker holding the current lease has a live player object
3. **Stale copies**: retired immediately after handoff commit
4. **Crash recovery**: on worker restart, uncertain saves are reconciled before the player can log in

---

## 6. Cross-Worker Social Features / 跨Worker社交功能

### Durable social-event pipeline

Cross-worker features use a durable outbox/inbox system:

| Feature | Mechanism |
|---------|-----------|
| Private chat | Direct worker RPC with retry + idempotent delivery |
| World broadcast | Fan-out to all workers via durable pipeline |
| Team snapshots | Primary replica on leader's worker, distributed to members' workers |
| Team chat/notices | Durable events with 7-day TTL |
| Team experience | Shared pool distributed via team-sync event family |
| Friend presence | Coordinator-verified cluster snapshot |

### Team sync delivery

```
Leader's worker: publishes team snapshot
    → gateway fans out to every worker
    → each worker validates + installs replica
    → members see consistent team state
```

Team snapshots self-heal: if a roster arrives with zero or multiple leaders, the receiving worker repairs it in place rather than rejecting it.

---

## 7. Recovery and Failure Model / 恢复与故障模型

### Worker failure

```
1. Coordinator detects missed heartbeats (TTL expiry)
2. Affected affinities marked for reassignment
3. New worker claims orphaned affinities
4. Players on failed worker: next login restores from last durable save
5. In-flight requests: quarantined and reconciled
```

### Coordinator failure

```
1. Docker restarts the container
2. Workers detect coordinator loss via heartbeat timeout
3. Workers drain and prepare for reconnection
4. New coordinator reads persisted topology + lease state
5. Workers reconnect and resume
```

### Fallback to legacy

If the worker topology cannot start (repeated health failures):

```
1. `fallback-latched` file is written (prevents startup loops)
2. System falls back to legacy single-process mode
3. Players continue playing without interruption
4. Manual intervention required to clear the latch
```

### Safe shutdown sequence

```
running → draining → prepared|failed
```

1. **Pause admission**: stop accepting new player requests
2. **Drain**: wait for in-flight requests to complete
3. **Reconcile**: resolve any uncertain work
4. **Fence saves**: ensure all player data is durable
5. **Stop workers**: only after all saves are confirmed

---

## 8. Compatibility Contract / 兼容性契约

The architecture change is **invisible to existing clients**:

| Guarantee | Status |
|-----------|--------|
| All public URLs | ✅ Unchanged |
| TXD encoding | ✅ Unchanged |
| Old bookmarks | ✅ Continue to work |
| Vue requests | ✅ Unchanged |
| Legacy JSP behavior | ✅ Preserved |
| PVP formulas | ✅ Untouched |
| Economy rules | ✅ Untouched |
| Drop rates | ✅ Untouched |

---

## 9. Seasonal Content Isolation / 赛季内容隔离

The seasonal (幻境) content uses dedicated affinities:

```
illusion_s1:hub      → hub rooms
illusion_s1:silver    → silver path
illusion_s1:ruins     → ruins area
illusion_s1:depths    → depths area
```

Seasonal characters are isolated:
- Shared account assets (warehouse, wallet, pets) are blocked during active season
- Chapter progression, rankings, and rewards use cycle-keyed state
- Return to 永恒服 atomically changes the account index entry
- No player archives, inventories, or rewards are ever copied during settlement

---

## 10. Performance Characteristics / 性能特征

### With 10 workers on production hardware

| Metric | Value |
|--------|-------|
| Workers | 10 |
| Coordinator processes | 1 |
| Total Pike processes | 11 |
| HTTP requests/sec | ~500 sustained |
| Cross-worker handoff latency | ~50-200ms |
| Worker cold start | ~2-5 minutes (full daemon compile) |
| Memory per worker | ~200-400MB |

### Scaling model

- **Horizontal**: add workers to handle more concurrent players
- **Affinity-based**: game logic parallelism follows the world's natural partitioning
- **No shared memory**: workers communicate only via authenticated HTTP RPC
- **Single-writer per room**: eliminates lock contention within rooms

---

## 11. Deployment / 部署

### Docker-based (recommended)

```bash
# Build image
./rebuild-image.sh

# Deploy with N workers
./restart-all-docker.sh --force-active --workers 10
```

### Local development

```bash
# Single worker (lightweight)
./restart-local-workers.sh --workers 1

# Multi-worker (realistic testing)
./restart-local-workers.sh --workers 3
```

### Configuration

Edit `data_xiand/map_workers/config.json`:

```json
{
  "enabled": 1,
  "traffic_mode": "active",
  "worker_count": 10,
  "coordinator_http_port": 18880,
  "worker_http_base_port": 18881,
  "worker_mud_base_port": 14801,
  "gateway_port": 8888
}
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `XIAND_WORKER_TOKEN` | Shared auth token (min 32 chars) |
| `XIAND_MAP_WORKER_ENABLED` | 0/1 |
| `XIAND_MAP_WORKER_TRAFFIC_MODE` | `shadow` or `active` |
| `XIAND_MAP_WORKER_COUNT` | Number of workers |
| `XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK` | Required for active mode trial |

---

## 12. Testing / 测试

Every change to the architecture must pass the full TestUnit suite:

```bash
./restart-local-workers.sh --workers 3
```

This runs **123 tests** including:
- Map worker architecture contracts
- Pike gateway routing
- Docker startup safety
- Friend teleport across workers
- Team snapshot distribution
- Cross-worker movement fencing
- Equipment anti-cloning
- Seasonal isolation boundaries

---

## Historical Context / 历史背景

The original engine was a single Pike process handling everything — a design that worked perfectly for the 2004-2008 era of WAP gaming. As we modernized the codebase for Pike 9 and Docker deployment in 2026, we recognized that the single-process model would not scale to modern player expectations.

The multi-worker architecture represents the biggest structural change in the engine's 20+ year history. It preserves every gameplay formula, every public interface, and every line of legacy code — while adding horizontal scalability that the original designers could only dream of.

---

*Last updated: August 2026*
