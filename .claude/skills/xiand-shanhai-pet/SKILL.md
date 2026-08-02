---
name: xiand-shanhai-pet
description: Develop, audit, debug, balance, test, document, or deploy Xiand's 山海万灵 account pet system. Use when changing pet collection, V1/V2 migration, levels, stars, evolution, attributes, rift eggs or fragments, account sharing, active companion ownership, bounded PVE/PVP assistance, fast-decision parity, pet duels, battle-status API data, Vue companion cards, charge/cooldown feedback, pet animations, mobile layout, or Shanhai pet TestUnit coverage.
---

# Xiand Shanhai Pet System

Treat 山海万灵 as account-level collection plus deterministic cultivation and
bounded combat companionship, not as a second summon NPC system. Read `references/system-map.md` before changing pet
storage or acquisition. Read `references/combat-companion-ui.md` before changing
PVE assistance, battle API fields, animations, or the Vue battle dock.

## Non-negotiable contracts

- Store permanent data by registration account in
  `data_xiand/accounts/<suffix>/<account>.pets.json`; keep player `.o`, backpack,
  warehouse, home, equipment, tasks, and profession summons unchanged.
- Give every pet a collision-resistant permanent ID. Keep one instance per
  species per account; convert duplicates into fragments instead of cloning.
- Keep the first companion free at level 15. Use earned pet materials for stable
  exchanges and hatch guarantees. Do not sell combat-exclusive pets, PVP power,
  hidden probability boosts, or extra rewarded opponents through VIP.
- Share collection and materials across sibling characters, but let one pet
  accompany only one online character at a time. Reconcile assignments on login
  and clear only temporary battle state on disconnect or selection changes.
- Keep universal pets separate from Fangshi tiger, crane, and turtle summons.
  Never clone a universal pet NPC, register it with `SUMMOND`, add it to threat
  tables, consume a Fangshi slot, or trigger three-spirit resonance.
- Keep levels at 1–60, stars at 1–10, bonds at 1–5, and evolution derived from
  the 3/6/9-star thresholds. Calculate five attributes and power
  deterministically; do not add random aptitude or paid rerolls. Upgrade V1
  records in memory to one star, avoid read-only bulk rewrites, and persist V2
  through the next real atomic mutation.
- Permit PVE assistance only against valid ordinary NPC targets in the same room
  and logical zone. Preserve cooldowns, contribution caps, healing reduction,
  and anti-last-hit rules.
- Permit ordinary player PVP only through the bounded server path: 4/5/6 combat
  heartbeat charge by skill set, at most two activations per combat, 20% of
  extra cultivation growth, target-life caps, healing reduction, and no final
  blow. Resolve Fangshi summons to their player owner. Reset charge on opponent
  change but never reset used activations until combat cleanup. Reject stale,
  cross-room, cross-zone, self, city, and unrelated NPC targets.
- Keep standardized three-pet duels independent from cultivation and VIP. Make
  long-PVP fast decision consume only remaining bounded pet activations from
  temporary snapshots; never scale a one-time pet effect with simulated speed.
- Keep battle polling read-only and cheap. Build companion presence from player
  temporary state plus the in-memory catalog; never load the account pet file on
  every `/api/status` or `/api/battle_status` request.
- Treat blank child-character bootstrap as a pet login regression boundary.
  Keep `choice_race`, `choice_profe`, and `start` on the Backend thread; make an
  internal command failure return an HTTP error so Vue keeps the character
  selector open for retry instead of accepting an error line as a game screen.
- Make every visual event server-authored and uniquely identified. Let Vue render
  it once, retain a short bounded history across character switches, and clear
  timers/effects on logout, unmount, battle end, pet removal, or session change.
- Keep visual effects optional. Always retain readable cooldown/status/log text;
  honor the game effect toggle and `prefers-reduced-motion`.
- Edit `vue_source` only, then run the unified build so `web/web_vue` and
  `vue_source/dist` are generated from the same source.

## Workflow

### 1. Establish the runtime baseline

Inspect the active branch, dirty files, last restart result, ports 13800/8888,
pet test summary, and current built artifacts. Preserve player records, account
pet/wallet files, logs, backups, zone configs, caches, and generated output.

