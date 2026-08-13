# Architecture Reference

## Contents

1. Runtime topology
2. Request routing and concurrency
3. Room placement
4. Character movement
5. Persistence and anti-clone fences
6. Cross-worker and global features
7. Recovery and failure model
8. Compatibility contract
9. Adjacent dynamic-NPC balance contract

## Runtime topology

The architecture uses process isolation, not threaded world mutation.

```text
Browser / old JSP / Vue
          |
          | public HTTP :8888 (active only)
          v
Coordinator Pike process
  - map_workerd control plane
  - embedded pike_gateway
  - internal HTTP :18880
  - internal MUD :14800 by default
          |
          | loopback HTTP + internal token + lease capabilities
          +------------------+------------------+
          v                  v                  v
      worker w01         worker w02         worker w03
      HTTP :18881        HTTP :18882        HTTP :18883
      MUD  :14801        MUD  :14802        MUD  :14803
```

For `N` workers:

- Active: one coordinator Pike plus `N` worker Pike processes. With three workers, four Pike processes.
- Shadow: one authoritative legacy Pike on `13800/8888`, one coordinator Pike, plus `N` workers. With three workers, five Pike processes.
- Tomcat is an additional process in the unified container.
- The gateway is part of the coordinator Pike. Do not add a second Python or standalone gateway lifecycle.

Node roles are selected by `XIAND_NODE_ROLE=standalone|gateway|worker`. Worker identity is `XIAND_WORKER_ID=wNN`. Worker processes bind internal listeners to `127.0.0.1`; Docker publishes only the historical public ports.

## Request routing and concurrency

`pike_gateway.pike` owns public admission in active mode. It never executes a player command locally.

1. Snapshot the request path, query, body, and allowed headers.
2. Parse identity consistently from `userid`, `character_id`, `auth_userid`, account token, or `txd`. Reject conflicting valid identities.
3. Resolve character to authoritative account identity.
4. Acquire the account-sharded lock. There are 4096 deterministic lock shards. Acquire two-account locks in stable shard order for admin recharge. Use a dedicated global auction lock for auction commands.
5. Check that routing is ready and acquire/renew the character lease.
6. Proxy exactly once to the selected worker with:
   - internal token;
   - worker id;
   - userid and lease epoch;
   - random request id;
   - account owner and cache capability;
   - optional signed admin target capability.
7. Require the worker to echo the accepted request id and prove the request reached `done` before releasing the account lock.
8. Reconcile the player's actual post-command affinity and complete any move.

Public request work runs in a bounded `Thread.Farm`, but per-account transaction locks preserve causality. The default pending limit is 128. Each target worker also has its own bounded bulkhead and short transport-failure circuit, configurable with `XIAND_GATEWAY_MAX_REQUESTS_PER_WORKER`. Routing pause, total saturation, worker saturation, and an open worker circuit return controlled `503` responses. A pre-start bulkhead rejection is not an uncertain mutation; a transport failure after dispatch remains globally quarantined. Do not make either queue unbounded and do not reroute uncertain writes.

A coordinator-cold account token is resolved by authenticated loopback RPC on the primary worker. Use only the short account-session resolver lock for that lookup; never acquire all 4096 character lock shards for one missing or expired token.

Recovery, handoff arrivals, social fan-out, and online/auction housekeeping run in separate maintenance lanes. Safe shutdown counts these operations alongside active and pending public requests so no worker save fence can race background mutation.

If the HTTP result is uncertain after a request may have started, quarantine `(worker, request_id)`, pause global routing, ask the worker for completion state, and inventory all workers before reopening. Never blindly replay a mutation.

Worker RPC accepts only loopback callers with a matching `XIAND_WORKER_TOKEN` and exact routing capabilities. Strip hop-by-hop, framing, and internal capability headers from proxied responses.

## Room placement

`map_workerd.pike` assigns an affinity, not an individual object, to one worker.

- Static room affinity: top-level directory below `gamelib/d`, such as `wugongdong`.
- Home affinity: one `home` consistency domain because `HOMED` owns a shared snapshot.
- Dungeon affinity: `<fb-directory>:<term-or-player-instance>` when the directory begins with `fb_` or ends with `_fb`.
- Timed event affinity: one `timed_event` consistency domain because the scheduler owns one shared session snapshot.
- First login before a real room exists: temporary `session:<digest>` affinity.

All users in the same shared static map affinity resolve to the same worker, so they can see and interact with one another. Never hash a shared room by userid.

Runtime placement is `load_aware_rendezvous`:

- stable SHA-256-derived rendezvous score preserves ownership;
- live player, active room, pending command, and heartbeat cost reduce the score;
- assigned map-directory weight reduces effective remaining capacity;
- configured worker capacity lets larger nodes receive proportionally more weight;
- current healthy assignments remain sticky unless forced.

