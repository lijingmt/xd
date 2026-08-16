---
name: xiand-illusion-realm
description: Maintain, audit, configure, test, or extend Xiand's monthly 幻境区 cycle system. Use for 新月幻境, S1 or later cycle IDs, cycle-keyed permanent account entitlement, per-cycle character slots, illusion character creation, route chapters, rankings and duel honor, cycle-only maps and rewards, logical-zone or map-Worker isolation, shared-asset restrictions, lifecycle administration, end-of-cycle return to 永恒服, rollover, anti-cloning guarantees, or related Vue/JSP compatibility in /usr/local/games/xiand.
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

## Locate each layer

- tracked cycle config: `gamelib/etc/illusion_realm.json`
- tracked S1 story: `gamelib/etc/illusion_s1_story.json`
- tracked nine-volume storyboard atlases and 81 chapter illustrations:
  `images/illusion_s1/story/`
- shared runtime phase/audit: `data_xiand/illusion_realm/runtime.json`
- archived closed states: `data_xiand/illusion_realm/history/`
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
   load, nine volumes contain exactly 81 ordered chapters, the 7-day gate and
   25 key story events are intact, all nine atlases load, chapter rewards total
   exactly ten pieces, and both route arrays contain exactly three challenges.
2. Run `mgr_illusion_realm`, preview `open_registration`, then confirm.
3. Let players permanently activate the S1-specific account entitlement for
   free. S1 keeps a configured zero price while retaining idempotent
   account-index auditing. A later cycle must have its own entitlement.
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
  titles, active-day gates from 1 through 7, and exactly 25 configured story
  events whose chapter, kind, Chinese location label and canonical room/NPC
  path agree;
- keep story prose in the separate tracked story JSON and require its immutable
  ID/title/premise to match the cycle config before flattening it at startup;
- keep one original square 3x3 atlas per volume for the volume index and one
  independently rendered `chapters/chapter_NNN.png` for each chapter. Chapter
  prose emits only `[storypic 1..81:/xd/images/illusion_s1/story/chapters/chapter_NNN.png]`;
  the JSON API, Vue, every legacy HTML filter, build script, and Docker image
  must reject traversal, mismatched chapter/path pairs, and out-of-range IDs;
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
global entitlements are S1-only and must never unlock S2. The first character
is free after entitlement activation in that cycle. Store 100-jade extra slots
and the cumulative
500-jade multi-character unlock under `season_expansions[illusion_id]`; never
let S1 capacity leak into S2. Continue mirroring S1 into the legacy top-level
fields so rollback binaries retain already-paid S1 capacity. Use bounded
request-ID lists and the player-saved two-phase expansion credential for
cross-Worker retry and refund.

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
   all three route gates, 81 ordered claims across seven distinct Beijing
   activity days, 25 exact room/NPC story events, exactly ten bound rewards,
   duplicate-claim denial, movement/isolation, malformed-index failure closure,
   automatic expiry/close without automatic start, login-hook ordering,
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
5. Run `./scripts/restart_map_workers_with_testunit.sh 3`. Require the complete
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
