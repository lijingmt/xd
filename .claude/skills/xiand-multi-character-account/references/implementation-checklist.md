# Implementation checklist

Use every applicable row as a gate. Mark a row intentional only with a code
comment, test, and operator-documentation note.

## Baseline and scope

- [ ] Confirm the active feature branch and preserve unrelated runtime dirt.
- [ ] Read the current account daemon, HTTP module, Vue flow, tests, and operator
      document before editing.
- [ ] Classify every requested field as account-wide or character-local.
- [ ] Confirm old direct login, automatic-browser TXD, JSP/Socket, and one-profile
      Vue behavior that must remain unchanged.

## Storage and compatibility

- [ ] Keep the original account `.o` path and format unchanged.
- [ ] Keep manifest synthesis read-only for legacy accounts.
- [ ] Create the physical child before committing manifest membership.
- [ ] Keep default slot 1, sequential unique slots, safe unique IDs, valid
      race/profession pairs, and bounded count.
- [ ] Preserve the logical-zone prefix in generated IDs.
- [ ] Reject a second unfinished character and a duplicate profession.
- [ ] Verify child `account_owner` from its physical save before selection.
- [ ] Validate main and backup manifests independently and fail closed when both
      physical files are invalid.
- [ ] Preserve a valid backup when replacing an invalid main.
- [ ] Roll back only artifacts created by the failed operation.

## Initialization and game systems

- [ ] Return the original `choice_profe` command only for an empty profession.
- [ ] Verify starter skill, gear, auto-equip, medicine, guide, spawn, registration
      time, and save occur through the original profession flow.
- [ ] Confirm character-local level, skills, equipment, inventory, currency,
      tasks, home, guild, friends, VIP, personal storage, and automation after
      relogin.
- [ ] Keep the shared vault an explicit independent account service; never
      silently redirect personal-warehouse callers to account scope.
- [ ] Keep old/free jade character-local and future paid recharge in an explicit
      account wallet; verify physical-first mixed payment and no bulk migration.
- [ ] Confirm all current profession pairs appear exactly once in backend and
      Vue catalogs; update slot/product policy explicitly when adding a class.

## Authentication and account recovery

- [ ] Authenticate management sessions against the registration/default account.
- [ ] Use cryptographic random bounded tokens with expiry and revocation.
- [ ] Require POST for token-bearing list/create/select/logout operations.
- [ ] Keep tokens out of URLs, localStorage, logs, and caches.
- [ ] Recheck manifest and physical ownership on every selection.
- [ ] Synchronize password changes from settings, administrator tools, and
      mobile/security-code recovery.
- [ ] Prepare all password files before committing any, and roll back all on
      partial replacement.
- [ ] Remove the old password from automatic-recovery backups.
- [ ] Update live objects, invalidate per-character password caches, and revoke
      account sessions after success.
- [ ] Verify no old or new plaintext password is emitted to logs.

## Concurrency

- [ ] Serialize account manifest creation and password synchronization.
- [ ] Serialize account-session table changes.
- [ ] Resolve Socket/JSP, direct TXD, automatic-browser, and HTTP logins through
      the same configurable account-online guard.
- [ ] Permit distinct siblings only up to the 1-10 configured limit; always
      replace an older object for the same physical character ID.
- [ ] Fall back to one on missing/invalid config and prove both repository default
      5 and test override 1 in real runtime tests, including periodic eviction of
      already-online excess characters.
- [ ] Acquire the stable registration-account command mutex before sibling
      save/remove, including a first HTTP command that creates the player.
- [ ] Call `save_with_result()`, not boolean `save()`.
- [ ] Remove the virtual connection only after successful save.
- [ ] Do not hold connection-table locks during player save/remove.
- [ ] Bound account sessions and character slots against resource exhaustion.

## Shared-vault anti-clone transactions

- [ ] Preserve the legacy personal warehouse and its equipment metadata; accept
      the appended permanent-ID field without changing old withdrawal behavior.
