---
name: fangshi-system
description: Develop, audit, debug, balance, or extend the Xiand 方士 profession. Use for neutral third/fangshi character creation, skill books and learning, self/team healing, tiger/crane/turtle summons, 灵契共鸣, hidden mythic drops, advanced replacements, equipment/drop/forge compatibility, newbie guidance, jade purchasing, shared-system parity, TestUnit, restart validation, or push preparation.
---

# Xiand Fangshi System

Treat Fangshi as an end-to-end profession. Trace every change from character
creation through high-level progression and shared game systems. Use the
current source under `/usr/local/games/xiand` as the authority; do not trust
old comments or historical design notes without checking active code.

## Core contracts

- Represent Fangshi as race `third` and profession `fangshi`.
- Give new characters `lingdanshu`; never reintroduce removed `lingshu`.
- Keep Fangshi neutral: share supported human/monster facilities and social
  actions, but reject faction conversion before consuming its item.
- Preserve the real learning flow: buy or loot book, receive it, use the
  inventory `[学习:read ...]` action, pass level/profession checks, then learn.
- Cap five-stage skills at five. Preserve legacy ten-stage behavior where the
  skill really configures ten stages.
- Preserve all utilities after `spec_read(old_skill)` removes the old key.
  `huling_mystic` must still summon tiger and `sanlingheyi2` must still summon
  all three spirits.
- Clone every summon and clean its daemon record on dismissal, death, expiry,
  logout, or owner loss.
- Never revive a dead player through healing, crane AI, or resonance.
- Keep hidden mythic books drop-only, equally rare, level/profession gated, and
  absent from all stores and teachers.
- Do not report completion from static searches alone. Use real player objects,
  real book reads, real skills/summons/equipment, full TestUnit restart, ports,
  and logs.

## Architecture

### Identity and lifecycle

| Area | Source |
| --- | --- |
| Character choice/start/migration | `gamelib/d/init` |
| Identity and neutral helpers | `lowlib/mudlib/inherit/feature/char.pike` |
| Initial stats | `lowlib/mudlib/inherit/user.pike` |
| Level growth | `lowlib/mudlib/inherit/feature/level.pike` |
| Login/logout lifecycle | `gamelib/clone/user.pike` |

Creation must call `setup_player("third", "fangshi")`, grant `lingdanshu`,
starter weapon/armor, run silent auto-equip, choose a valid starter room, and
save. Login migration must idempotently remove `lingshu`, grant missing
`lingdanshu`, and repair old `lingzhihun` passive state when required.

### Learning and UI

| Area | Source |
| --- | --- |
| State-based guide | `gamelib/cmds/newbie_guide.pike` |
| Auto-equip | `gamelib/cmds/auto_equip.pike` |
| Teacher | `gamelib/clone/npc/fangshi_teacher.pike` |
| Book catalog | `gamelib/data/can_buy_book_list.csv` |
| Book learning | `lowlib/mudlib/inherit/feature/readed.pike` |
| Skill pages | `gamelib/cmds/myskills.pike`, `lowlib/wapmud2/inherit/feature/skills.pike` |

Books may store either Chinese profession name `方士` or ID `fangshi`;
`read()`, `beidong_read()`, and `spec_read()` must accept both. Buying a book
does not learn it. The guide must inspect real inventory/equipment/skill state,
not mark progress from button clicks.

Important early milestones:

- Level 1: `lingdanshu`
- Level 2: `lingren`
- Level 8: `lingzhi`
- Level 10/15/20: tiger/crane/turtle
- Level 24: `linglianpu`
- Level 50: `sanlingheyi`

### Combat and skill proficiency

| Area | Source |
| --- | --- |
| Attack/defense formulas | `lowlib/mudlib/inherit/feature/attack.pike` |
| Skill execution/effects | `lowlib/wapmud2/inherit/feature/fight.pike` |
| Configured skill cap | `lowlib/wapmud2/inherit/skill.pike` |
| Proficiency/UI | `lowlib/wapmud2/inherit/feature/skills.pike` |
| Proficiency medicine | `gamelib/cmds/skill_eat_teyao.pike` |

