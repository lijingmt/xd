---
name: xiand-illusion-realm
description: Maintain, audit, configure, test, or extend Xiand's monthly 幻境区 cycle system. Use for 新月幻境, S1 or later cycle IDs, 81-chapter seasonal stories, chapter task authoring, exploration stuck at 0/1, cross-Worker chapter arrivals, original AI chapter artwork, cycle-keyed permanent account entitlement, per-cycle character slots, illusion character creation, route chapters, rankings and duel honor, cycle-only maps and rewards, logical-zone or map-Worker isolation, shared-asset restrictions, lifecycle administration, end-of-cycle return to 永恒服, rollover, anti-cloning guarantees, or related Vue/JSP compatibility in /usr/local/games/xiand.
---

# Xiand Illusion Realm

## Preserve the model

Treat `S1` as the immutable first cycle ID and “新月幻境·S1” as its display
name. Use “幻境区” in player-facing Chinese; “season” is only an architectural
analogy.

If the shared runtime file is absent, only an `S1` draft may be created. A later
ID must roll over from an intact closed runtime; deleting runtime state is never
a valid shortcut to a new cycle.

Keep one ordinary player `.o` archive per character. An active illusion
character is identified by its account-index entry:

- `realm_type=illusion`
- `illusion_id=S1` (or the configured later ID)
- `illusion_state=active`

Returning to 永恒服 atomically changes that index entry to `realm_type=eternal`
and `illusion_state=returned`. Never copy a player archive, inventory, equipment,
warehouse row, or reward during settlement. This is the primary anti-cloning
invariant.

Also apply the Pike coding/review, TestUnit, Xiand development validation,
map-Worker, API transaction-lock, Vue playability, and English Git commit skills
when their surfaces are touched.

Before creating or revising an 81-chapter campaign, its task chain, or its
artwork, read [references/story-production.md](references/story-production.md)
completely and follow its production gates in order.

## Locate each layer

- tracked cycle config: `gamelib/etc/illusion_realm.json`
- tracked S1 story: `gamelib/etc/illusion_s1_story.json`
- tracked nine-volume storyboard atlases and 81 chapter illustrations:
  `images/illusion_s1/story/`
- shared runtime phase/audit: `data_xiand/illusion_realm/runtime.json`
- archived closed states: `data_xiand/illusion_realm/history/`
- validated merged content snapshots: `data_xiand/illusion_realm/content/<ID>.json`
- derived leaderboard snapshots: `data_xiand/illusion_realm/rankings/<ID>/`
- lifecycle/progress/reward/payment recovery: `gamelib/single/daemons/seasonal_chard.pike`
- cycle-keyed entitlement and realm identity: `gamelib/single/daemons/account_characterd.pike`
- logical interaction group: `_logical_zone_mod/policy.pike`
- map affinity: `MAP_WORKERD->query_affinity_key()` plus the static rooms under
  `gamelib/d/illusion_<id>/`
- account HTTP create/list API: `_http_api_mod/account_characters.pike`
- Vue account center: `vue_source/` only; rebuild generated clients with the
  repository build script
- player/admin commands: `gamelib/cmds/illusion_realm.pike` and
  `gamelib/cmds/mgr_illusion_realm.pike`
- focused lifecycle regression: `test_unit/test_illusion_realm.pike`
- mandatory all-profession journey regression:
  `test_unit/test_illusion_realm_all_professions.pike`
- post-teleport action regression:
  `test_unit/test_illusion_realm_task_navigation.pike`
- personal difficulty matrix: `test_unit/test_personal_difficulty.pike`

Do not commit runtime JSON, account indexes, player saves, logs, Worker state, or
other generated data.

## Lifecycle workflow

Use the monotonic phases only:

`draft -> registration -> active -> settling -> closed`

Manual registration/start/end-time/rollover mutations must use the admin preview
followed by its SHA-256 confirmation. Once `ends_at` is reached, every node runs
the same idempotent automation and persists `active -> settling -> closed` under
the interprocess lock. It settles local online characters before and after close;
offline characters settle on their next real login. The shared runtime file uses
a revision, bounded audit list, temp file, backup, and atomic rename. Never edit
it manually while processes are running.

