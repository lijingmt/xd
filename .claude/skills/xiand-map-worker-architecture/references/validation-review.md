# Validation and Review Reference

## Contents

1. Mandatory validation order
2. Test matrix
3. Player-flow scenario
4. Ten-dimension review
5. Log review
6. Push checklist

## Mandatory validation order

Run validation from the repository root. Do not reset unrelated runtime/player files.

1. Inspect scope:

```bash
git status --short --branch --untracked-files=no
git diff --check
git diff --stat
```

2. Run shell/static contracts for touched deployment code:

```bash
bash -n scripts/setup_deploy_env.sh
bash -n scripts/bootstrap_map_worker_runtime.sh
bash -n scripts/map_worker_cluster.sh
bash -n docker/start-unified.sh
bash tools/map_workers/test_bootstrap.sh
bash tools/map_workers/test_startup.sh
```

3. Run the real server restart/TestUnit path:

```bash
./restart-local-workers.sh --workers 3
```

Confirm the internal TestUnit summary, not merely standalone Pike compilation. Expected architecture suites include:

- `test_unit/test_map_worker_architecture.pike`;
- `test_unit/test_pike_gateway.pike`;
- `test_unit/test_docker_mud_startup.pike`;
- `test_unit/test_friend_teleport_workers.pike`;
- `test_unit/test_dynamic_npc_scaling.pike` when the adjacent level transition changes;
- persistence/security/account regression suites touched by the change.

4. Check live cluster health:

```bash
scripts/map_worker_cluster.sh status
scripts/map_worker_cluster.sh health
```

5. Test HTTP behavior and compatibility in the actual configured mode.
6. Inspect all relevant logs after the test timestamps.
7. Repeat after every fix. Do not reuse an earlier green result after source changes.

## Test matrix

### Placement

- Same static top-level map always maps to one worker.
- Home visitors map to the home's owner affinity.
- Separate dungeon/timed-event instances may distribute without splitting one instance.
- Traversal, clone suffixes, invalid separators, and unsafe room paths fail closed.
- Weighted placement uses every healthy worker and remains sticky.
- Drain excludes new placement but does not force active player migration.

### Identity and concurrency

- Query, form, JSON, Vue, and legacy JSP resolve one character identically.
- Conflicting userid fields are rejected.
- Shared-account characters serialize on the same account lock shard.
- Two-account operations acquire locks in stable order.
- Auction uses one global cluster lock; ordinary commands do not.
- Admission is bounded and returns controlled `503` under pressure.
- One saturated worker opens only its own bulkhead/circuit before dispatch; another healthy worker remains serviceable.
- A cold or expired account token never locks all 4096 character shards.

### Request fencing

- Internal RPC without token, wrong token, non-loopback origin, wrong worker, wrong userid, or stale epoch is rejected.
- Worker response must contain exact accepted request proof.
- Gateway waits for `done` before releasing the account lock.
- Timeout after possible execution creates uncertain state and pauses routing.
- Recovery inventories all workers before clearing uncertain state.

### Movement and storage

- Same-worker move rebinds affinity without epoch drift.
- Cross-worker move executes the player command once.
- Source saves before retirement; source stale object is discarded without saving.
- Target loads only after persisted epoch ownership.
- Arrival room must match the signed static path and affinity.
- Lost response retries arrival idempotently.
- Team movement requires a complete primitive snapshot on source and target; missing snapshots and unreconstructable dynamic rooms fail closed.
- Save/load across restart preserves inventory, account owner, pets, wallet, home, summons, and last room.
- No second archive location or per-worker copy exists.

### Global operations

- Online aggregate contains no duplicate userid and matches exact leases.
- Friend/online list uses the coherent aggregate, preserves logical-zone/faction visibility, rejects unsafe room paths, and routes teleport through the normal player handoff.
- Private chat reaches the exact remote owner once; durable team/broadcast events survive retry without duplicate delivery.
- Admin recharge handles online/offline target, idempotent replay, bonus save, and cache refresh.
- Same-room direct gift/trade uses stable two-account locking; old links cannot bypass the cross-room/cross-worker boundary.
- Auction scheduled tick runs exactly once and never from shadow workers.
- Global daemons/files are not eagerly mutated by every worker.

### Compatibility