Cold start combines each top-level map directory's static file count with a privacy-safe online-popularity EWMA. The coordinator derives counts only from its already verified coherent online snapshot; `affinity_heat.json` stores affinity names and integer aggregate scores, never user ids. Recent restored leases seed first deployment so a restart does not forget current hotspots. Apply the heat-driven cold bin packing at most once per coordinator topology lifetime; later catalog installation/recovery must preserve that already-durable placement instead of incrementing generations again.

Heartbeat placement pressure includes player/room counts, command backlog, command activity, heartbeat/backend lag, and CPU. Admin status exposes these values plus save latency/failures and the highest effective-weight affinity. They are placement and diagnosis signals, not permission to migrate an active room.

For a proven-cold worker inventory, sort affinities by effective weight and use capacity-normalized least-loaded bin packing; use rendezvous only as a deterministic tie-break. This keeps several heavy/popular maps apart. A topology-size change must fail closed unless every worker reports zero in-flight requests and zero local players. Heat-driven catalog remapping is also cold-only. Normal requests keep current assignments sticky, and runtime admin rebalance still skips affinities with active/frozen leases or prepared handoffs. Never live-move a room object merely to improve balance.

Changing `worker_count` is not a hot-add operation. Stop the current topology safely, update persisted configuration, and apply/start the new topology.

## Character movement

`user.pike::move()` calls `MAP_WORKERD->guard_local_player_move()` before `move_object()`.

- Same affinity: move normally.
- Different affinity owned by the same worker: complete the room move, then rebind the lease affinity under the same epoch.
- Different worker: record a pending redirect and let the coordinator run a fenced handoff.
- Saved login room conflicting with an exact arrival capability: suppress the stale saved move.
- Player in a team: require a complete primitive team snapshot; install it on the target before source release, otherwise reject the move.
- Dynamic clone path that cannot be reconstructed as a safe static room: fail closed.

Cross-worker handoff sequence:

```text
coordinator begin_handoff
  -> freeze source lease and persist prepared handoff
  -> source local_release
       -> verify epoch/control/request fences
       -> save character atomically
       -> retire in-memory source without another save
  -> coordinator commit_handoff
       -> owner=target, epoch=source+1
       -> persist exact arrival room capability
  -> target local_arrival
       -> load the one shared archive
       -> install account/cache/epoch capabilities
       -> enter exact room
  -> coordinator acknowledge arrival
       -> clear pending arrival capability
```

Abort a prepared handoff only while the exact source lease can be thawed. Use idempotency keys and validate every replay against original userid, source epoch, target affinity, and target room.

Background moves caused by timers are polled and settled by the coordinator, not left to browser refresh. A lost response keeps the committed arrival in a retry map until exact acknowledgement.

Never use the original public gameplay request as the arrival transport. A movement command has already completed its costs, cooldowns, and other durable effects on the source worker. Materialize every committed cross-worker arrival through the authenticated, idempotent `local_arrival` RPC and its exact userid/epoch/affinity/room proof. If the client needs an immediate destination page, issue only a shape-compatible `look` refresh for `/api`, `/api/html`, or `/api/json`; collapse duplicate `cmd` fields in query/form/JSON input and never replay the original direction, trade, gift, auction, item, or admin command. Unsupported response shapes keep the already completed source response and catch up on the next ordinary refresh.

## Persistence and anti-clone fences

There is one player data location. In Docker, host `/usr/local/games/allxd/<GAME_AREA>/data_xiand` mounts to `/app/xiand/data_xiand`. Every process sees the same archive tree; no process receives its own copy.

The control plane persists primitive routing state to:

- `data_xiand/map_workers/control_plane.json`;
- `data_xiand/map_workers/control_plane.json.bak`;
- `data_xiand/map_workers/affinity_heat.json` and its validated backup for heuristic aggregate map heat;
- `data_xiand/map_workers/config.json` for desired topology.

The authoritative control snapshot contains placements, player leases, handoffs, envelopes, escrow state, and PK session primitives. It never replaces player archives. Validate every restored field and capacity count; reject incomplete/corrupt generations and use only a validated backup. Heat is deliberately a separate bounded heuristic snapshot: if neither generation validates, discard it and retain the authoritative placements.

Control snapshots remain serialized and atomically replaced with a validated backup. Coalesce scheduled writes under the persistence mutex and expose attempt/failure, latency, and byte metrics. Do not replace this with an unreviewed WAL or async authority grant: placement/lease authority is usable only after its exact durable snapshot succeeds.

Before any worker save, require one of:

- live local control lease plus exact local character epoch;
- current accepted request save fence;
- coordinator-issued handoff/shutdown save capability.

If a worker loses control, it fences player activity and blocks ordinary saves. Recovery discards stale in-memory copies without saving them. Lease expiry alone never proves an old process stopped; retain expired leases as ownership tombstones until full inventory reconciliation.