For S1:

1. Verify `current_id` is exactly `S1`, duration is 30 days, entry/return rooms
   load, nine volumes contain exactly 81 ordered chapters, active-day data is
   analytics-only and never gates progression, 25 key story events are intact,
   all nine atlases load, chapter rewards total
   exactly ten pieces, and both route arrays contain exactly three challenges.
2. Run `mgr_illusion_realm`, preview `open_registration`, then confirm.
3. Let players activate the S1-specific account entitlement for free. It is
   cycle-keyed: S1 entitlement must not unlock S2. Keep the configured zero
   entitlement price while retaining idempotent account-index auditing.
   Character capacity is separate and is never free: each seasonal character
   slot costs 100 jade, or five slots cost 500 jade. Existing early S1
   characters are grandfathered without retroactive charges or deletion.
4. Preview `start`, confirm, and verify `ends_at-starts_at=30*86400`.
5. Let natural expiry enter automatic return settlement. To end early, preview
   and confirm a new `ends_at`; do not create a second manual settlement path.
6. Confirm players retain the same character ID and `.o` archive after return.
7. Confirm the system reaches `closed` automatically and retains the runtime
   audit/history.

Never auto-open, auto-repeat, or clone the previous cycle after `closed`. The
eternal world must continue normally until new characters, quests, equipment,
maps, and balancing are ready and an administrator explicitly starts the next
cycle.

For a later cycle:

1. Close the old cycle first.
2. Add the new static map/NPC content and change the tracked config to a new
   permanent uppercase ID such as `S2`. Never reuse or rename an old ID.
3. Complete a full restart so every Worker loads the same new config.
4. In `mgr_illusion_realm`, preview rollover and confirm the old/new IDs and
   population counts.
5. Apply rollover. It archives the old runtime and creates the new `draft`.
6. Continue with registration and start.

`closed_ids` allows old offline characters to return lazily after rollover. The
login hook must run seasonal reconciliation before shared storage/wallet
reconciliation. On their next login, settle the unique old archive directly to
永恒服; never route an old-cycle character into the new cycle.

The runtime reader must validate `runtime.json` before using it. If it is
missing, truncated, oversized or invalid and `runtime.json.bak` is a valid state
for the configured cycle, atomically restore the primary from that backup and
continue from the recovered revision. Create a fresh S1 draft only when neither
primary nor backup exists on a genuine first install. If a backup exists but is
also invalid, fail closed; never silently reset an active or closed cycle.

## Configuration rules

Keep gameplay content data-driven:

- derive the active map prefix from `entry_room`;
- configure three `pioneer_secrets`, three distinct `hunter_bosses`, and the
  `companion_team_kills` target;
- validate all paths, IDs, messages, counts, duration, cost, and chapter fields;
- keep rooms and configured secrets/NPCs inside the cycle's dedicated
  `illusion_<lowercase-id>` directories, and require every configured file to
  exist before enabling the daemon;
- require chapter IDs to be the ordered `<ID>-C1...Cn` sequence;
- for S1 require exactly nine volumes of nine chapters, 81 unique chapter
  titles, active-day metadata from 1 through 7 for analytics only, and exactly
  25 configured story events whose chapter, kind, Chinese location label and canonical room/NPC
  path agree;
- keep story prose in the separate tracked story JSON and require its immutable
  ID/title/premise to match the cycle config before flattening it at startup;
- require five authored opening paragraphs and three authored completion
  paragraphs per chapter; preserve their line breaks at runtime and reject
  generic filler or a malformed chapter instead of silently repairing it;
- after all 81 ordered claims, expose the cycle's ten-question comprehension
  quiz one question at a time. Keep answer keys daemon-private, save each answer
  on the unique character archive, reject stale/replayed submissions, retain the
  best score across retries, and use non-economic titles plus a perfect-score
  epilogue so the quiz cannot become a farming loop;
- keep one original square 3x3 atlas per volume for the volume index and one
  independently rendered `chapters/chapter_NNN.png` for each chapter. Chapter
  prose emits only `[storypic 1..81:/xd/images/illusion_s1/story/chapters/chapter_NNN.png]`;
  the JSON API, Vue, every legacy HTML filter, build script, and Docker image
  must reject traversal, mismatched chapter/path pairs, and out-of-range IDs;
