---
name: xiand-new-profession
description: Design, implement, audit, balance, test, document, or extend a complete Xiand profession. Use when adding a character class or profession, adding another profession under the neutral third race, comparing a new class with Fangshi, Zhenyue, Tianxiang, Lingyi, or legacy classes, creating profession skills/books/equipment/tasks/hidden drops, or checking that a profession works from character creation through high-level play, Vue UI, auto-fight, social systems, deployment, restart, and TestUnit validation.
---

# Xiand New Profession

Build a profession as a complete player lifecycle, not as a collection of skill
files. Treat active source and runtime behavior under `/usr/local/games/xiand`
as authoritative. Read `references/integration-map.md` before editing and use
`references/profession-checklist.md` as the implementation gate. Use
`references/ten-pass-audit.md` for final review.

## Non-negotiable contracts

- Choose one stable lowercase ASCII profession ID and one Chinese display name.
- Treat race and profession as separate axes. The neutral race `third` already
  contains Fangshi, Zhenyue, Tianxiang, and Lingyi; never equate `third` with one profession or
  let a two-race `else` branch select a neutral profession accidentally.
- The post-Lingyi 2026-08-02 baseline has ten active professions and 31 hidden mythic
  books. Never hard-code those totals in new generic logic: enumerate the
  authoritative catalog/pool and test that adding one profession grows every
  dependent set exactly once.
- Reuse an existing race only after defining its faction, PvP, facility, chat,
  task, equipment, ranking, and migration behavior.
- Make creation idempotent: set identity, starter stats, starter skill, starter
  equipment, valid room, silent auto-equip, guide state, and save exactly once.
- Make login migration additive and idempotent. Never overwrite legitimate
  learned skills, equipment, progress, money, or player choices.
- A bought or dropped book enters inventory first. Learning happens through its
  real `[学习:read ...]` action and must enforce level, profession, prerequisite,
  duplicate, and consumption rules.
- Every described skill effect must exist in runtime code. Do not promise taunt,
  healing, shielding, group protection, control, or scaling through text alone.
- Give every stateful class mechanic an ownership and cleanup matrix covering
  move, team change, target change, death, logout, disconnect, expiry, recast,
  replacement, daemon reload, and stale/dead/cross-room objects.
- Serialize every server-owned profession resource in both legacy and Vue
  battle state. Expose only derived display values; never let the client submit
  stacks, expiry, strength, duration, or target ownership.
- Preserve per-book hidden-drop probability when expanding a uniform pool. In
  the current one-roll-per-monster design, adding three books means growing both
  the pool and shared numerator by three, not silently diluting old books. The
  current ten-profession baseline is 31 books at 31/100000 because Lingyi has
  one deliberate extra hidden group-heal inheritance.
- Keep generated equipment, normal drops, Boss drops, forge restrictions,
  auto-equip, storage, trade, and item descriptions profession-compatible.
- Audit profession-limited medicine in `food`, `water`, `liandan`, and `teyao`;
  a class that can equip gear but cannot consume normal recovery items is not
  complete.
- Add the display name, rank tag, default unnamed title, top-list/game-list
  identity, logo, male/female avatars, both image mirrors, Vue use, and Docker
  asset copy. Distinct files must contain distinct intended images.
- Treat session activity as a gameplay boundary: real player commands renew
  activity, read-only HTTP status/battle/room polling does not, active automatic
  combat may renew activity, and online lists must use the same idle/VIP policy
  as the kick daemon.
- Use bounded effects: no permanent invulnerability, unbounded reflection,
  resurrection side effects, arbitrary remote effects, or percent damage without
  player/Boss caps.
- Add runtime TestUnit coverage before calling the profession complete.

## Workflow

### 1. Establish the baseline

Inspect `git status`, the active branch, running ports, and existing TestUnit
summary. Preserve runtime data and unrelated user changes. Compare at least one
physical, one magical, and one special-role profession. Run:

```bash
python3 .claude/skills/xiand-new-profession/scripts/audit_profession.py \
  zhenyue --name-cn 镇越 --race third --expect-hidden 3 --require-assets
```

Use missing checks as investigation leads; the script is not proof of runtime
correctness. If a historical class uses a nonstandard image prefix, pass
`--asset-prefix`; use `--allow-missing AREA` only for a documented generic or
intentional route, never to hide unfinished integration.

### 2. Write the class contract

Record the profession ID/name, race, combat role, primary/secondary attributes,
resource loop, solo loop, team loop, PvP counterplay, equipment policy, skill
milestones, advanced replacements, declared hidden skills, task route, avatar
policy, auto-fight policy, and VIP-assistant policy. Define numeric caps, effect
ownership, cleanup triggers, server authority, and failure behavior before
implementing mechanics. Fill the contract block in
`references/profession-checklist.md` before writing Pike.

Prefer a distinctive loop with counterplay over inflated coefficients. A tank,
for example, needs reliable threat, bounded mitigation, a useful solo damage
conversion, same-room team protection, explicit death/logout cleanup, and visible
feedback. It does not need immunity.

### 3. Wire identity and creation

