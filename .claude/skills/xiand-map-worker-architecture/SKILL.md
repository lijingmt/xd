---
name: xiand-map-worker-architecture
description: Maintain, review, test, deploy, or troubleshoot Xiand's Pike map-worker architecture in /usr/local/games/xiand. Use for coordinator/gateway, map_workerd, room affinity and placement, cross-worker movement or friend teleport, player leases, save fencing, worker scaling, shadow/active modes, Docker or local multi-worker startup, failover, legacy JSP/txd compatibility, admin worker controls, online/presence aggregation, cross-worker social features, or equipment-duplication boundaries.
---

# Xiand Map Worker Architecture

## Preserve these invariants

Treat every change as unsafe unless all invariants remain true:

1. Keep one room and all objects in it inside one Pike worker. Never mutate world objects in a generic thread pool.
2. Route one map affinity to exactly one worker. Players entering the same shared map must reach the same process.
3. Give one character archive exactly one live worker owner. Treat `(worker_id, lease_epoch)` as the equipment anti-clone fence.
4. Keep character/account/pet/wallet data in the existing shared `data_xiand` tree. Do not create per-worker player stores.
5. Persist placement, leases, and handoff state before granting authority to load or save a character.
6. On ambiguity, pause or reject traffic. Never retry a possibly executed mutation on another worker without reconciliation.
7. Preserve all public URLs, `txd` encoding, old bookmarks, Vue requests, and legacy JSP behavior.
8. Keep worker/control ports on loopback and authenticate internal RPC with `XIAND_WORKER_TOKEN`.
9. Stop safely: pause admission, drain requests, reconcile uncertain work, fence saves, then stop workers. Never force-kill an owner that may still save.
10. Do not change combat formulas, economy rules, or gameplay values as part of architecture maintenance.

## Read the required reference

- Read [architecture.md](references/architecture.md) before changing Pike routing, movement, persistence, account locks, admin operations, or cross-worker gameplay.
- Read [deployment-operations.md](references/deployment-operations.md) before changing `.env`, Docker, local startup, ports, worker count, health checks, fallback, or production procedures.
- Read [validation-review.md](references/validation-review.md) before editing or pushing this branch. Follow its test matrix and failure review.

## Locate the implementation

Use these files as the primary sources of truth:

| Concern | Source |
|---|---|
| Control plane, affinity, leases, handoff, escrow primitives | `gamelib/single/daemons/map_workerd.pike` |
| Embedded coordinator/public proxy | `gamelib/single/daemons/_http_api_mod/pike_gateway.pike` |
| Authenticated loopback worker RPC | `gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike` |
| HTTP role initialization | `gamelib/single/daemons/http_api_daemon.pike` |
| Player move/save/arrival fences | `gamelib/clone/user.pike` |
| Process lifecycle | `scripts/map_worker_cluster.sh` |
| Local restart + real TestUnit | `restart-local-workers.sh`, `scripts/restart_map_workers_with_testunit.sh` |
| Docker lifecycle | `restart-all-docker.sh`, `restart-docker.sh`, `docker/start-unified.sh` |
| Persistent desired configuration | `data_xiand/map_workers/config.json` |
| Admin UI | `gamelib/cmds/mgr_map_workers.pike`, `gamelib/cmds/game_deal.pike` |
| Online/friend teleport UI | `lowlib/wapmud2/inherit/feature/qqlist.pike`, `gamelib/cmds/qge74hye.pike` |
| Regression contracts | `test_unit/test_map_worker_architecture.pike`, `test_unit/test_pike_gateway.pike`, `test_unit/test_docker_mud_startup.pike`, `test_unit/test_friend_teleport_workers.pike` |

Do not trust older Python gateway artifacts or documentation. The active implementation embeds the gateway in the coordinator Pike process; there is no Python gateway runtime.

## Apply the change workflow

1. Inspect the branch, dirty files, and `main...HEAD`. Preserve runtime/player changes not owned by the task.
2. Classify the change: placement, request fencing, handoff, persistence, deployment, compatibility, or operations.
3. Trace the full causal path, including failure and restart paths. A happy-path-only patch is insufficient.
4. For Pike edits, use `pike-coding-guard`, `pike9-syntax`, and `pike-code-review`. Find historical syntax precedents before writing.
5. Add or update a focused TestUnit contract. Add shell fixture tests for shell-only behavior.
6. Run static checks, shell self-tests, real local restart/TestUnit, cluster health, endpoint tests, and log inspection.
7. Review all ten dimensions in [validation-review.md](references/validation-review.md).
8. Commit only intended source/tests with an English conventional commit. Push the feature branch; do not merge this architecture branch to `main` unless the user explicitly changes that decision.

## Enforce current release boundaries

- Ship examples as `enabled=0`, `traffic_mode=shadow`, `worker_count=3`; preserve an existing host's persisted configuration instead of resetting it.
- Treat `shadow` as the safe observation mode: legacy single-process remains authoritative; the coordinator and workers receive no player traffic.
- Active mode is implemented and may run a controlled production trial with a configured worker count. Still require `XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only`, a healthy full topology, and no persistent fallback latch.
- Keep player direct gift and face-to-face trade disabled in distributed mode until durable cross-worker transactions are integrated end to end.
- Cross-worker private chat, team invitations/snapshots/chat/notices, and world broadcast use the durable social-event pipeline. Preserve event ids, outbox durability classes, gateway fan-out, and idempotent worker delivery.
- Permit a team member's cross-worker movement only when the source has a complete primitive team snapshot and the target installs it before source release; otherwise fail closed.
- Build player/friend presence from the coordinator-verified cluster snapshot. Never use local `users()` or `find_player()` as proof that a remote player is offline.
- Friend teleport must resolve to a validated static `/gamelib/d/` room and then use `qge74hye -> user::move() -> guard_local_player_move()`. Reject clone paths, logical-zone violations, incompatible factions, stale snapshots, and unavailable owners.
- Do not remove a `fallback-latched` file merely to make startup pass. Audit the failure and control-plane/player inventories first.

## Keep adjacent balance changes separate

The authorized dynamic-NPC transition currently smooths combat attributes through level 120 and life through level 122, reducing levels 101-121 without changing player damage, custom NPC life, rewards, or elite/Boss 3x/6x multipliers. Maintain it in `lowlib/mudlib/inherit/npc.pike` and `test_unit/test_dynamic_npc_scaling.pike`; do not couple this gameplay curve to worker placement or load balancing.

## Report precisely

State:

- mode and process count;
- desired versus running worker count;
- restart path used;
- TestUnit summary and shell tests;
- endpoints and legacy JSP/txd checks;
- logs inspected and new error counts;
- unresolved trial limitations;
- branch/commit/push status and whether `main` changed.

Never claim `restart-all-docker.sh` tested a branch image if it actually pulled a different remote `latest`.