- keep one primary `illusion_realm next` action on every open chapter. It must
  route only to the current allowlisted target, reload progress after successful
  movement, render a bounded-hunt autofight action for hunt objectives, render a
  direct boss action for boss objectives, render an explicit “完成当前探索”
  action for exploration objectives, always render return-to-game, show per-kill
  chapter progress, claim only a ready ordered chapter, and lead directly into
  the next chapter. The current-progress page, chapter detail and post-claim
  follow-up must detect when the player is already in the exact canonical target
  room and immediately render the hunt, boss or exploration action; requiring a
  second “下一步” click only to reveal that action is a regression. A generic
  location-only success page or repeated travel link after the player is already
  in the exploration room is also a regression. Legacy explicit commands remain
  compatible;
- place S1's long-term collection gates at the end of all nine volumes
  (chapters 9/18/27/36/45/54/63/72/81), not as three isolated late patches.
  Store probabilities as integer basis points over 10,000 so sub-percent rates
  never round to zero. The reviewed S1 curve is
  `1000/422/178/75/32/13/6/2/1` basis points, with hard pity at
  `10/24/57/134/313/770/1667/5000/10000` eligible kills. Chapter 81 is exactly
  1 in 10,000, not 1 percent or a floating-point approximation;
- require the configured story event before a gate can roll. Only the exact
  allowlisted NPC path in one of the configured canonical rooms may increment
  pity. A wrong monster, right monster in the wrong room, pre-event kill,
  duplicate death callback, Eternal-world kill, or another character's bound
  item must not advance or satisfy the gate;
- represent each gate reward as a saved physical task item bound to the exact
  registered-account owner. Disable drop, trade, gift, auction and both storage
  paths. Count the physical owner-matching item as authoritative, persist every
  eligible roll, and on clone/move/save failure destruct the new item and roll
  progress and pity back together. Previously claimed chapters stay
  grandfathered; never push an existing character backwards;
- keep bounded chapter autofight running after the ordinary kill quota while a
  gate remains incomplete. Once both the kill target and gate are complete,
  stop only the bounded chapter mode, wait for combat teardown, reset the view
  and execute `illusion_realm` so the player returns to the task page. Never
  stop ordinary continuous autofight. Test the 1..10000 roll boundaries through
  the production decision helper and use an environment-gated TestUnit pity
  primer for 12-profession journeys instead of performing hundreds of thousands
  of disk writes;
- require chapter reward counts to sum to exactly ten;
- fail closed if config or runtime state is malformed.

Keep S1 progression self-contained without changing Eternal-world formulas:

- derive chapter minimum level as `min(story_level_cap, chapter ordinal)`;
- after an ordered claim, top up only the missing experience required to reach
  the next chapter level, preserving all experience already earned from combat;
- cap S1 story growth at the configured level 69 equipment baseline;
- align the six training tiers to levels 1/10/20/30/40/50 and every key boss to
  its chapter level, capped at 69;
- include level, total/current experience, life, and mana in the same claim
  rollback as progress and cloned rewards. Never leave a level-up behind after
  a failed save;
- suppress the Newbie tutorial's automatic reward hook only while applying the
  transactional story level-up. A tutorial reward is outside the chapter
  rollback boundary and must remain manually claimable after the chapter saves;
- never change global experience, damage, monster, VIP, or profession formulas
  to make a cycle test pass.

S1 routes are intentionally different without changing combat formulas:

- 寻星: discover all configured hidden moon seals;
- 破阵: defeat all configured distinct guardian bosses;
- 同心: reach the configured same-team kill count.

Keep route choice immutable within a cycle. Reward claims must be ordered,
account-bound, save-before-success, idempotent, and rollback all newly cloned
items plus progress on failure.

## Preserve exploration credit across movement boundaries

Record a chapter visit only after the character has really reached the exact
canonical target room and all earlier chapter gates are complete. Preserve every
movement path that bypasses ordinary `user::move()`:

