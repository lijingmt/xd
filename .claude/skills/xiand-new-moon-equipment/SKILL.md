---
name: xiand-new-moon-equipment
description: Maintain, extend, audit, balance, or debug Xiand's New Moon six-collection profession equipment system. Use for 新月/曜星/天穹/太虚/太初/寰极套装, 12-profession 10-piece equipment, full-set skills, rare drops, collection quality, dynamic equipment generation, reforging/forging/socketing, bind-on-use and limited trading, personal/shared warehouse persistence, old JSP or Vue equipment display, cross-Worker saves, or related TestUnit and restart validation in /usr/local/games/xiand.
---

# Xiand New Moon Equipment

## Start here

Preserve the system as one data-driven lineage: 120 validated base templates
(12 professions × 10 slots) map to six collection identities. Do not copy the
templates into 720 source files and do not alter core combat formulas.

Read [architecture.md](references/architecture.md) before changing collection
identity, generation, drops, binding, storage, or display. Read
[validation.md](references/validation.md) before writing tests, committing, or
reporting completion.

Also apply the repository skills for Pike coding, Pike review, equipment
forge/fusion, unit testing, Xiand development validation, map Workers, frontend
playability, and English Git commits when those surfaces are touched.

## Required workflow

1. Inspect the branch, recent collection commits, and dirty files. Preserve all
   unrelated player/runtime data.
2. Identify the layer being changed:
   - catalog/drop selection: `gamelib/single/daemons/itemsd.pike`
   - identity, quality, set counting, binding: `lowlib/mudlib/inherit/feature/equip.pike`
   - full-set skill identity and activation: `gamelib/single/daemons/newmoon_set_skilld.pike`
   - rank-safe skill base: `gamelib/inherit/newmoon_set_skill.pike`
   - profession skill implementations: `gamelib/single/skills/newmoon_*`
   - unified old/new UI name: `lowlib/mudlib/inherit/item.pike`
   - personal warehouse row: `gamelib/inherit/packaged.pike`
   - shared warehouse validation: `gamelib/single/daemons/account_storaged.pike`
   - base registrations and affixes: `gamelib/data/orgItems.list` and
     `gamelib/data/allItems.list`
3. Add or update focused TestUnit coverage before treating the code as done.
4. For a new collection, add one catalog record and keep its rank immutable.
   Reuse the 120 bases; encode identity in the generated source and filename.
5. Preserve old equipment and first-generation New Moon behavior. Any collection
   lookup must first prove the item has New Moon resonance metadata.
6. Preserve bind-on-use and storage schemas. Never trust display names, pictures,
   client prices, or client-supplied collection IDs as identity.
7. Restart through the real game environment and run the complete TestUnit suite.
   Restore the local active Worker topology and inspect health/logs.
8. Review the exact staged files and commit only task files. For staged rollouts,
   commit each collection only after its own restart passes.

## Non-negotiable invariants

- Keep 12 professions × 10 non-conflicting slots complete.
- Keep normal equipment drops separate from the rare collection pool.
- Keep each collection's probability stable when rarer collections are added;
  consume unmet high-rank rolls instead of falling through to a lower rank.
- Scale only equipment base attack/defense through collection quality. Keep
  affixes, set bonuses, and core damage formulas separate to avoid compounding.
- Compare collection ID, profession, theme, actual equipped slot, durability,
  and object uniqueness when counting set pieces.
- Keep raw drops freely tradable. Bind on first equip, reforge, socket, or artisan
  mutation. A bound item may use the same-account shared warehouse but may not be
  dropped, gifted, traded, auctioned, or stalled across accounts.
- Keep the player profile as the unique player save. Collection identity must
  survive regular saves, cross-Worker handoff, dynamic source reload, and both
  warehouse directions.
- Derive full-set skills from the ten objects actually equipped. Never persist a
  duplicate learned-skill flag, rank, or owner in a Worker-local cache.
- Require one profession, one collection ID, ten unique objects, ten unique
  equipped slots, usable durability, active resonance, and matching owner before
  exposing a set skill. Mixed or broken sets fail closed immediately.
- Keep set-skill cooldown in the existing player combat cooldown mapping so
  unequip/re-equip, collection swaps, saves, and Worker handoff cannot reset it.
- Keep old JSP and Vue displays consistent by decorating both `query_name_cn()`
  and `query_short()` without mutating the raw internal name.
- Fail closed on unknown IDs, malformed snapshots, ownership mismatch, missing
  templates, incomplete 120-item registration, or generated-source failure.

## Common change patterns

### Add a collection

1. Choose a permanent ASCII ID, Chinese name, quality label, rank, minimum NPC
   level, minimum affix count, and integer weight under the common denominator.
2. Append it to the catalog in ascending rank and update the enabled count only
   when the collection is ready.
3. Add the same immutable ID metadata to the equipment getter/setter whitelist and
   warehouse snapshot whitelist.
4. Give ranks above one an unambiguous generated filename suffix. Do not reuse a
   suffix for a different collection.
5. Extend the generic collection matrix and exact roll-window tests.
6. Restart, validate, and make a standalone commit before enabling the next rank.

### Add or change a full-set skill

1. Keep the skill name stable and ASCII-only. Register it in the daemon catalog
   for exactly one profession.
2. Reuse existing combat types and damage/heal helpers. Do not introduce or
   silently change core physical, magical, healing, defense, or PvP formulas.
3. Use the active collection rank as the virtual skill level. The player must not
   learn, forget, save, or warehouse the skill itself.
4. Integrate the virtual skill through the common skill resolver so legacy JSP,
   Vue, toolbar, manual perform, and auto-fight queue share one authorization path.
5. Preserve cooldown when the full set becomes temporarily inactive. Remove the
   unusable queue entry, not its already-running cooldown.
6. Prove all 12 professions and ranks 1..6, incomplete/mixed/broken sets,
   reactivation, cooldown persistence, toolbar use, and auto-fight use in TestUnit.

### Change balance

Change catalog level/weight/affix data or collection base-quality percentages.
Do not edit physical/magical damage formulas as part of an equipment request.
Prove old New Moon output is unchanged and collection output remains monotonic.

### Fix forge or warehouse loss

Trace identity from the object, not from `query_name_cn()`, picture, or file
basename. Verify original → generated → reforged and personal → shared → other
character → restored round trips. Test bound and unbound rows separately.

### Fix UI naming

Keep raw source names backward compatible. Apply a dynamic collection label for
both legacy commands and JSON/Vue callers, and prove no stale `【新月·职业】`
prefix remains on higher collections.

## Completion gate

Do not claim completion or push merely because Pike compiles. Require:

- focused collection tests pass inside TestUnit;
- complete TestUnit reports zero failures;
- generated test files are cleaned;
- local HTTP health responds;
- active Worker count and health match the requested topology;
- logs contain no new compile, storage, transaction, or runtime exception;
- staged diff excludes player profiles, generated frontend timestamps, logs, and
  runtime Worker state.
