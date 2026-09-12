# Xiand 仙道 — Open-Source Guide

> An eastern-fantasy multi-profession MUD: Pike 9 backend + Vue 3 web + React Native mobile, horizontally scaled across map workers.

## Quick Start

### Requirements

| Component | Version | Notes |
|---|---|---|
| Pike | 9.0.x | Engine runtime (this repo bundles `lowlib/` stdlib) |
| MySQL | 5.7+ | Optional (leaderboards/guild persistence, see `docs/MYSQL_SETUP.md`) |
| Node.js | 18+ | Frontend builds (Vue + RN client) |
| Docker | 20+ | Production deployment (recommended) |

### Local Run (single process + TestUnit)

```bash
git clone <repo> && cd xiand
./scripts/restart_with_testunit.sh
# Boots Pike -> runs the full TestUnit suite -> expects 146+ passed / 0 failed.
# The game then serves HTTP on 127.0.0.1:8888 and MUD on 127.0.0.1:13800.
```

### Local Run (multi-worker cluster)

```bash
./scripts/restart_map_workers_with_testunit.sh
# 1 coordinator + N map workers + full TestUnit regression.
```

### Docker Production (runboot)

```bash
docker compose -f docker/docker-compose.yml up -d
# The container entrypoint is docker/start-unified.sh ("runboot"):
#   1. Starts Tomcat (static assets / legacy JSP compatibility)
#   2. Applies the multi-worker cluster (scripts/map_worker_cluster.sh)
#   3. Waits for the HTTP health endpoint (up to 1200s cold-compile window)
#   4. Enters the supervisor loop:
#      - health probe checks coordinator status every 5 seconds
#      - soft failures (online snapshot not ready) must persist 600s
#        before escalation
#      - hard failures: 3 strikes -> safe stop -> full restart
#        (archive barrier preserved)
#      - cold-start stabilization: no unhealthy verdict during the
#        first 900 seconds
```

Overrideable env vars: `XIAND_MAP_WORKER_CONFIG`, `XIAND_MAP_WORKER_STARTUP_STABILIZATION_SECONDS`, `XIAND_ACTIVE_START_ATTEMPTS` and more — see the header comments in `docker/start-unified.sh`.

## Repository Layout

```
xiand/
├── lowlib/              Pike stdlib (driver, user, item inheritance)
│   └── driver.pike      Engine entry (start with -p 13800)
├── gamelib/
│   ├── cmds/            Player/admin commands (refine, pet, timed_event...)
│   ├── clone/           Item / NPC / room clone templates
│   ├── inherit/         NPC, equipment, book inherit layers
│   ├── single/daemons/  Daemons (autofightd, itemsd, refined,
│   │                    pike_gateway, map_worker_rpc...)
│   └── etc/             Config (timed_events.json, app_version.conf)
├── vue_source/          Vue 3 frontend source (builds into web/web_vue/)
├── rn_client/           React Native mobile client (iOS + Android)
├── docker/              Dockerfile.all + docker-compose.yml + runboot
├── scripts/
│   ├── restart_with_testunit.sh              Single process + test gate
│   ├── restart_map_workers_with_testunit.sh  Cluster + test gate
│   ├── map_worker_cluster.sh                 Worker lifecycle management
│   └── build/build_vue_frontend.sh           Vue build script
├── test_unit/           All regression tests (currently 147 files)
├── data_xiand/          Runtime data (player saves, cluster state — gitignored)
└── docs/                Architecture + topical design documents
```

## Core Architecture Documents

| Document | Content |
|---|---|
| [map-worker-architecture.md](map-worker-architecture.md) | Multi-worker topology, routing, anti-clone fences, failure recovery |
| [new-moon-multi-worker-architecture.en.md](new-moon-multi-worker-architecture.en.md) | New Moon equipment system across workers |
| [illusion-realm-s1.md](illusion-realm-s1.md) | Illusion season (S1): 81-chapter campaign, anti-cloning, settlement |
| [frontend-open-source-license-memo.md](frontend-open-source-license-memo.md) | Frontend dependency license compliance |
| [MYSQL_SETUP.md](MYSQL_SETUP.md) | MySQL configuration |

## Recently Added Systems (Aug–Sep 2026)

### Equipment Refining (`gamelib/single/daemons/refined.pike` + `cmds/refine.pike`)

Each refine level adds +1% to all attributes. Refine stones drop from PVP kills (40% chance of 1–3 stones, daily cap 200, five anti-farm rules). Fire Jade purchased 1:1 with Jade Shards. Every 50 levels past 950 sets a threshold: failure delevels instead of zeroing, with a band floor. Monthly PVP and donation leaderboards merge across workers; the top donor receives a Guard Charm. Set resonance: wearing 5+ pieces of a collection grants +5%, 8+ grants +10% refine bonus.

### Server-Side Auto-Battle (`gamelib/single/daemons/autofightd.pike`)

The browser/client only renders; combat runs in server-side ticks. One global scheduler dispatches by world-queue pressure (normal 16/s down to severe 4/s). After quota exhaustion a 6-hour session hold keeps the virtual connection alive (prevents idle-kick false positives). Overflow rooms: when public training rooms fill, the system clones isolated no-exit instances, reclaimed after 10 idle minutes. The ~30k-line daemon covers smart skill queues, auto- potion, auto-inventory cleanup, set recycling, and the online-snapshot self-heal below.

### Online Snapshot Self-Heal (`_http_api_mod/pike_gateway.pike`)

Root-cause fix for two full-cluster restarts (2026-09-10): a live player with a diverged route epoch poisoned every snapshot publish, escalating to a 600-second supervisor restart. The same offender is now discarded on its claiming worker after 120 seconds (one relogin instead of a cluster-wide outage). Validation failures log the offending `user_ref` plus route details for triage.

### Daily Timed Events (`_timed_event_mod/`)

20:00 Tianheng (PVP mirror arena) and 21:00 Jiuyao (PVE nine-grid). Experience settles as a percentage of the level requirement (3% participation up to 15% champion; capped characters convert to double tokens). Rank rewards include refine stones. Event tokens exchange for supplies and forging materials. Clock-injection test hooks enable deterministic full-flow regression.

### Illusion Season (`seasonal_chard.pike` + `illusion_journeyd.pike`)

81 chapters across nine volumes plus deterministic side quests and three routes (Star Seeker / Array Breaker / Heart United). Anti-clone invariant: settlement only flips the account index `illusion -> eternal`; saves are never copied. Cross-worker state files use PID-suffixed temp files + mkdir locks + month-aware merges.

### Mobile Client (`rn_client/`)

React Native + Expo. Parallel characters (locally adjustable cap 10–50), one-tap login of all characters with auto-battle, chat rooms, paper-doll equipment panel, world map, version-update prompts, terms-of-service gate, and recharge guidance. Build recipes live in `docs/`.

## Test Gate

```bash
./scripts/restart_with_testunit.sh
# Expected:
# [restart] TestUnit passed: [TESTUNITD] COMPLETE passed=147 failed=0 skipped=4
```

**Every change must pass this gate before pushing.** Tests catch compile errors, numeric regressions, and save-file conservation violations. The 147 test files cover refine formula boundaries, illusion full-profession flows, timed-event signup-to-settlement, snapshot self-heal, multi-worker transaction locks, XSS protection, and more.

## License

See [LICENSE.zh.md](../LICENSE.zh.md). Frontend dependency license compliance is documented separately.

---

Questions after cloning? QQ group 610653957 · Telegram https://t.me/wapmud