Account wallet/storage/character/pet caches are process-local views of shared files. The gateway supplies an account cache token; a worker invalidates these caches when the token changes. Preserve the account-level lock identity so shared-account professions cannot write concurrently on different workers.

## Cross-worker and global features

Current integrated behavior:

- Online users: collect per-worker exact `(userid, worker, epoch)` snapshots, validate against coordinator leases, and publish a coherent aggregate to workers/admin UI.
- Friend/online teleport: render from that coherent aggregate, filter every row by logical zone and faction, accept only static `/gamelib/d/` paths without clone suffixes, then reuse `qge74hye` and the normal fenced player-move handoff. A stale or incomplete aggregate fails closed instead of falling back to local `users()`.
- Private chat: stage a source-worker social event, route the target through its exact lease, and apply once on the target worker.
- Team state: distribute invitations, membership snapshots, team chat, and notices through event ids and worker replicas. Movement carries the primitive team snapshot before source retirement.
- World broadcast: stage a durable event and fan it out to every healthy non-source worker with idempotent delivery receipts.
- Admin recharge: resolve target account and worker, lock manager and target accounts in stable order, sign the target capability, execute idempotently, and invalidate account caches across workers.
- Auction: serialize auction commands with a gateway-global lock; scheduled settlement runs only through the primary worker (`w01`) under coordinator control.
- Direct gift/trade: same-room exact characters may transact through the gateway's stable two-account lock and `player_transferd` atomic dual-save path.
- Homes, summons, and timed events: carry only explicitly reconstructable state and preserve single-owner affinity.
- Global legacy manager files/schedulers: run only on the primary/authorized owner, not independently on every worker.

Current fail-closed behavior:

- direct gift/trade across rooms or workers is disabled;
- team movement without a complete source snapshot is disabled;
- dynamic clone destinations without a reconstructable arrival path are disabled;
- social delivery fails when any required worker/lease/event proof is stale or unavailable.

Envelope, escrow, and PK-session primitives in `map_workerd.pike` are foundations, not proof that every gameplay command is integrated. Trace command-level usage before claiming support.

## Recovery and failure model

The coordinator monitors each worker every five seconds and maintains:

- worker incarnation generation;
- heartbeat and load metrics;
- exact live lease inventory;
- control heartbeat;
- coherent online snapshots.

Normal safe stop enters `draining`, pauses admission, waits for public and maintenance work, reconciles inventories, and installs a bounded worker save fence. If preparation fails before process stop, the coordinator sends idempotent cancellation to every expected live worker because a successful fence response itself may have been lost. Routing resumes only after all cancellations and inventory reconciliation prove a clean state. Failover ambiguity remains paused and failed closed.

A recovered coordinator registers workers, distributes one placement generation, inventories all local players, renews exact owners, and discards duplicates. A recovered worker remains control-fenced until coordinator reconciliation succeeds.

Docker supervisor behavior after three failed health probes:

- Shadow: legacy remains authoritative; stop/degrade the shadow cluster and write runtime mode `shadow-degraded`.
- Active: write persistent `data_xiand/map_workers/fallback-latched`, safely quiesce reachable workers, then start the legacy main and write `legacy-fallback`.

This is whole-cluster fallback, not per-request rerouting from a failed worker to legacy. The latch prevents automatic return to active after restart. Remove it only after operator audit proves no unresolved owner, request, handoff, or arrival.

## Compatibility contract

Never modify the public `txd` format. Existing bookmarks must continue to work.

- Vue continues to call the historical public HTTP API port.
- Legacy JSP proxies through `/legacy_api.jsp` and passes authenticated `txd` unchanged across rendered links.
- Initial username/password legacy login may generate a complete stored-password token.
- Literal `~dummy` tokens must remain rejected; do not restore compatibility by weakening authentication.
- Async request ids are bound to the authenticated userid; reject cross-user result access.
- Opaque `c_...` UI command tokens are resolved only on the worker/epoch that created them.

Test old JSP, Vue JSON endpoints, async endpoints, and bookmark-style URLs after routing or renderer changes.

## Adjacent dynamic-NPC balance contract

This is a gameplay contract stored beside the architecture work, not part of placement:

- `query_dynamic_npc_defense_scale()` keeps level 100 at 1x, reaches the historical integer `player_defense^0.3` multiplier at level 120, and remains monotonic.
- `query_dynamic_npc_life_scale()` keeps level 100 at 1x, lowers the 101-121 life transition, and reaches the same historical multiplier at level 122.
- Preserve custom NPC life overrides, rewards, player damage formulas, and elite/Boss 3x/6x multipliers.
- Validate with `test_unit/test_dynamic_npc_scaling.pike`; never tune this curve as a worker-capacity optimization.