- ordinary same-process movement records through `user::move()` after `::move()`;
- a committed cross-Worker static arrival records in
  `complete_map_worker_arrival()` only after its exact arrival archive is durable
  and the local arrival fence has been consumed;
- a same-Worker static redirect records after its inherited move succeeds and
  the redirect is cleared;
- `travel_to_chapter_target()` must idempotently recover an older/stuck character
  who is already in the exact target room while `chapter_visit_rooms` is still
  empty. Do not require leaving and re-entering the map.

Never credit before a movement or handoff commit. If visit persistence fails,
roll back only the visit mutation, keep the proven room arrival, and let the next
current-room action retry safely. Do not duplicate chapter rewards, ranking visits,
or story events.

Keep this hook inert for Eternal characters. `record_room_visit()` must return
without mutation when `story_context(player)` is empty. Never change `TASKD`,
generic autofight routing, profession combat formulas, or ordinary-world quest
progress to repair an illusion chapter.

Expose current/required values and the configured Chinese location for the next
story event. This is guidance only: do not add a teleport that bypasses room
movement, boss ownership, previous-chapter gates, or map-worker routing. Test a
future echo before its previous chapter and require it to fail closed.

## Isolation rules

Assign all active characters from one illusion ID to `illusion:<ID>`. Do not
equate that logical group with a physical process. For S1, preserve the stable
affinities `illusion_s1:hub`, `illusion_s1:silver`, `illusion_s1:ruins`,
`illusion_s1:depths`, `illusion_s1:hunt_a`, `illusion_s1:hunt_b`, and
`illusion_s1:hunt_c`; unknown future rooms fail safely into
`illusion_s1:frontier` until deliberately classified. Keep the common camp in
`hub`, connected field chapters in separate groups, and every exact shared room
on exactly one owner Worker. Use the common worker pool rather than reserving a
fixed 4+4 split. Existing dungeon/team instance keys remain authoritative, so a
single instance converges without forcing the whole seasonal world into one
process.

While active, block access to eternal shared warehouse, shared recharge wallet,
shared pets, auction, all `home_*` commands and home-room movement, and cross-world
mail/trade/gift/team/combat/visibility. Do not create, clone, merge, or migrate a
seasonal home; the cycle camp is the rest point until the character returns.
Allow ordinary local trading only between characters in the same illusion
group; existing item binding rules remain authoritative. Do not weaken gateway
account locks or player-transfer transaction locks.

If an account index exists but both main and backup fail validation, assign a
unique unavailable group, freeze movement, and block shared assets. Never treat
that character as a legacy eternal account.

## Keep personal challenge out of routing

Personal challenge tiers are character-side PVE modifiers, not realms, logical
zones, room instances, affinities, or Worker partitions. Eternal and illusion
characters at different challenge tiers must still share the same room owner,
visibility, chat, teams, and PVP rules. Never add `personal_difficulty` to
`map_workerd.pike`, map-worker RPC, cluster scripts, room paths, dungeon keys, or
logical-zone identity.

Only apply the selected tier to that character's PVE outgoing/incoming damage,
personal eligible set-drop weighting, and personal AFK allowance. For a team
reward, use the lowest valid same-room participating tier so a high-tier member
cannot carry low-tier characters into unearned loot. Persist selection and
unlock progress on the unique player archive, save before success, and roll back
timestamps/progress when saving fails.

## Payment and settlement safety

Per-cycle permanent entitlement activation uses a player-saved two-phase
credential around the optional configured jade payment and account-index grant.
S1 is free, but the recovery path must remain correct if a later explicitly
reviewed cycle sets a nonzero price. On login:

- if entitlement exists with the same request ID, clear the stale credential
  without refunding;
- if entitlement exists under another/admin request ID, refund this request's
  duplicate debit before clearing it;
- if entitlement does not exist, restore the pre-payment physical/shared jade
  balances and clear the credential;
- if recovery validation or refund fails, retain the credential and fail closed
  for retry/audit.

Settlement saves the return position and inventory receipt before changing the
account index. Repeated settlement with the same valid lowercase SHA-256 receipt
must return `already=1`. Failed routing after settlement must leave a safe return
position for the next login; it must never recreate inventory.

