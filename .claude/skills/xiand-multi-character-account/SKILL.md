---
name: xiand-multi-character-account
description: Develop, modify, audit, debug, test, document, or deploy Xiand's one-registration-account-to-multiple-independent-characters system. Use when changing account manifests, character slots, profession uniqueness, old-account compatibility, configurable concurrent-character login, account shared storage, character selection APIs or Vue UI, account-wide password recovery, independent player saves, anti-clone recovery, deployment persistence, or multi-character TestUnit coverage.
---

# Xiand Multi-Character Accounts

Treat this feature as a compatibility layer above complete legacy player saves,
not as a replacement player model. Read `references/architecture.md` before any
design or code change. Use `references/implementation-checklist.md` during the
change and `references/ten-pass-review.md` before completion.

## Non-negotiable contracts

- Keep every old player at its original `data_xiand/u/<suffix>/<userid>.o`
  path. Never require a bulk migration, rename, or conversion.
- Let an account without a manifest synthesize one default character in memory.
  Merely logging in or listing it must not write a manifest.
- Create `data_xiand/accounts/<suffix>/<account>.json` only when a second
  character is requested. Create directories lazily under the existing
  persistent `data_xiand` mount.
- Store every character as a full standard `GAMELIB_USER` `.o` file. Keep level,
  experience, profession, skills, equipped items, backpack, personal warehouse,
  tasks, home, social, VIP, currency, and automation state character-local.
- Implement optional account sharing only through the independent shared vault
  daemon and `*.storage.json`; never make the legacy personal warehouse itself
  account-wide. Move items directly between the two warehouses under a durable
  pending transaction with permanent item IDs and login-time reconciliation.
- Keep only registration identity, ownership, login password, and management
  authorization account-wide. Any new shared field needs an explicit migration,
  recovery, concurrency, and privacy contract.
- Preserve old Socket/JSP, direct TXD, automatic-browser, and one-character Vue
  login paths. A one-character account must still enter automatically.
- Reuse the authoritative `choice_profe <race>/<profession>` flow for new
  character initialization. Do not duplicate starter skills, gear, medicine,
  guide, registration, or spawn logic in the account daemon.
- Enforce ownership, supported race/profession pairs, the configured slot limit,
  one character per profession, and at most one unfinished character on the
  server. Never trust the browser's character ID or profession.
- Write manifests and synchronized passwords with temp files, size checks,
  backups, atomic replacement, rollback, and fail-closed recovery. A password
  backup must not retain an old credential that can become active after restore.
- Use short-lived random account-management tokens only for list/create/select.
  Continue using the selected character's legacy TXD for game commands. Put
  management tokens in POST bodies and `sessionStorage`, never URLs or durable
  browser storage.
- Serialize manifest creation and account password changes. Resolve every
  character command mutex to its registration account so sibling HTTP commands
  cannot race. On every HTTP, Socket/JSP, direct-TXD, or automatic-browser login,
  enforce `gamelib/etc/account_characters.conf`. Different characters may remain
  online up to its configured limit, but the same physical character ID must
  never have two player objects. Save and disconnect the oldest excess object;
  invalid or missing configuration must safely fall back to one. Recheck the
  file periodically so lowering the limit also affects already-online accounts.
- Keep `data_xiand/u` and `data_xiand/accounts` in the same backup, restore,
  permission, container-volume, and disaster-recovery boundary.

## Workflow

### 1. Establish the active baseline

Inspect branch, status, recent commits, server ports, latest TestUnit summary,
and runtime dirt. Preserve unrelated player data. Run:

```bash
python3 .claude/skills/xiand-multi-character-account/scripts/audit_multi_character.py
```

Treat this audit as an integration map, not runtime proof.

### 2. Classify the requested state

Decide whether each field is registration-account state or character state.
Default to character-local state. Share a field only when all characters must
observe one security or ownership value and when every legacy mutation path can
be synchronized. Consult the ownership table in `references/architecture.md`.

### 3. Change the storage layer first

Maintain the daemon as the sole authority for resolving account ownership,
loading/saving manifests, generating collision-resistant child IDs, checking
profession occupancy, and synchronizing account credentials. Validate the main
manifest and backup independently. If either physical file exists but neither
validates, fail closed instead of synthesizing a legacy account.

Never write a manifest before the child `.o` file is safely created. If manifest
commit fails, remove only the newly created child and its temporary files.