### 2. Classify the change

Decide whether it affects permanent account state, character-local temporary
state, combat authority, UI-only presentation, or more than one layer. Define
save/recovery behavior for permanent fields and lifecycle cleanup for temporary
fields before editing.

### 3. Change vertically

For acquisition or growth, update the catalog/collection daemon, command UI,
persistence validation, player guidance, and real runtime tests together.

For combat companionship, update all four layers together:

1. `perform_pet_combat_assist()` classifies ordinary NPC, player, and
   player-owned summon targets; its PVE/PVP handlers author the result and event.
2. `query_pet_battle_presence()` returns cultivation, power, PVE cooldown or PVP
   charge/uses, and a recent event without disk I/O.
3. `query_player_state()` exposes the presence snapshot to battle status.
4. Vue synchronizes the snapshot, de-duplicates the event, renders the companion
   card/burst/log, and cleans all timers safely.

Never infer damage, healing, targets, cooldown, or readiness in the browser when
the server can provide it.

### 4. Protect concurrency and identity

Use the registration account resolver for permanent mutations and the existing
pet mutex for account state. Keep HTTP status reads non-mutating. Include the
physical character ID in temporary event identity and prevent sibling character
responses from overwriting the selected Vue session.

### 5. Validate presentation

Cover compact and full battle windows, collapsed dock, narrow phones, tablet and
desktop widths, long pet/skill names, full HP/MP zero-value assistance, effect
toggle off, reduced motion, repeated one-second polling, battle end, logout,
character switch, and a missing/invalid pet snapshot.

### 6. Validate in the real game

Extend `test_unit/test_shanhai_pet_system.pike` and
`vue_source/tests/battle-state.test.js`; update build-contract tests when new
markup or responsive CSS becomes required. Then run:

```bash
cd vue_source && npm test
cd ..
./scripts/restart_with_testunit.sh
./scripts/build/build_vue_frontend.sh
git diff --check
```

Require the pet-specific assertions, full TestUnit, Vue tests, template compile,
ports, HTTP public endpoint, logs, and generated artifact comparisons to pass.
Static source checks alone are not completion evidence.

When login reconciliation or account ownership changes, use a disposable
account to run create, select, bootstrap, and birthplace entry through the real
HTTP endpoints. Cover every profession pair at least once before release and
remove only the disposable records after all test player objects are offline.

### 7. Document and commit safely

Update `docs/shanhai-wanling-system.md` whenever player-facing collection,
balance, combat, UI, or recovery behavior changes. Commit source, tests, docs,
skill files, and generated frontend only. Exclude `data_xiand`, runtime rankings,
logs, backups, logical-zone runtime files, `__pycache__`, `output`, and `tmp`.

## Pike editing rules

- Apply the Pike coding guard, Pike syntax, code-review, battle-system, Vue, and
  Xiand restart-validation skills as applicable.
- Find a compiling project precedent for each Pike construct.
- Use immutable mapping assignment for cross-thread temporary event snapshots;
  return copies to HTTP readers rather than mutating a shared mapping in place.
- Guard optional object methods and validate room, life, target kind, logical
  zone, and summon ownership before changing HP/MP.
- Do not return from inside `catch`; do not add disk access to status polling.

## Definition of done

- Collection, materials, active assignment, V1/V2 migration, 60 levels, ten
  stars, evolution, rift, duel, and old-account compatibility remain correct.
- PVE and PVP assistance remain bounded; PVP cannot kill, exceed two
  activations, reset its limit by switching targets, or diverge in fast decision.
- The battle dock visibly communicates which pet is present, what it can do, and
  when it will act; valid events animate once and remain readable without motion.
- Full-resource assistance gives companionship feedback without fabricating a
  heal or damage number.
- Multi-character switching cannot replay, cross-wire, or concurrently assign a
  single pet incorrectly.
- A newly created child character can complete its profession bootstrap; an
  initialization failure remains recoverable from the character selector.
- Vue source and both generated directories match the unified build.
- Pet-targeted tests and the full restart TestUnit pass with no new compile,
  backtrace, API, or layout-contract failure.
