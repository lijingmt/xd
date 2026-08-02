# Xiand profession integration map

## Identity and lifecycle

| Concern | Primary source | Runtime proof |
| --- | --- | --- |
| Race/profession selection | `gamelib/d/init` | choose class through the real room action |
| Initial stats | `lowlib/mudlib/inherit/user.pike` | clone `GAMELIB_USER`, call `setup_player` |
| Names and faction helpers | `lowlib/mudlib/inherit/feature/char.pike` | query ID/CN, room and PvP policy |
| Level growth | `lowlib/mudlib/inherit/feature/level.pike` | exact stats at levels 1, 30, 80, 120 |
| Combat formulas | `lowlib/mudlib/inherit/feature/attack.pike` | damage, defense, hit, dodge, crit boundaries |
| Login/logout/migration | `gamelib/clone/user.pike`, `gamelib/d/init` | old and new save-shaped users, reconnect twice |
| Default and shared identity | `lowlib/system/inherit/base.pike`, `look_top.pike`, `my_games.pike` | unnamed title, top/game lists, logs |
| Avatar and logo | `images/`, `web/images/`, init/avatar tests, Vue header | male/female/default fallback and distinct bytes |
| Deployment | `restart-docker.sh`, `rebuild-image.sh`, Vue build scripts | container/Tomcat assets match source |

Current baseline is six legacy professions plus neutral Fangshi, neutral
Zhenyue, and neutral Tianxiang: nine professions in total. Derive profession
totals from authoritative data. Never make array length `9`, hidden count `27`,
or `third == fangshi` part of generic behavior.

## Skills and acquisition

| Concern | Primary source |
| --- | --- |
| Skill definitions | `gamelib/single/skills/` |
| Skill engine | `lowlib/wapmud2/inherit/feature/fight.pike` |
| Skill caps/proficiency | `lowlib/wapmud2/inherit/skill.pike`, `feature/skills.pike` |
| Book objects | `gamelib/clone/item/book/` |
| Read enforcement | `lowlib/mudlib/inherit/feature/readed.pike` |
| Store catalog/UI | `gamelib/data/can_buy_book_list.csv`, `buyd.pike`, `buy_items.pike` |
| Teacher | `gamelib/clone/npc/*teacher*`, both faction plaza rooms |
| High-level rotation | `gamelib/single/daemons/buyd.pike` and purchase confirmation |
| Hidden drop | `itemsd.pike`, `gamelib/inherit/npc.pike` |
| My skills/UI | `gamelib/cmds/myskills.pike`, legacy skills view, Vue parser |
| Skill factory/registry | `gamelib/single/create_skill.pike`, `MUD_SKILLSD` |

Every skill needs a real effect test. Test insufficient mofa, cooldown, invalid
target, dead caster/target, duplicate cast, replacement, expiry, and maximum
stage. Test passive learning before the registry is warmed and active-skill use
by an unlearned character. Group effects are same-room, living, real-team only
unless explicitly designed otherwise.

When three mythic books are added, update the data-driven pool and shared rate
together. At the current baseline, 27 books use a shared 27/100000 roll and then
a uniform 27-way selection, retaining about 1/100000 per book. Never fix the
pool size in unrelated UI, docs, or tests.

## Equipment and economy

- Starter weapon and armor object existence, profession restriction, level gate,
  correct slot, `wield()`/`wear()`, silent `auto_equip`.
- Existing restricted equipment compatibility in `feature/equip.pike`.
- Dynamic generation in `itemsd.pike` and `bossdropd.pike`.
- Ordinary/Boss drop ownership, pickup, inventory capacity, sell, destroy,
  auto-sell, warehouse, trade, send, and forge/fusion.
- Profession-limited recovery items under `gamelib/clone/item/{food,water,liandan,teyao}`.
- Money and jade purchase paths, including automatic jade denomination exchange.
- Task-only and bound items must retain their original restrictions.

## Shared systems

Check tasks, growth guide, level-gap tasks, maps, dynamic monsters, autofight,
offline AFK, medicine, team, invite, follow, guild, home, dungeon, ranking,
honor, PvP, faction conversion, chat, whisper, friends, trade, warehouse, post,
transfer, rest, death recovery, relife, VIP level cap, feedback, admin operations,
HTTP API player state, battle panel, and deployment/build scripts.

Neutral professions must deliberately define whether they use both factions'
facilities/tasks/chat/equipment or a dedicated neutral route. Never rely on a
two-race `else` branch accidentally granting access.

Multiple professions now share race `third`. Audit race helpers independently
from profession-specific teachers, shops, guides, ranking tags, default names,
avatars, class mechanics, and VIP assistants. Cross-faction social tests must
cover both directions and must prove an ordinary human/monster pair remains
unchanged.

### Recorded Fangshi compatibility exceptions

These explain the only expected static exemptions when Fangshi is used as a
regression baseline; they are not templates for a new profession.