Keep each cycle entitlement separate from paid character capacity. Legacy
global entitlements are S1-only and must never unlock S2. Entitlement activation
does not grant a free character: every seasonal character consumes one paid
slot. Store exact 100-jade single-slot and 500-jade five-slot purchases under
`season_expansions[illusion_id]`; never let S1 capacity leak into S2. Preserve
existing early characters without retroactive debit. Continue writing a
legacy-shaped, conservative S1 top-level mirror solely so rollback binaries
retain paid capacity, while the versioned per-cycle record remains authoritative.
Use bounded request-ID lists and the player-saved two-phase expansion credential
for cross-Worker retry and refund.

## Preserve closed content as Eternal Echoes

At startup, validate and atomically archive the merged config/story snapshot
for every published ID under `data_xiand/illusion_realm/content/`. Closed content
must remain addressable by its original ID after a later config is deployed.
Returned Eternal characters may enter a closed echo, traverse its maps, read the
81 chapters, and view frozen rankings. They must not enter an active cycle or
reset progress, claims, quiz rewards, set receipts, or ranking data. Ranking
publication stops for a closed echo; old snapshots are display-only.

The archive is runtime persistence and must not be committed. A future S2 still
requires deliberately authored and validated config, story, rooms, NPCs,
artwork, drop tables, and TestUnit updates; never silently relabel or clone S1
as new content.

## Ranking safety

Derive the six boards (journey, level, experience, duel honor, set, speed) from
small atomic JSON snapshots under the ranking directory. Never scan every full
player `.o` when a player opens a board. Treat the player `.o` as authoritative;
the JSON contains only bounded display/progress fields and may be regenerated
at login or a saved checkpoint. Normalize every missing legacy numeric field to
an explicit integer before JSON encoding—Pike's undefined integer can otherwise
become JSON `null`. Reject corrupt or truncated snapshots instead of displaying
a partial ranking, cap scans and output, cache briefly, and remove all TestUnit
snapshots during test cleanup.

Record duel honor only after an existing same-race duel win path has completed.
Keep the hook inside `catch`, never modify combat formulas, give zero points for
the same registered account or excessive level advantage, and apply per-opponent
100/50/20 daily decay. Reset this limit at Beijing midnight. Save the unique
player archive before publishing its snapshot. Ranking titles are idempotent,
bounded, display-only, and must never add combat attributes.

## Adjacent compatibility checks

Only allow `query_toVip()` equipment—not VIP consumables or materials—to pass
through personal plus account shared storage, and persist an explicit binding
marker so reconstruction cannot wash it clean. Keep gift, trade, and auction
binding checks unchanged. For batch alchemy, distinguish craft count from stack
capacity: a furnace remains capped at 100 while medicine stacks may hold 9999;
never truncate a legal combine count during move or storage restore.

In active Worker mode, eagerly load `viceflushd.pike` on Workers, never on the
gateway, wait for affinity assignments, and use stable slots plus
`local_worker_owns_room()` so artisan elite totals exist exactly once across the
cluster. Validate the live aggregate totals for 灵兔 and 灵猫 after restart.

The account center and all entitlement/settlement/creation mutations must read
the latest shared account index from disk. Hot movement/group checks may use the
Worker-local cache and rely on the gateway account-cache token during handoff.

## Required validation

1. Keep a 12-profession end-to-end matrix for 剑仙、羽士、诛仙、狂妖、巫妖、
   影鬼、方士、镇越、天象、灵医、无相、太极. Give every profession a fresh
   account and ordinary empty character archive; use the real `choice_profe`
   bootstrap, enter a real cycle room, defeat a real level-appropriate S1 NPC
   through the production `kill_quick` combat loop, complete all configured chapter targets
   through room-visit and NPC-kill recording, claim exactly ten profession
   pieces, remove starter gear, invoke real one-click set equip, save/restore,
   then settle the same archive to 永恒服 and restore again. Distribute the
   matrix evenly across 寻星、破阵、同心. Every chapter must start only after
   the character naturally reached its configured minimum level, and every
   character must finish at level 69. Never write `player->level` in the test,
   directly inject full progress, replace combat with a kill counter, or rely on
   a one-profession smoke test.
