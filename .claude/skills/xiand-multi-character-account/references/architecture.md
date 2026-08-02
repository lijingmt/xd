# Multi-character architecture

## Contents

1. Authoritative files
2. Data layout and manifest schema
3. Ownership boundary
4. Lifecycle flows
5. Failure and recovery semantics
6. Security and concurrency
7. Deployment boundary

## 1. Authoritative files

| Concern | Path |
|---|---|
| Account/character daemon | `gamelib/single/daemons/account_characterd.pike` |
| Concurrent-character limit | `gamelib/etc/account_characters.conf` |
| Account shared-vault daemon | `gamelib/single/daemons/account_storaged.pike` |
| All-mode login guard | `lowlib/system/inherit/user.pike` |
| HTTP account command mutex | `gamelib/single/daemons/_http_api_mod/thread_manager.pike` |
| HTTP account sessions/routes | `gamelib/single/daemons/_http_api_mod/account_characters.pike` |
| HTTP route wiring | `gamelib/single/daemons/http_api_daemon.pike` |
| Password cache | `gamelib/single/daemons/_http_api_mod/auth.pike` |
| Player ownership field | `gamelib/clone/user.pike` |
| Profession initialization | `gamelib/d/init` (`choice_profe`) |
| Mobile/security recovery | `lowlib/system/cmds/login_band.pike` |
| Vue source | `vue_source/index.html`, `js/app.js`, `css/app.css` |
| Pike regression | `test_unit/test_multi_character_account.pike` |
| Shared-vault/login regression | `test_unit/test_account_shared_storage.pike` |
| Vue regression | `vue_source/tests/account-characters.test.js` |
| Operator documentation | `docs/multi-character-account.md` |

## 2. Data layout and manifest schema

An old account remains its own default character:

```text
data_xiand/u/bc/xd01abc.o
```

After creating another character:

```text
data_xiand/accounts/bc/xd01abc.json
data_xiand/u/bc/xd01abc.o
data_xiand/u/20/xd01abcc2a8f31e20.o
```

The optional shared vault is a separate account file and is created only after
the first successful deposit:

```text
data_xiand/accounts/bc/xd01abc.storage.json
```

The manifest contains identity and initialization intent, not gameplay state:

```json
{
  "version": 1,
  "account_id": "xd01abc",
  "created_at": 1785670000,
  "updated_at": 1785670100,
  "characters": [
    {
      "id": "xd01abc",
      "slot": 1,
      "created_at": 0,
      "desired_race": "",
      "desired_profession": ""
    },
    {
      "id": "xd01abcc2a8f31e20",
      "slot": 2,
      "created_at": 1785670100,
      "desired_race": "third",
      "desired_profession": "fangshi"
    }
  ]
}
```

Validate that the default account is slot 1, slots are sequential and unique,
IDs are unique and safe, desired race/profession pairs are authoritative, and
the character count is bounded. Treat a child as selectable only when its `.o`
exists and its saved `account_owner` matches the manifest account.

## 3. Ownership boundary

| State | Scope | Notes |
|---|---|---|
| Registration account ID | Account | Default old character ID |
| Character ID | Character | Stable generated ID; retains zone prefix |
| Password | Account | Must remain synchronized across every `.o` |
| Account management token | Account session | List/create/select only |
| `account_owner` | Character ownership | Old saves fall back to their own ID |
| Race/profession | Character | One character per profession |
| Level, XP, skills | Character | Never copied after creation |
| Equipped items and backpack | Character | Complete independent save |
| Personal warehouse | Character | Legacy `packaged_items`; unchanged |
| Shared vault | Account | Explicit transfer only; independent JSON authority |
| Currency and materials | Character | Do not share implicitly |
| Tasks and newbie guide | Character | Initialized by original profession flow |
| Home, guild, team, friends | Character | Existing systems key by character ID |
| VIP and automation | Character | Current design intentionally independent |

If a future product requirement shares VIP, wallet, mobile, security code, or
entitlements, design an account-level source of truth first. Do not synchronize
only the happy-path command; audit admin, recovery, offline, cache, backup,
rollback, and legacy direct-login paths.

## 4. Lifecycle flows

### Legacy login

1. Resolve the requested old character.
2. Find no physical manifest.
3. Synthesize a one-character record in memory.
4. Return one character and auto-enter it in Vue.
5. Write no account file.

### Create a child

1. Resolve registration owner from requested/default/child ID.
2. Lock account storage.
3. Validate account, limit, pending state, pair, and profession uniqueness.
4. Generate a collision-resistant child ID under the same zone prefix.
5. Read the registration password and save an empty standard user with
   `account_owner`.
6. Append the manifest entry and atomically commit it.
7. Roll back only the new child if manifest commit fails.
8. Return `choice_profe race/profession` as the bootstrap command.

### Select a child