Verify runtime effects rather than descriptions. Check `s_skill_type`,
`s_curse_type`, damage/heal/debuff mappings, cooldown, duration, mofa cost,
configured level gates, and actual post-cast state.

Healing rules:

- `lingzhi` heals the caster.
- `linglianpu` always heals the caster and also living same-room teammates.
- Without a real team, `linglianpu` heals only the caster.
- Never heal outsiders, remote teammates, or dead members.
- Honor `curse/life` healing reduction and maximum-life caps.
- `lingzhi_mystic` must preserve the base healing role.

Most Fangshi active skills have five configured stages and must stop training
at level five. A skill with one character-level gate may still use the legacy
ten-level proficiency model; `lingbailei11` is the important regression case.

## Summons and resonance

| Area | Source |
| --- | --- |
| Player command | `gamelib/cmds/summon.pike` |
| Registry/resonance | `gamelib/single/daemons/summond.pike` |
| Base summon | `gamelib/clone/npc/summon/base_summon.pike` |
| Tiger/crane/turtle | `gamelib/clone/npc/summon/{huling,heling,guiling}.pike` |

Summon limits are one below level 30, two at levels 30-59, and three at level
60+. Resolve replacement aliases before authorization and scaling:

- `huling_mystic` replaces `huling` but still authorizes tiger.
- `sanlingheyi2` replaces `sanlingheyi` but still authorizes all three spirits.

`summon resonance` uses only living summons in the owner's current room:

- Tiger reduces only currently cooling Fangshi skills by a bounded amount.
- Crane heals living same-room team members and never revives.
- Turtle removes supported DOT/curse effects.
- Perfect three-spirit resonance restores bounded mofa and clears public
  `timeCold`, without globally erasing arbitrary per-skill cooldowns.
- Persist cooldown under `/plus/fangshi/resonance_until`.
- Normal/perfect cooldowns are 90/120 seconds.

Do not set `_tasknpc = 1` on summons. Do not use `time() % n` as heartbeat
cadence; use an explicit counter. Summon death intentionally bypasses ordinary
monster drops.

## Advanced and hidden progression

Normal replacement graph:

```text
lingbailei   -> lingbailei11
lingxuanying -> lingxuanying2
sanlingheyi  -> sanlingheyi2
lingchuanxin -> lingchuanxin2
```

Mystic replacement graph:

```text
lingxuan    -> lingxuan_mystic
linghuoshao -> linghuoshao_mystic
lingzhi     -> lingzhi_mystic
lingdun     -> lingdun_mystic
huling      -> huling_mystic
```

### Hidden mythic books

`gamelib/single/daemons/itemsd.pike` owns the nine-book pool and deterministic
boundary helper. `gamelib/inherit/npc.pike` owns team and solo death wiring.

Fangshi:

- `taixulingyun`
- `wanlingchaosheng`
- `sixiangfengjin`

Parity professions:

- Yushi: `jiutianleiyin`, `taiyixuanguang`, `bingpochanshen`
- Wuyao: `huangquanwudu`, `wanxiangshihun`, `jiuyouduzhang`

Drop and economy contract:

- Gate on the killed monster object's actual `query_level() >= 70`.
- Use total rate `9/100000`; select uniformly from nine books, making each
  book's long-run rate about `1/100000`.
- Roll exactly once per monster for team Boss, team normal, and solo kills.
  Keep the team roll before `if(this_object()->_boss)` so Bosses cannot bypass
  it. Never multiply the roll by team size.
- Protect team/player ground ownership for 120 seconds and remove an unclaimed
  drop after five minutes.
- Permit ordinary pickup, drop, trade, send, and storage.
- Enforce level 80 and profession on `read()`. Duplicate learning must not
  consume the book.
- Append every successful drop to `log/hidden_skill_drop.log`.
- Never add these books to `can_buy_book_list.csv`, a teacher, or the advanced
  shop.

Dynamic scaling is separate from hidden-drop eligibility:

- Ordinary non-peaceful overworld rooms start dynamic NPC scaling at player
  level 50.
- Dynamic NPC level is requested player level plus `random(3)`, capped at 500;
  dynamic NPCs also have a 0.5% Boss roll.
- Registered ordinary dungeons suppress dynamic scaling. `posanzhidi` is the
  explicit exception.
