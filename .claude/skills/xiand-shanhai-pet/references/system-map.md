# 山海万灵系统图

## Permanent data

- Account record: `data_xiand/accounts/<suffix>/<account>.pets.json`
- Authority: `gamelib/single/daemons/petd.pike`
- Modules:
  - `_pet_mod/catalog.pike`: species, roles, elements, skills, balance constants
  - `_pet_mod/growth.pike`: level/star caps, evolution, five attributes, power,
    PVE growth and compressed PVP growth
  - `_pet_mod/persistence.pike`: validation, cache, atomic save, corruption rules
  - `_pet_mod/collection.pike`: starter, active assignment, growth, materials,
    hunting, exchange, hatch, cosmetic unlock, login reconciliation
  - `_pet_mod/rift.pike`: teams, rounds, rewards, eggs, pity, weekly choice
  - `_pet_mod/duel.pike`: invitations, standard teams, rewards, anti-farming
  - `_pet_mod/assist.pike`: bounded PVE/PVP profiles, runtime effect, room and
    battle snapshots, fast-decision pet profile

Never bulk-migrate legacy player saves. Merely viewing the pet entry must not
create the account pet file. If physical pet data exists but cannot validate,
fail the pet feature closed without blocking character login.

## Player-facing entry points

- Commands: `pet`, `daily_cultivation`, `pet_hunt`, `wanling_rift`,
  `wanling_join`, `pet_duel`
- Room: `gamelib/d/wanling/wanlingtai`
- Legacy home navigation: `[万灵:pet]`
- Vue quick tool: `sendQuickCommand('pet')`
- Guide: `gamelib/cmds/newbie_guide.pike`
- Canonical documentation: `docs/shanhai-wanling-system.md`

## Acquisition baseline

- Level 15 starter: choose one of 当康、鹿蜀、文鳐鱼 for free.
- Exchange species: spend 30 earned spirit marks through the catalog detail.
- Rift species: win the weekly 3–5-player rift; a complete egg has a low drop
  chance and a 30-win pity. Spend 60 fragments for deterministic hatching.
- Daily hunt: actively start with an equipped pet and defeat three ordinary
  monsters no more than five levels below the player.
- Materials stay in the pet material mapping and never enter backpack, sell,
  destroy, shared-storage, or auto-loot flows.

## Runtime ownership

Permanent active assignments map physical character IDs to pet IDs. The current
player object caches identity, level, star, bond, evolution, five attributes,
power, PVE/PVP growth, skill set, PVE cooldown, PVP target/charge/uses, event
sequence, and the immutable recent assist event under `/tmp/wanling/`. Clear
combat state when selecting/removing/reconciling a pet and on `_clean_fight()`.
Do not persist charge, cooldown, targets, or animation state.

## Validation map

- Pike: `test_unit/test_shanhai_pet_system.pike`
- Vue state: `vue_source/tests/battle-state.test.js`
- Build/template: `vue_source/tests/build-pipeline.test.js`
- Full runtime: `./scripts/restart_with_testunit.sh`
- Unified artifacts: `./scripts/build/build_vue_frontend.sh`
- Multi-character bootstrap: `test_unit/test_multi_character_account.pike` and
  `test_unit/test_http_thread_architecture.pike`

The targeted pet test must cover all professions, read-only legacy behavior,
unique IDs, duplicate conversion, level/star/bond caps, evolution thresholds,
deterministic attributes and skill sets, inventory isolation, sibling ownership,
hunt anti-repeat, PVE cooldown, PVP charge/two-use/no-last-hit rules,
fast-decision snapshots, battle presence/event identity, full-resource
zero-value feedback, rift anti-small-account rules, reward idempotency, duel
anti-farming, corruption, and wiring.

After changing login reconciliation, repeat the real account HTTP chain:
`/api/account/login` -> `/api/account/characters/create` ->
`/api/account/characters/select` -> `/api/json` with `bootstrap_command`.
Require profession initialization to run on the Backend thread and require a
runtime failure to leave Vue on the recoverable character selector.