For shared-vault changes, treat the current `*.storage.json` as the sole
authority. Never automatically load its `.bak` after the main file is missing or
invalid: an older backup can resurrect already withdrawn equipment. Persist a
pending record before removing either source copy, save the affected character
with `save_with_result()`, then commit the destination and a retired-ID
tombstone. Recovery decides commit or rollback by checking the exact permanent
item ID in the physical player save. Reconcile stale personal-save backups at
login before the character becomes active.

### 4. Change APIs and login compatibility

Authenticate against the registration/default character, then issue a bounded
account-management session. Recheck ownership from the server manifest and
physical child `account_owner` before selection. Return the existing TXD format
for the selected character. Preserve the Vue fallback to the old direct-login
endpoint for rolling deployments with an older backend.

Account password changes must cover the in-game settings command, administrator
command, mobile/security-code recovery, live objects, HTTP password cache,
management-session revocation, main saves, and recovery backups.

### 5. Change the Vue experience

Edit `vue_source`, never only built output. Keep selector state separate from
login and game state. Pause player, battle, chat, and auto-fight polling while
the selector covers the game, then resume it on cancel. Handle unavailable
physical saves, unfinished characters, expired account tokens, failed creation,
failed selection, refresh/relogin, mobile safe areas, and one-character auto
entry. Build to both `vue_source/dist` and `web/web_vue` through the repository
pipeline.

### 6. Validate vertically

Extend `test_unit/test_multi_character_account.pike`,
`test_unit/test_account_shared_storage.pike`, and
`vue_source/tests/account-characters.test.js`. Test real `.o` save/restore and
cleanup, not source strings alone. Cover legacy zero-write listing, child create,
bootstrap reuse, duplicate/pending rejection, ownership forgery, corrupt main
and backup, password plus backup synchronization, token method boundaries, and
rolling-backend fallback.

Run Vue tests, then perform a real safe restart:

```bash
cd vue_source && npm test
cd .. && git diff --check && ./restart.sh
```

Require full TestUnit success, ports `13800` and `8888`, a healthy `/health`,
expected 405/401 account-API boundaries, identical built/deployed artifacts,
zero test-account leftovers, and no new compile/runtime errors.

### 7. Review deployment and documentation

Confirm Docker and restart scripts persist the whole `data_xiand` directory;
do not add a separate accounts volume. Update `docs/multi-character-account.md`
when paths, limits, shared fields, APIs, backup rules, or recovery behavior
change. Never commit runtime manifests, player `.o` files, logs, backups,
`__pycache__`, or test output.

## Pike editing rules

- Apply the repository Pike coding, Pike syntax, code-review, HTTP architecture,
  transaction-lock, Vue, and Xiand restart-validation skills as applicable.
- Find a compiling historical precedent for every Pike construct.
- Use `apply_patch`; avoid broad formatting rewrites.
- Do not return from inside `catch`.
- Do not treat `user->save()` as boolean; call `save_with_result()` when success
  must be verified.
- Release mutex keys on every path. Do not hold a connection-table lock while
  saving or removing a player.
- Keep test-only cleanup APIs gated by a `testunit` account identifier and never
  expose them through commands or HTTP routes.

## Definition of done

- Old accounts and every old login mode work without manifest creation.
- Every login mode enforces the configured active-character limit. Distinct
  sibling characters coexist up to that limit; the same character always
  replaces its former object, and save/reconciliation failure refuses the
  incoming login. Switching the configuration back to one must safely evict
  excess online objects within the configured polling interval and is covered by
  tests.
- A legacy account creates, initializes, switches, saves, restores, and resumes
  multiple independent profession characters without shared growth state.
- Personal warehouses remain compatible, while explicit account-shared-vault
  transfers survive duplicate clicks, interruption, relogin, cross-character
  access, and stale `.o.bak` restoration without creating a second item ID.
- Invalid profession pairs, duplicate professions, excess slots, unfinished
  stacking, missing saves, forged ownership, expired tokens, and corrupt indexes
  fail safely with actionable UI messages.
- All password mutation and recovery paths synchronize every character, caches,
  sessions, live objects, main files, and safe backups.
- Concurrency cannot save/remove a player during a same-account parallel
  command, including siblings with different character IDs.
- Fresh deployments create the accounts directory lazily; existing deployments
  retain manifests across rebuild/restart through the current data volume.
- The static audit, targeted Vue tests, targeted Pike assertions, full restart,
  logs, ports, HTTP boundary checks, artifact checks, and ten-pass review all
  pass.
- Only intended source, tests, built frontend, docs, and this skill are committed
  and pushed on the requested branch.