- Fixed and dungeon monsters still qualify when their actual level is 70+.
- City-war keeper/guard/lord deaths use a separate honor flow and do not use
  ordinary hidden drops.

## Equipment, economy, and shared systems

Fangshi currently has no dedicated equipment set. It intentionally uses all
restricted legacy equipment routes through:

- `lowlib/mudlib/inherit/feature/equip.pike`
- `gamelib/single/daemons/itemsd.pike`
- `gamelib/single/daemons/bossdropd.pike`
- `gamelib/cmds/auto_equip.pike`

Test actual `wear()`/`wield()` for existing and dynamically generated gear.
Preserve slot, two-hand, level, attribute, profession, and task restrictions.

Jade purchases must use total-value automatic denomination conversion and
change through `YUSHID->have_enough_yushi()` and `YUSHID->pay_yushi()`. Do not
reintroduce manual break/exchange steps in individual shops.

Include these profession-generic systems in every full audit:

- Tasks, dungeons, home, guild, ranking
- Team, trade, send, whisper, friends, follow
- Transfer, rest, warehouse, post, honor stores
- Offline training and auto-fight
- Birth, relife, fall-death recovery, login/logout

## Required audit workflow

1. Inspect branch, status, and dirty/generated files.
2. Compare creation, migration, attributes, and identity maps.
3. Test starter equipment, auto-equip, guide, attack, and first healing.
4. Test book catalog, purchase, inventory link, real read, return codes, and
   profession/level gates.
5. Test configured caps, proficiency UI/medicine, and an old ten-stage skill.
6. Test summon creation, scaling, combat, following, death, expiry, logout,
   limits, resonance, and replacement aliases.
7. Test equipment generation/drop/wear/forge and high-level purchases.
8. Test tasks, dungeons, home, guild, ranking, social, offline, and auto-fight.
9. Reverse-scan old six-profession and two-race hardcodes.
10. Review Pike syntax against historical precedents, restart the full suite,
    inspect logs, and verify both ports.

For shared drops, scan every NPC/dungeon `fight_die()` override and require a
parent `::fight_die()` call unless it is an explicit no-drop class. The expected
deliberate exception is `gamelib/clone/npc/summon/base_summon.pike`.

## Test and restart contract

Core tests:

| Test | Coverage |
| --- | --- |
| `test_fangshi_full_chain.pike` | Creation through advanced progression |
| `test_fangshi_system_parity.pike` | Neutral/shared-system parity |
| `test_fangshi_spirit_resonance.pike` | Resonance and alias boundaries |
| `test_hidden_mythic_skills.pike` | Nine-book pool, dynamic level, Boss wiring, learning, economy, effects |
| `test_auto_equip_assistant.pike` | Seven professions and equipment rules |
| `test_equipment_drop_fangshi.pike` | Normal/Boss generated equipment |
| `test_skill_book_learning.pike` | Book restrictions and return codes |
| `test_yushi_auto_exchange.pike` | Jade conversion and purchase flows |

After every Pike change:

```bash
cd /usr/local/games/xiand
git diff --check
./startup.sh
```

Require:

- `[TESTUNITD] COMPLETE ... failed=0`
- Game port `13800` listening
- HTTP port `8888` listening
- No task-related compile, syntax, null-indexing, or runtime errors

Regression floor verified on 2026-07-29:

- TestUnit files: 13 passed, 0 failed, 4 helper scripts skipped
- Inner assertions: 125 passed
- `test_fangshi_full_chain`: 14/14
- `test_fangshi_system_parity`: 13/13
- `test_fangshi_spirit_resonance`: 7/7
- `test_hidden_mythic_skills`: 9/9

The local environment may still report missing MySQL databases `xd`/`xd01`
while loading ranking or auction daemons. Report this honestly, but do not
misclassify it as a Fangshi compile failure.

## Push safety

- Apply Pike syntax, code-review, and validation skills before editing/pushing.
- Preserve runtime/generated files such as `data_xiand/**`,
  `gamelib/data/topten.s`, `gamelib/data/uniq_user/**`, `log/**`,
  `web/web_vue/index.html`, and `web/web_vue/manifest.json` unless explicitly
  requested.
- Use English conventional commit messages.
- Commit or push only on explicit user request.
