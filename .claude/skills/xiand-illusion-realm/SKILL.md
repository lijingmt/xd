---
name: xiand-illusion-realm
description: Maintain, audit, configure, test, or extend Xiand's three-month 幻境区 cycle system. Use for 新月幻境, S1 or later cycle IDs, permanent account entitlement, illusion character creation, route chapters, cycle-only maps and rewards, logical-zone or map-Worker isolation, shared-asset restrictions, lifecycle administration, end-of-cycle return to 永恒服, rollover, anti-cloning guarantees, or related Vue/JSP compatibility in /usr/local/games/xiand.
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
- map affinity: the static directory under `gamelib/d/illusion_<id>/`
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

Every phase mutation must use the admin preview followed by its SHA-256
confirmation. The shared runtime file uses an interprocess lock, revision,
bounded audit list, temp file, backup, and atomic rename. Never edit it manually
while processes are running.

For S1:

1. Verify `current_id` is exactly `S1`, duration is 90 days, entry/return rooms
   load, seven chapters award exactly ten pieces, and both route arrays contain
   exactly three unique challenges.
2. Run `mgr_illusion_realm`, preview `open_registration`, then confirm.
3. Let players permanently unlock the account entitlement.
4. Preview `start`, confirm, and verify `ends_at-starts_at=90*86400`.
5. Let natural expiry or an explicit `settle` enter return settlement.
6. Confirm players retain the same character ID and `.o` archive after return.
7. Preview `close`, confirm, and retain the runtime audit/history.

For a later cycle:

1. Close the old cycle first.
2. Add the new static map/NPC content and change the tracked config to a new
   permanent uppercase ID such as `S2`. Never reuse or rename an old ID.
3. Complete a full restart so every Worker loads the same new config.
4. In `mgr_illusion_realm`, preview rollover and confirm the old/new IDs and
   population counts.
5. Apply rollover. It archives the old runtime and creates the new `draft`.
6. Continue with registration and start.

`closed_ids` allows old offline characters to return lazily after rollover. On
their next login, settle the unique old archive directly to 永恒服; never route
an old-cycle character into the new cycle.

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

Assign all active characters from one illusion ID to `illusion:<ID>`. Keep every
static room for one cycle under one map affinity so players entering the same
room meet on the same Worker.

While active, block access to eternal shared warehouse, shared recharge wallet,
shared pets, auction, and cross-world mail/trade/gift/team/combat/visibility.
Allow ordinary local trading only between characters in the same illusion
group; existing item binding rules remain authoritative. Do not weaken gateway
account locks or player-transfer transaction locks.

If an account index exists but both main and backup fail validation, assign a
unique unavailable group, freeze movement, and block shared assets. Never treat
that character as a legacy eternal account.

## Payment and settlement safety

Permanent entitlement purchase uses a player-saved two-phase credential around
the jade payment and account-index grant. On login:

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

1. Add focused TestUnit coverage for config, all rooms, one-affinity mapping,
   entitlement denial/grant, interrupted-payment refund, one-character-per-ID,
   all three route gates, seven ordered claims, exactly ten bound rewards,
   duplicate-claim denial, movement/isolation, malformed-index failure closure,
   same-archive settlement, and idempotent return.
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