2. Add focused TestUnit coverage for config, all rooms, stable multi-affinity
   grouping and catalog weights,
   entitlement denial/grant, interrupted-payment refund, multiple characters
   per cycle within the existing account/profession limits,
   all three route gates, 81 ordered claims in one real activity day without
   injecting future dates, 25 exact room/NPC story events, exactly ten bound
   rewards,
   duplicate-claim denial, movement/isolation, malformed-index failure closure,
   automatic expiry/close without automatic start, immutable content archival,
   active-world Eternal denial, closed-world Eternal Echo entry/exit, frozen
   rankings and one-time reward state, login-hook ordering,
   end-time boundaries, same-archive settlement, idempotent return, same-room
   convergence, cross-chapter handoff, and team-instance convergence.
3. Require illusion kill credit to come only from a cycle NPC in the player's
   exact room. Persist first room visits immediately and checkpoint kill progress
   at chapter thresholds, bosses, route completion, and bounded kill intervals;
   roll progress back if a checkpoint save fails.
4. Run Vue tests and `./scripts/build/build_vue_frontend.sh` for account-center
   changes. Require the real SSR/playability test, not source-string checks alone.
   Verify all 81 source illustrations are unique, byte-identical to their web
   copies, and return HTTP 200 for representative early/middle/final chapters.
5. Run `./restart-local-workers.sh --workers 3`. Require the complete
   TestUnit suite to report zero failures and the final topology to be active
   with three healthy Workers.
6. Probe public and coordinator health and inspect new logs for Pike compilation,
   storage, transaction, routing, or runtime exceptions.
7. Run `scripts/test_local_player_entry_smoke.sh` with credentials supplied only
   through `XIAND_SMOKE_USER`, `XIAND_SMOKE_PASSWORD`, and optionally
   `XIAND_SMOKE_CHARACTER`. It must obtain the real account session, select the
   character, find and execute the rendered `进入游戏` button command, then
   verify room view, `myhp`, inventory, skills, status, equipment, battle status,
   and start/stop the server autofight loop. For a disposable character already
   placed in a monster map, set `XIAND_SMOKE_REQUIRE_BATTLE=1` and require a real
   battle. Never commit smoke credentials. If a supported browser is available,
   also click the visible button there; otherwise report API-button coverage as
   browser-independent rather than claiming a visual browser run.
8. Review old JSP/bookmark/TXD paths. Eternal creation without `realm_type` must
   retain its old behavior; the client cannot choose an unauthorized ID.
9. Review the exact staged diff. Exclude player/runtime data and unrelated dirty
   files. Keep large staged rollout work on its feature branch until explicitly
   approved for main.
10. Run the post-teleport navigation regression. A successful hunt travel must
    expose `illusion_realm hunt`; a successful boss travel must expose the
    canonical direct challenge action; every success page must expose return to
    game, and failed movement must expose neither action.
11. Run all eight personal tiers for all twelve professions in Eternal and S1.
    Require monotonic PVE risk/reward, unchanged PVP, isolated unlock state,
    deterministic drop-weight checks, and source guards proving difficulty never
    enters Worker affinity, logical-zone identity, or instance routing.
12. Do not let TestUnit hide an exploration defect by moving a player and then
    calling `record_room_visit()` manually. In the twelve-profession 81-chapter
    matrix, use production `travel_to_chapter_target()` for every exploration.
    For at least one exploration per profession, clear only the current chapter's
    visit map after a successful arrival and call the same production travel
    action again; require the exact current-room retry to restore 1/1 without
    adding another global visit or reward. Keep source/runtime contracts for both
    cross-Worker arrival and same-Worker redirect visit hooks.
13. After any illusion task or movement fix, rerun Eternal-world regressions:
    `test_autofight_system.pike`, `test_autofight_capacity_pagination.pike`,
    `test_level_growth_tasks.pike`, `test_task_guide.pike`, and the dedicated
    profession suites. Require generic autofight to start, attack, route, rest,
    preserve ordinary task credit, and carry no `illusion_chapter_autofight`
    marker. A green seasonal matrix alone is insufficient proof that ordinary
    characters remain unaffected.
