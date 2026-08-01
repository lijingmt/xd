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
| Avatar | image assets, avatar command/tests, Vue header | male/female/default fallback |

## Skills and acquisition

| Concern | Primary source |
| --- | --- |
| Skill definitions | `gamelib/single/skills/` |
| Skill engine | `lowlib/wapmud2/inherit/feature/fight.pike` |
| Skill caps/proficiency | `lowlib/wapmud2/inherit/skill.pike`, `feature/skills.pike` |
| Book objects | `gamelib/clone/item/book/` |
| Read enforcement | `lowlib/mudlib/inherit/feature/readed.pike` |
| Store catalog/UI | `gamelib/data/can_buy_book_list.csv`, `buyd.pike`, `buy_items.pike` |
| Teacher | `gamelib/clone/npc/*teacher*`, plaza room |
| High-level rotation | `gamelib/single/daemons/buyd.pike` and purchase confirmation |
| Hidden drop | `itemsd.pike`, `gamelib/inherit/npc.pike` |
| My skills/UI | `gamelib/cmds/myskills.pike`, legacy skills view, Vue parser |

Every skill needs a real effect test. Test insufficient mofa, cooldown, invalid
target, dead caster/target, duplicate cast, replacement, expiry, and maximum
stage. Group effects are same-room, living, real-team only unless explicitly
designed otherwise.

## Equipment and economy

- Starter weapon and armor object existence, profession restriction, level gate,
  correct slot, `wield()`/`wear()`, silent `auto_equip`.
- Existing restricted equipment compatibility in `feature/equip.pike`.
- Dynamic generation in `itemsd.pike` and `bossdropd.pike`.
- Ordinary/Boss drop ownership, pickup, inventory capacity, sell, destroy,
  auto-sell, warehouse, trade, send, and forge/fusion.
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

## Reverse scans

Search for the new profession ID and for old hard-coded sets:

```bash
rg -n 'jianxian|yushi|zhuxian|kuangyao|wuyao|yinggui|fangshi' \
  gamelib lowlib vue_source test_unit
rg -n 'human.*monst|monst.*human|sizeof\([^)]*\)==[67]|case [1-7]' \
  gamelib lowlib vue_source test_unit
```

Classify every hit as identity, balance, acquisition, UI, test expectation, NPC
taxonomy, or deliberate exception. Do not mechanically add player professions to
NPC taxonomy.
