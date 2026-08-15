---
name: xiand-illusion-realm
description: Maintain, audit, configure, test, or extend Xiand's monthly 幻境区 cycle system. Use for 新月幻境, S1 or later cycle IDs, permanent account entitlement, illusion character creation, route chapters, cycle-only maps and rewards, logical-zone or map-Worker isolation, shared-asset restrictions, lifecycle administration, end-of-cycle return to 永恒服, rollover, anti-cloning guarantees, or related Vue/JSP compatibility in /usr/local/games/xiand.
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
- shared runtime phase/audit: `data_xiand/illusion_realm/runtime.json`
- archived closed states: `data_xiand/illusion_realm/history/`
- lifecycle/progress/reward/payment recovery: `gamelib/single/daemons/seasonal_chard.pike`
- entitlement and realm identity: `gamelib/single/daemons/account_characterd.pike`
- logical interaction group: `_logical_zone_mod/policy.pike`
- map affinity: `MAP_WORKERD->query_affinity_key()` plus the static rooms under
  `gamelib/d/illusion_<id>/`
- account HTTP create/list API: `_http_api_mod/account_characters.pike`
- Vue account center: `vue_source/` only; rebuild generated clients with the
  repository build script
- player/admin commands: `gamelib/cmds/illusion_realm.pike` and
  `gamelib/cmds/mgr_illusion_realm.pike`
- focused regression: `test_unit/test_illusion_realm.pike`

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
   load, seven chapters award exactly ten pieces, and both route arrays contain
   exactly three unique challenges.
2. Run `mgr_illusion_realm`, preview `open_registration`, then confirm.
3. Let players activate the permanent account entitlement for free. S1 keeps a
   configured zero price while retaining idempotent account-index auditing.
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
- require chapter reward counts to sum to exactly ten;
- fail closed if config or runtime state is malformed.

S1 routes are intentionally different without changing combat formulas:

- 寻星: discover all configured hidden moon seals;
- 破阵: defeat all configured distinct guardian bosses;
- 同心: reach the configured same-team kill count.

Keep route choice immutable within a cycle. Reward claims must be ordered,
account-bound, save-before-success, idempotent, and rollback all newly cloned
items plus progress on failure.

## Isolation rules

Assign all active characters from one illusion ID to `illusion:<ID>`. Do not
equate that logical group with a physical process. For S1, preserve the stable
affinities `illusion_s1:hub`, `illusion_s1:silver`, `illusion_s1:ruins`, and
`illusion_s1:depths`; unknown future rooms fail safely into
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

Permanent entitlement activation uses a player-saved two-phase credential around
the optional configured jade payment and account-index grant. S1 is free, but the
recovery path must remain correct if a later explicitly reviewed cycle sets a
nonzero price. On login:

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

The account center and all entitlement/settlement/creation mutations must read
the latest shared account index from disk. Hot movement/group checks may use the
Worker-local cache and rely on the gateway account-cache token during handoff.

## Required validation

1. Add focused TestUnit coverage for config, all rooms, stable multi-affinity
   grouping and catalog weights,
   entitlement denial/grant, interrupted-payment refund, multiple characters
   per cycle within the existing account/profession limits,
   all three route gates, seven ordered claims, exactly ten bound rewards,
   duplicate-claim denial, movement/isolation, malformed-index failure closure,
   automatic expiry/close without automatic start, login-hook ordering,
   end-time boundaries, same-archive settlement, idempotent return, same-room
   convergence, cross-chapter handoff, and team-instance convergence.
2. Run Vue tests and `./scripts/build/build_vue_frontend.sh` for account-center
   changes. Require the real SSR/playability test, not source-string checks alone.
3. Run `./restart-local-workers.sh --workers 3`. Require the complete TestUnit
   suite to report zero failures and the final topology to be active with three
   healthy Workers.
4. Probe public and coordinator health and inspect new logs for Pike compilation,
   storage, transaction, routing, or runtime exceptions.
5. Review old JSP/bookmark/TXD paths. Eternal creation without `realm_type` must
   retain its old behavior; the client cannot choose an unauthorized ID.
6. Review the exact staged diff. Exclude player/runtime data and unrelated dirty
   files. Keep large staged rollout work on its feature branch until explicitly
   approved for main.
