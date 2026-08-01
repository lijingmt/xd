---
name: xiand-new-profession
description: Design, implement, audit, balance, test, document, or extend a complete Xiand profession. Use when adding a character class or profession, adding a neutral profession, comparing a new class with legacy classes, creating profession skills/books/equipment/tasks/hidden drops, or checking that a profession works from character creation through high-level play, Vue UI, auto-fight, social systems, restart, and TestUnit validation.
---

# Xiand New Profession

Build a profession as a complete player lifecycle, not as a collection of skill
files. Treat active source and runtime behavior under `/usr/local/games/xiand`
as authoritative. Read `references/integration-map.md` before editing and use
`references/ten-pass-audit.md` for final review.

## Non-negotiable contracts

- Choose one stable lowercase ASCII profession ID and one Chinese display name.
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
- Preserve per-book hidden-drop probability when expanding a uniform pool.
- Keep generated equipment, normal drops, Boss drops, forge restrictions,
  auto-equip, storage, trade, and item descriptions profession-compatible.
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
  fangshi --name-cn 方士
```

Use missing checks as investigation leads; the script is not proof of runtime
correctness.

### 2. Write the class contract

Record the profession ID/name, race, combat role, primary/secondary attributes,
resource loop, solo loop, team loop, PvP counterplay, equipment policy, skill
milestones, advanced replacements, and three hidden skills. Define numeric caps
and failure behavior before implementing mechanics.

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

Cover early survival, basic offense, class-defining utility, team contribution,
midgame growth, level-70 progression, and three level-80+ hidden skills. Use the
existing five-stage model for new scalable abilities unless a historical format
requires otherwise.

### 5. Integrate shared systems

Run the audit script for the new ID, then reverse-scan old profession arrays and
branches. Check every row in the Shared systems section of the integration map.
Do not special-case only one shop or one equipment generator.

### 6. Add player-facing guidance

Expose role and controls during character selection. Make the state-based newbie
guide require real actions and provide direct task navigation where supported.
Show skill acquisition, team use, current status/resource, cooldown failures,
level unlocks, and high-level goals in both legacy and Vue paths.

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
- Starter skill and equipment are granted, equipped, and usable.
- Books can be acquired and learned through real inventory actions.
- Solo combat, team role, death, movement, logout, reconnect, auto-fight, and
  offline behavior work without stale state.
- Equipment can drop, be forged, viewed, worn, removed, sold, stored, and traded
  under the intended policy.
- Tasks, maps, home, guild, ranking, chat, transfer, warehouse, dungeon, PvP, VIP,
  feedback, and high-level progression do not reject the profession accidentally.
- Three hidden books remain drop-only and equally rare per book.
- Vue and legacy UI show the correct identity, skills, status, and guidance.
- Targeted tests plus full TestUnit pass after a real restart; logs contain no
  compile/runtime errors; both service ports respond.
- Versioned Markdown/PDF handbooks are regenerated and visually verified when
  relevant; temporary renders and runtime data are excluded from the commit.
- Source, tests, skill documentation, intended assets, and current handbooks are
  committed and pushed.