Implement every identity surface in the first two sections of
`references/integration-map.md`. Add creation and migration tests using real
`GAMELIB_USER` objects. Verify exact initial and level-scaled attributes at more
than one level.

### 4. Implement progression vertically

Add each milestone as a vertical slice:

1. Skill runtime object.
2. Book runtime object and inventory learning link.
3. Catalog, teacher, drop, task, or high-level acquisition route.
4. Level/profession/prerequisite/duplicate checks.
5. Runtime effect test and UI visibility.

For passive books, test learning with a cold/uninitialized skill registry. For
active skills, reject forged use by a character who has not learned the skill.
For purchases, reject an unknown type/path, cross-profession detail request,
stale daily selection, and forged client price.

Cover early survival, basic offense, class-defining utility, team contribution,
midgame growth, level-70 progression, and the declared level-80+ hidden skills. Use the
existing five-stage model for new scalable abilities unless a historical format
requires otherwise.

### 5. Integrate shared systems

Run the audit script for the new ID, then reverse-scan old profession arrays,
fixed totals, race branches, shop type branches, hidden pools, UI choices, image
copy lists, medicine restrictions, tests, and documentation builders. Check
every row in the Shared systems section of the integration map. Do not
special-case only one shop, one image directory, or one equipment generator.

### 6. Add player-facing guidance

Expose role and controls during character selection. Make the state-based newbie
guide require real actions and provide direct task navigation where supported.
Show skill acquisition, team use, current status/resource, cooldown failures,
level unlocks, and high-level goals in both legacy and Vue paths.
Require the level-20 restricted reward, the level-53 chained book route, and the
continuous growth-task path unless the class contract documents and tests a
deliberate alternative.

### 7. Regenerate versioned handbooks

When player-facing mechanics, balance, progression, acquisition, equipment,
VIP, tasks, maps, or UI behavior changes, update the appropriate builder:

- `docs/build_xiand_profession_guide.py` for lifecycle, progression, equipment,
  maps, shared systems, and profession-facing UI.
- `docs/build_xiand_skill_guide.py` for skills, books, drops, learning rules, and
  combat balance.

Treat the builder source as authoritative. Run every relevant builder and commit
both the stable-name Markdown and PDF under `docs/`. Never commit `tmp/pdfs`,
`__pycache__`, or other render intermediates. Render every changed PDF with
`pdftoppm`; inspect the cover, every changed section, affected tables, and the
last page; use `pdfinfo` and text extraction to verify the page count, branch,
commit baseline, and date. A Desktop copy is a delivery convenience, not the
versioned source of truth.

### 8. Validate and review

Run the ten independent passes in `references/ten-pass-audit.md`. After every
Pike change, perform a full restart through the repository restart/TestUnit
script, inspect the summary and error log, verify ports 13800 and 8888, then run
targeted HTTP/Vue/load checks. Static grep and compile-only checks are supporting
evidence, never completion evidence.

## Pike editing rules

- Apply the repository Pike coding and code-review skills before Pike edits.
- Find a compiling historical precedent for every syntax pattern.
- Use `apply_patch`; preserve surrounding style and avoid broad rewrites.
- Never `return` from inside `catch`.
- Treat `this_player()` and `this_object()` context as mutable shared state.
- Serialize same-player mutations; use a global lock for cross-player/shared
  economy mutations; keep pure reads parallel when proven safe.
- Clean timers, registries, threat/guard links, and temporary buffs on death,
  logout, move, owner loss, expiry, and replacement.

## Definition of done

Completion requires all of the following:

- Character can be created, saved, restored, and migrated.
- Multiple professions under the selected race remain independently selectable;
  selecting one never rewrites or inherits another profession accidentally.
- Starter skill and equipment are granted, equipped, and usable.
- Books can be acquired and learned through real inventory actions.
- Solo combat, team role, death, movement, logout, reconnect, auto-fight, and
  offline behavior work without stale state.
- Equipment can drop, be forged, viewed, worn, removed, sold, stored, and traded
  under the intended policy.
- Tasks, maps, home, guild, ranking, chat, transfer, warehouse, dungeon, PvP, VIP,
  feedback, and high-level progression do not reject the profession accidentally.
- Every declared hidden book remains drop-only and equally rare per book; a
  deliberate extra grows both pool and shared numerator and is documented.
- Stateful mechanics reject dead, stale, cross-room, cross-team, unlearned, and
  forged inputs and clean every owned effect at all lifecycle boundaries.
- Vue and legacy UI show the correct identity, skills, status, guidance, logo,
  and gender avatar; deployment includes the same verified assets.
- Newbie medicine, ordinary medicine, smart auto-fight, level-gap tasks,
  profession shop, advanced rotation, and optional PVE-only profession assistant
  have an explicit pass or documented intentional exclusion.
- Targeted tests plus full TestUnit pass after a real restart; logs contain no
  compile/runtime errors; both service ports respond.
- Versioned Markdown/PDF handbooks are regenerated and visually verified when
  relevant; temporary renders and runtime data are excluded from the commit.
- Source, tests, skill documentation, intended assets, and current handbooks are
  committed and pushed.