- Vue endpoints remain unchanged.
- Legacy username/password login renders a valid full `txd`.
- Subsequent legacy links preserve the authenticated incoming `txd`.
- Existing full-token bookmarks still work.
- Literal `~dummy` remains rejected.
- Async result ids are bound to their authenticated userid.
- Opaque `c_` commands resolve only on the issuing worker/epoch.

### Lifecycle

- Local one-click restart runs full TestUnit before cluster start.
- Docker entrypoint starts the correct process count for disabled/shadow/active.
- Only historical public ports are published.
- Safe stop pauses routing and drains all accepted/uncertain/background work.
- Safe stop drains maintenance lanes, releases pending admission when processing settles, and cancels every possible worker save fence after an aborted normal stop.
- Worker/coordinator stop refuses force kill when save proof is missing.
- Worker failure opens the correct shadow/active fallback path.
- Active fallback latch prevents automatic active restart.
- Coordinator-only recovery requires all workers and reconciles inventory.

## Player-flow scenario

Validate from a player's perspective:

1. Login through Vue and old JSP using the same existing account.
2. Read `myhp`, inventory page 1/next page, equipment, skills, and room view.
3. Start automatic combat and let it continue with the browser backgrounded/minimized.
4. Enter combat; verify the main view continues updating.
5. Kill monsters, receive drops/experience/currency, consume medicine, and save.
6. Move within one affinity, then cross into an affinity owned by another worker.
7. Verify the movement response is the destination view, not the stale source view.
8. Have a second player enter the same map and verify both converge to one worker and see one another.
9. Put the second player on a different worker, open the online/friend list, and use its teleport button; verify the actor migrates once and arrives in the target's static map.
10. Restart safely; verify both archives load once with no lost or cloned equipment, then check admin online count and recharge routing for online/offline targets.

Do not change combat/economy expected values while testing architecture. Compare damage and reward formulas to `main` when a regression is reported.

## Ten-dimension review

Perform all ten passes and record concrete evidence:

1. **Scope:** intended files only; unrelated data/dist files excluded.
2. **Syntax/runtime:** Pike historical precedents, shell syntax, config schema, image entrypoint.
3. **Identity/auth:** userid conflicts, account resolution, `txd`, token, internal capabilities.
4. **Placement:** affinity definition, sticky ownership, topology generation, scaling behavior.
5. **Concurrency:** account lock order, auction/global locks, bounded queues, no deadlocks.
6. **Persistence:** atomic save/control snapshots, cache invalidation, restart/load, one archive location.
7. **Movement:** same-worker rebind, prepare/release/commit/arrival/ack, replay and background paths.
8. **Failure:** timeout, worker loss, coordinator loss, partial startup, safe stop, fallback latch.
9. **Compatibility:** Vue, old JSP, old bookmarks, async, opaque command links, logical zones.
10. **Operations/security:** secret handling, port exposure, owner/mode, logs, image/tag/platform, rollback.

If a pass uncovers a defect, fix it, rerun all affected validation, and repeat the ten-pass review from the beginning.

## Log review

Inspect new lines after the final restart in:

- `log/stderr.13800` or `log/pike.log` for standalone;
- `log/map-workers/<area>/runtime.coordinator.log`;
- every `log/map-workers/<area>/runtime.wNN.log` and corresponding `log/stderr.<port>`;
- `log/map-worker-monitor.log`;
- `log/map_worker_admin.log` when admin operations ran;
- `log/tomcat.log` for JSP tests;
- transaction-specific logs for recharge, auction, save, or equipment work.

Search at minimum:

```bash
rg -n "TESTUNITD|failed=|失败|ERROR|Error|Backtrace|Attempt to call|undefined|NULL|P0|SAVE_FENCE|REQUEST_FAILED|CONTROL_FENCE|uncertain|fallback" log
```

Distinguish intentional security-test denials from unexpected production-path denials. Count only lines after the current test start when comparing regressions.

## Push checklist

- Confirm final TestUnit has zero failures attributable to the branch.
- Confirm shell fixtures and health pass after the last edit.
- Confirm no secrets, `.env`, player data, generated frontend files, or runtime logs are staged.
- Review `git diff --cached --check` and `git diff --cached`.
- Use an English conventional commit message.
- Push only the feature branch unless the user explicitly requests a merge.
- Verify local and remote feature branch hashes match.
- Verify `main` and `origin/main` remain unchanged when no merge was authorized.
