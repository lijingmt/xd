# Ten independent review passes

Record evidence and defects separately for every pass. A repeated grep is not a
new pass.

1. **Creation and persistence** — race and independent profession selection,
   starter state, 1/30/80/120 growth, save/restore, migration idempotency,
   invalid arguments, reconnect, default identity, death/logout cleanup.
2. **Attributes and balance** — levels 1/30/80/120+, health/mofa, damage,
   defense, accuracy, avoidance, criticals, penetration, PvE/PvP/Boss caps.
3. **Skills and books** — every file loads, cold-registry passive learning,
   unlearned active rejection, all stages, prerequisites, profession/level/
   duplicate rules, inventory action, consumption, shops, teacher and cooldown.
4. **Class mechanic edge cases** — server-owned inputs, solo/team, weaker and
   stronger recasts, movement, target/team changes, stale objects, leader
   changes, death, expiry, repeated casts, disconnect, reload, cross-room/team,
   AOE cleanup, PvP/Boss/pet caps, client serialization and reward attribution.
5. **Equipment and economy** — starter/dynamic/Boss gear, wear/remove, forge,
   sell/store/trade/destroy, four recovery-item families, capacity, failed
   pickup recovery, currency conversion and reward abuse.
6. **Tasks and world progression** — beginner guide, every level band, task NPC,
   navigation, continuous growth tasks, maps, monster gaps, dungeons, level
   70/120+/999, hidden pool/rate growth, ownership and drop-path cardinality.
7. **Social and shared systems** — team, guild, home, ranking, honor, chat,
   friends, PvP, faction rules, VIP, feedback, admin, online labels and idle
   behavior.
8. **Frontend and accessibility** — legacy UI and Vue, responsive layout,
   identity/logo/distinct gender avatars and both mirrors, actionable errors,
   battle status, skill animation, refresh, login/session compatibility,
   request overlap, container copy and cache-busted assets.
9. **Concurrency, performance, and security** — same-player serialization,
   shared transaction locks, bounded workers/queues, timeouts, cleanup, heartbeat,
   rate/body/command limits, malformed and concurrent requests, idle CPU, and
   proof that read-only HTTP polling cannot keep an abandoned session alive.
10. **Release proof** — run the static audit with race/hidden/assets expectations,
   review diff and staged paths, compile historical Pike patterns, targeted
   runtime tests, full restart/TestUnit, ports, HTTP load, logs, Vue build/test,
   regenerated/rendered handbooks, deployment artifacts, English commit and
   remote push.

Any failure returns to its owning pass and triggers the relevant regression test.
Completion means all ten pass after the final code change, not before it.