- [ ] Assign collision-resistant permanent IDs and address transfer commands by
      ID, never item path/name/index.
- [ ] Persist pending escrow before removing the source and verify the character
      save before destination commit.
- [ ] Recover interrupted transfers by checking the exact ID in the saved `.o`.
- [ ] Retain withdrawn-ID tombstones and reject duplicate active IDs.
- [ ] Fail closed on corrupt/missing shared main when `.bak`/`.tmp` exists; do
      not auto-load a potentially stale shared backup.
- [ ] Reconcile a player backup that resurrects an item already in shared storage
      before login registration.
- [ ] Test duplicate clicks, same-path items, both failpoints, cross-character
      withdrawal, corrupt-main/valid-backup, stale player backup, capacity, and
      invalid ownership/path inputs.

## Shared paid-recharge transactions

- [ ] Resolve a selected character to its verified registration owner before
      reading or mutating the wallet.
- [ ] Require administrator authorization, a second confirmation, and a random
      idempotency key; reject a reused key with different parameters.
- [ ] Serialize and atomically persist credit, debit, and refund with bounded
      validated transactions and cache.
- [ ] Consume character physical jade first, then exactly the shared shortage;
      test two sibling characters spending the same wallet.
- [ ] Keep free/reward jade character-local and show shared balance explicitly in
      the account selector.
- [ ] Fail closed on corrupt wallet main when any balance artifact exists; never
      restore a stale backup automatically and never block character login.
- [ ] Synchronize cumulative recharge entitlement to online siblings and on
      offline login without lowering old values.
- [ ] Close every raw client minting command and test duplicate confirmation,
      mismatched request ID, corruption, rollback, and audit log fields.

## Vue and rolling deployment

- [ ] Edit `vue_source` and rebuild; never patch only `dist` or `web/web_vue`.
- [ ] Keep old-backend 404/501 direct-login fallback.
- [ ] Auto-enter a healthy one-character account.
- [ ] Show actionable states for pending, unavailable, loading, creation failure,
      selection failure, expired token, and account limit.
- [ ] Reauthenticate an expired management session from the active TXD in the
      same user action when safe.
- [ ] Pause stats, battle, chat, and auto-fight polling under the selector and
      resume on cancel/entry.
- [ ] Clear per-character UI state before switching and persist only current
      account/session/character identifiers in sessionStorage.
- [ ] Verify phone, tablet, desktop, safe-area, keyboard, scrolling, focus, and
      disabled-button behavior.

## Deployment, backup, and docs

- [ ] Confirm the whole `data_xiand` mount remains persistent and writable.
- [ ] Do not add or copy an empty `accounts/` seed; allow lazy creation.
- [ ] Back up and restore `u/`, account manifests, and `*.storage.json` as one
      consistency unit.
- [ ] Include `*.wallet.json` in the same data-root backup and restore boundary.
- [ ] Update `docs/multi-character-account.md` for any contract change.
- [ ] Exclude runtime account JSON, player saves, logs, backups, caches, and test
      artifacts from commits.

## Validation

- [ ] Run `audit_multi_character.py` with zero failures.
- [ ] Run Vue tests and build.
- [ ] Run targeted real-save TestUnit assertions with cleanup on every path.
- [ ] Require the shared-vault/login suite to prove exactly one permanent item ID
      across personal and shared locations after every recovery path.
- [ ] Perform safe `./restart.sh`; require all TestUnit files to pass.
- [ ] Verify ports 13800/8888 and `/health`.
- [ ] Verify account GET returns 405 and invalid POST token returns 401.
- [ ] Verify `Cache-Control: no-store` on JSON.
- [ ] Compare source/dist/deployed JS/CSS and built dist/deployed HTML/manifests.
- [ ] Scan the fresh runtime log for new compile, cast, null-index, or account
      daemon failures.
- [ ] Verify no test account manifests or child `.o` files remain.
- [ ] Run all ten review passes before commit and push.
