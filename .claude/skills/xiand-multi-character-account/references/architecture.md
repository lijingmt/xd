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
| HTTP account sessions/routes | `gamelib/single/daemons/_http_api_mod/account_characters.pike` |
| HTTP route wiring | `gamelib/single/daemons/http_api_daemon.pike` |
| Password cache | `gamelib/single/daemons/_http_api_mod/auth.pike` |
| Player ownership field | `gamelib/clone/user.pike` |
| Profession initialization | `gamelib/d/init` (`choice_profe`) |
| Mobile/security recovery | `lowlib/system/cmds/login_band.pike` |
| Vue source | `vue_source/index.html`, `js/app.js`, `css/app.css` |
| Pike regression | `test_unit/test_multi_character_account.pike` |
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
| Equipment, inventory, storage | Character | Complete independent save |
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
3. Acquire per-user command mutexes for Vue siblings.
4. Save each sibling with `save_with_result()` before disconnecting it.
5. Return a legacy TXD for the selected physical character.
6. Execute the bootstrap command only while the saved profession is empty.

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
- Sibling save failure during switch: abort selection and leave the player
  connected.
- Password preparation/replacement failure: restore all committed characters and
  keep live objects on the old password.

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
- Use existing per-character HTTP command mutexes before save/remove.
- Do not hold the virtual-connection mapping mutex while saving/removing.
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

Restoring only one side can produce missing character cards or orphan `.o`
files. Never copy runtime manifests into the image or Git repository.