- `shared_identity`: `look_top.pike` historically uses Fangshi as the `third`
  fallback instead of naming it in the branch. Its behavior is covered by
  `test_fangshi_system_parity.pike`. Every additional neutral profession still
  needs an explicit tag and must not inherit this fallback.
- `autofight`: Fangshi uses the generic auto-fight path, so the daemon has no
  Fangshi literal. `test_fangshi_edge_cases.pike::test_fangshi_autofight`
  covers the route. Add an explicit branch only when the new class mechanic
  requires one.
- Assets use the legacy `human_fangshi` prefix; audit them with
  `--asset-prefix human_fangshi`.

## Stateful role mechanics

For every class-owned object, registry, effect, threat link, team shield, DOT,
control, summon, or target array, define and test:

- authoritative owner/target/level/duration/strength;
- weaker/equal/stronger recast behavior;
- move, team change, target switch, death, logout, disconnect, owner loss,
  expiry, replacement, daemon reload, and duplicate cleanup;
- dead/destructed/cross-room/cross-team filtering;
- PvE, PvP, player-owned summon, Boss, duel, guild-war, and city-war boundaries;
- reward, PK, threat, and fast-decision attribution.

Zhenyue is the reference for finite personal/team shields, taunt/hate
multipliers, team-change cleanup, and stale AOE target removal. Fangshi is the
reference for cloned-object registries, owner cleanup, team healing, and alias
preservation. Tianxiang is the reference for a bounded server-owned temporary
resource: maximum three star marks, exact expiry/move/combat/death/logout
cleanup, HTTP/Vue serialization, and separate normal-PVE versus player/Boss
bonus caps.

## Session activity and idle policy

- Mark activity only for real player input and accepted gameplay commands.
- Do not renew activity from read-only HTTP status, room, or battle polling;
  otherwise an abandoned browser tab can remain online forever.
- Automatic combat that is still executing real actions may renew activity.
- Keep socket and Vue/HTTP timeouts aligned with the authoritative idle daemon.
- Online-list labels must use the same ordinary/VIP timeout calculation as the
  kick path and distinguish active automatic combat from idle display.
- Test exact timeout boundaries, expired VIP, reconnect, stale virtual
  connections, and a stopped client whose status polling has ceased.

## Profession VIP and monetization contract

For role-heavy or pet professions, integrate optional automation through
`gamelib/single/daemons/professionvipd.pike` and the single
`profession_assistant` command. Do not scatter raw `vip_flag` checks across
skills, summons, equipment, drops, or combat formulas.

- Core skills, manual casts, manual summons, healing, guarding, equipment,
  progression and drops stay available without VIP.
- Read effective membership through `VIPD->query_active_vip_level()`. A stored
  flag without a future end time is not an active membership.
- Profession trials may raise only the assistant level. They must not grant the
  generic VIP flag, AFK hours, level cap, store benefits, stats, drops, cooldown
  reduction, summon count, or skill power.
- Automated combat decisions are PVE-only. Reject player targets and
  player-owned summons at the daemon boundary, even if the UI or command has
  already checked.
- Use the same authoritative skill, summon and resonance functions as manual
  play. Automation cannot bypass resource cost, cooldown, learned-skill checks,
  action cadence, level caps, or target rules.
- Tiered configuration slots and toggles persist after expiry or downgrade;
  inaccessible execution pauses without deleting player choices.
- Paid cosmetics must be permanent, confirmation-gated, server-priced and
  stat-neutral. Include reduced-motion UI behavior and verify attributes before
  and after purchase in TestUnit.
- Put any profession-assistant command in both HTTP thread-manager mirrors and
  the global core lock because it may mutate currency, summon registries and
  shared combat state.
- Test free/trial/active/expired/downgraded states, PVE/PVP boundaries, duplicate
  purchase, insufficient currency, level-gated claims, monitor throttling and
  expiry acknowledgement.
- A profession may deliberately have no assistant, but document and test that
  exclusion. If it has one, add its context selection, manual recommendation,
  persisted configuration, styles/titles, UI entry, auto-fight integration, and
  both mirrored HTTP serialization lists as one vertical slice.

## Reverse scans

Search for the new profession ID and for old hard-coded sets:

```bash
rg -n 'jianxian|yushi|zhuxian|kuangyao|wuyao|yinggui|fangshi|zhenyue|tianxiang' \
  gamelib lowlib vue_source test_unit
rg -n 'human.*monst|monst.*human|sizeof\([^)]*\)[[:space:]]*==[[:space:]]*[6789]|case [1-9]|21/100000|24/100000|27/100000' \
  gamelib lowlib vue_source test_unit
```

Classify every hit as identity, balance, acquisition, UI, test expectation, NPC
taxonomy, or deliberate exception. Do not mechanically add player professions to
NPC taxonomy.
