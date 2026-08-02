# 山海万灵系统图

## Permanent data

- Account record: `data_xiand/accounts/<suffix>/<account>.pets.json`
- Authority: `gamelib/single/daemons/petd.pike`
- Modules:
  - `_pet_mod/catalog.pike`: species, roles, elements, skills, balance constants
  - `_pet_mod/persistence.pike`: validation, cache, atomic save, corruption rules
  - `_pet_mod/collection.pike`: starter, active assignment, growth, materials,
    hunting, exchange, hatch, cosmetic unlock, login reconciliation
  - `_pet_mod/rift.pike`: teams, rounds, rewards, eggs, pity, weekly choice
  - `_pet_mod/duel.pike`: invitations, standard teams, rewards, anti-farming
  - `_pet_mod/assist.pike`: bounded PVE profile, runtime effect, battle snapshot

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
player object caches only `/tmp/wanling/pet_id`, `species`, `skill_set`,
`assist_at`, `assist_seq`, and the immutable recent assist event. Clear stale
visual events when selecting/removing/reconciling a pet. Do not persist combat
animation state.

## Validation map

- Pike: `test_unit/test_shanhai_pet_system.pike`
- Vue state: `vue_source/tests/battle-state.test.js`
- Build/template: `vue_source/tests/build-pipeline.test.js`
- Full runtime: `./scripts/restart_with_testunit.sh`
- Unified artifacts: `./scripts/build/build_vue_frontend.sh`

The targeted pet test must cover all professions, read-only legacy behavior,
unique IDs, duplicate conversion, caps, deterministic skill sets, inventory
isolation, sibling ownership, hunt anti-repeat, PVE/PVP boundaries, battle
presence/event identity, full-resource zero-value feedback, rift anti-small-
account rules, reward idempotency, duel anti-farming, corruption, and wiring.