1. Authenticate the random management token.
2. Verify manifest membership and physical `account_owner`.
3. Return a legacy TXD for the selected physical character without disconnecting
   a different sibling merely because the browser selected another profile.
4. On the selected character's first game command, acquire the registration-
   account runtime mutex and enforce the configured online limit.
5. Execute the bootstrap command only while the saved profession is empty.

### Enter through any login mode

1. Restore the incoming physical character.
2. Resolve its registration owner and acquire the account runtime mutex.
3. Reconcile any stale personal-warehouse copy whose permanent item ID is
   already authoritative in the shared vault.
4. Always save and disconnect an older object for the same physical character
   ID. Different sibling IDs remain online until the configured account limit is
   reached; then save and disconnect the oldest excess sibling from the active
   table, HTTP virtual connection, Socket connection, and world registration.
5. Register the incoming player while the same account mutex is still held.
6. Refuse the incoming login if reconciliation or any required outgoing save
   fails. Invalid/missing configuration falls back to one active character.

### Move an item into the shared vault

1. Lazily assign a 64-hex permanent ID to legacy personal-warehouse records and
   verify the player save.
2. Persist a pending deposit containing the exact item record and ID.
3. Remove that exact ID from the personal warehouse and save the character.
4. Commit the pending record into shared items. A repeated click cannot select a
   different same-name item because commands use the permanent ID.
5. If interrupted, inspect the physical `.o`: source ID present means rollback;
   absent means commit.

Withdrawal is the inverse: shared item to durable pending escrow, append the
same ID to personal storage and save, then retire the shared ID. Login
reconciliation removes a personal copy resurrected by an old player backup when
the same ID already exists in shared storage.

### Change account password

1. Resolve owner and all manifest character IDs under the account lock.
2. Save live characters with verifiable results.
3. Prepare a new password temp for every physical file.
4. Commit only after all preparations succeed; roll back committed files on
   replacement failure.
5. Refresh backups so an old password cannot reactivate during recovery.
6. Update live objects, invalidate every HTTP password-cache entry, and revoke
   all account-management sessions.

## 5. Failure and recovery semantics

- No main or backup manifest: synthesize legacy view without writing.
- Valid main: use it and cache a defensive copy.
- Invalid/missing main with valid backup: use backup; preserve the good backup
  when replacing an invalid main.
- Both physical files invalid: fail closed with an unavailable-account response.
- Missing child `.o`: keep its manifest card visible as unavailable/recoverable;
  do not silently delete ownership history.
- Child creation save failure: do not touch the manifest.
- Manifest commit failure: delete only the just-created child artifacts.
- Save failure while replacing the same character or evicting an excess sibling:
  refuse the incoming login and leave the unsaved outgoing player connected.
- Password preparation/replacement failure: restore all committed characters and
  keep live objects on the old password.
- Shared main valid: use it and recover durable pending transfers by exact item
  ID against the saved character.
- Shared main missing/invalid while `.bak` or `.tmp` exists: fail closed. Never
  auto-restore a stale shared backup because it could clone withdrawn gear.
- Interrupted deposit/withdrawal: exact-ID recovery leaves the item in one
  authoritative location. Never infer identity from item path, name, or array
  position.

## 6. Security and concurrency

- Use cryptographic random 64-hex-character management tokens with a sliding
  expiration, a global bound, and a per-account bound.
- Put tokens in JSON POST bodies and `sessionStorage`; emit `Cache-Control:
  no-store` for JSON responses.
- Return generic authentication errors. Never log raw registration commands,
  login parameters, passwords, recovery passwords, or administrator password
  mutation arguments.
- Keep manifest mutation and password synchronization under the account mutex.
- Keep session mutation under its session mutex.
- Resolve HTTP command mutexes to the registration account; sibling characters
  must serialize with login, shared-vault transfers, save, and removal.
- The versioned online-limit configuration accepts 1-10 and is read on each
  login. The repository default is 5; changing it to 1 restores conservative
  single-character mode without a code change or process restart. A 15-second
  daemon check also saves and removes already-online excess characters.
- Do not hold the virtual-connection mapping mutex while saving/removing.
- Keep shared-vault transactions bounded, validate every item path/ID, and never
  reacquire the account mutex from code already executing under the HTTP account
  command mutex.
- Preserve logical-zone isolation because generated IDs retain the registration
  account's first four characters.

## 7. Deployment boundary

`docker/docker-compose.yml` and `restart-docker.sh` mount the complete
`data_xiand` directory. The daemon creates `accounts/` lazily, so no seed folder
or first-deployment copy is required. The process only needs write permission on
the mounted directory.

Back up and restore these together:

```text
data_xiand/u/
data_xiand/accounts/
```

This includes both `<account>.json` and `<account>.storage.json`. Restoring only
one side can produce missing character cards, orphan `.o` files, or inconsistent
pending vault transfers. Never copy runtime manifests into the image or Git
repository.
