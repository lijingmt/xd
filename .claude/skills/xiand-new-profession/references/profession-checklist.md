# Xiand new-profession implementation checklist

Use this as a release gate. Record a source path, runtime test, and observed
result for every checked item. Mark an item `N/A` only with a written design
reason and a regression test proving the generic or deliberately excluded path.

The active implementation record for the neutral healer added on 2026-08-01 is
kept in `docs/lingyi-profession-contract.md`. It is also a filled example of
this checklist's class-contract gate for future professions. Its completed
release proof is `docs/lingyi-10-pass-audit.md`.

## 0. Class contract before code

- [ ] Stable profession ID, Chinese name, race, role tag, and player-facing pitch.
- [ ] Primary/secondary attributes and exact values at levels 1, 30, 80, 120,
  the normal cap, and every VIP-expanded cap.
- [ ] Solo rotation, team contribution, PvP counterplay, Boss behavior, resource
  loop, equipment policy, and recovery-item policy.
- [ ] Skill milestones, stage count, passive chain, advanced replacements,
  level-20 reward, level-53 chain, and the profession's declared hidden mythic
  skills (normally three; every deliberate extra must update pool/rate/tests/docs).
- [ ] Stateful mechanic ownership, numeric caps, server-authoritative inputs,
  and cleanup matrix for move/team/target/death/logout/disconnect/expiry/recast.
- [ ] Auto-fight behavior, optional profession assistant behavior, free core,
  VIP boundary, trial boundary, and stat-neutral cosmetic policy.
- [ ] Intentional differences from Fangshi, Zhenyue, Tianxiang, Lingyi, and legacy professions.

## 1. Identity, race, creation, and persistence

- [ ] Real race/profession selection link reaches `setup_player(race, profession)`.
- [ ] A shared race lists every profession independently; `third` does not imply
  Fangshi, Zhenyue, or Tianxiang and a new neutral class cannot overwrite any of them.
- [ ] Identity helpers return race/profession IDs and Chinese names without a
  two-race fallback granting the wrong class.
- [ ] Initial life, mofa, strength, dexterity, think, luck, money, time, room,
  starter skill, starter gear, guide state, and save occur exactly once.
- [ ] Repeating setup/login migration is additive and idempotent; it preserves
  learned skills, equipment, currency, task progress, and player choices.
- [ ] Birth, relife, fall-death recovery, reconnect twice, and old-save migration
  retain the intended profession.
- [ ] Default unnamed title, honor/resource label, rank tag, top list, game list,
  admin display, HTTP player state, and logs show the right identity.
- [ ] Atomic save, backup recovery, 30-second autosave, and safe restart include
  both socket and Vue/HTTP players.

## 2. Attributes, combat, and class mechanic

- [ ] Exact growth is tested at levels 1/30/80/120 and the highest supported cap.
- [ ] Normal attack, every active skill, every passive stage, defense, hit,
  dodge, crit, penetration, healing, and resource costs use runtime assertions.
- [ ] Every skill effect type is handled by the engine; descriptions contain no
  unimplemented AOE, taunt, stun, dispel, reflection, ignore-defense, or heal.
- [ ] Unlearned, wrong-profession, under-level, dead, insufficient-resource,
  cooling, invalid-target, cross-room, and duplicate casts are rejected.
- [ ] Buff/shield/guard/taunt/summon/DOT/control ownership is server-side and
  cannot trust level, duration, price, target, or strength from a command link.
- [ ] Recast weaker/stronger/equal effects has a deliberate tested policy.
- [ ] Movement, team change, target switch, death, logout, owner loss, expiry,
  daemon reload, and replacement remove or recover state without stale links.
- [ ] Temporary resource stacks, cap, expiry, consumption, and cleanup are
  server-owned and serialized consistently to legacy and Vue battle state.
- [ ] AOE and target arrays purge dead, destructed, cross-room, and current-target
  objects consistently.
- [ ] Room-wide AOE takes a server snapshot, excludes allies and allied pets,
  never treats an uninvolved PvP bystander as authorized, caps player/Boss
  damage, preserves reward credit, and reports every resolved target to Vue.
- [ ] Team effects require real same-team, same-room, living members and never
  affect outsiders or revive dead players unless explicitly designed.
- [ ] Death-prevention/revival is checked before rewards, durability/experience
  loss, summon cleanup, and relocation; consumption precedes restoration; daily
  persistence, reentry lock, restore ratios, fast-PK, PvE/PvP, suicide, duel,
  city/guild war, ghost, invalid killer, and reconnect boundaries are tested.
- [ ] PvP, player-owned pets, Bosses, duels, guild wars, city wars, and long-PK
  fast decisions honor caps and attribution.
- [ ] Compare one physical, one magical, Fangshi, and Zhenyue regression case.

## 3. Skills, books, teachers, and acquisition

- [ ] Every catalog row has a real book object, real skill object, valid type,
  continuous stages, character gates, costs, cooldown, description, and icon.
- [ ] Buying creates inventory first; the visible `[学习:read ...]` action performs
  learning and buying alone never mutates learned skills.
- [ ] `read`, `beidong_read`, and `spec_read` return/consume correctly for success,
  duplicate, under-level, wrong profession, missing prerequisite, and failure.
- [ ] Passive learning works with a cold skill registry after restart.
- [ ] Replacement removes only the intended old key and every old-name utility
  resolves the replacement alias.
- [ ] Teacher exists, is placed in every intended faction plaza, exposes only the
  correct profession shop, and rejects forged shop type or book path.
- [ ] Ordinary catalog, high-level daily rotation, detail, confirmation, stock,
  selected catalog, profession, and server-owned price agree.
- [ ] Every active profession receives its configured rotation; do not encode a
  stale count such as seven or eight.
- [ ] Every declared hidden book requires level 80 and profession, allows normal item
  movement, survive duplicate reads, and never appear in any store or teacher.
- [ ] Hidden pool grows by the declared count and shared numerator grows equally so
  the current per-book long-run probability remains about 1/100000.
- [ ] Actual NPC level 70+, one roll per killed monster, team/solo ownership,
  120-second protection, five-minute cleanup, and audit log are preserved.

### 3a. Skill icons (added 2026-08-04)

- [ ] Every player-facing skill file sets `picture="<skill_id>_logo";` next to
  `name_cn=...` (no suffix collisions with book covers that use `picture=name`).
- [ ] 60x60 PNG + GIF generated in **both** `images/<skill>_logo.{png,gif}` and
  `web/images/<skill>_logo.{png,gif}`. Verify with `identify` and file size.
- [ ] Icon design follows the dark-navy + multi-ring gold border + class-colored
  inner + central CJK glyph style established by `wuxiang_logo.png` and the 16
  wuxiang skill icons. Use strokes for borders — never full-radius `fill circle`.
- [ ] Book covers (48x64) for mythic hidden books exist at `images/<book>.{png,gif}`
  and `web/images/<book>.{png,gif}` when the book file uses `picture=name`.
- [ ] `pic_flag["skill"]` defaults to `"open"` for new accounts in `gamelib/d/init`
  and old accounts are migrated on login.
- [ ] `gamelib/cmds/pic_switch_list.pike` exposes the skill toggle and
  `pic_switch_confirm.pike` includes `skill` in its `all` action.
- [ ] TestUnit verifies: each skill file's `picture=` field, asset presence in
  both image directories and both formats, `is("skill")==1`, `query_picture_url`
  emits `[imgurl picture:.../<skill>_logo.gif]` when open and `""` when closed,
  and `view_performs(...)` output contains the icon URL. See
  `test_unit/test_wuxiang_skill_icons.pike`.

## 4. Equipment, items, economy, and rewards

- [ ] Starter weapon/armor exist, match slots and restrictions, auto-equip
  silently, and never replace stronger legitimate gear.
- [ ] Existing restricted gear plus normal/Boss generated gear can be viewed,
  picked up, worn/wielded, removed, forged/fused, sold, destroyed, auto-sold,
  stored, traded, sent, and dropped under the intended policy.
- [ ] Inventory-full and failed pickup paths do not deadlock auto-fight.
- [ ] Profession-limited `food`, `water`, `liandan`, and `teyao` include the new
  profession where comparable classes are allowed; HP and mofa medicine work.
- [ ] Task-only, bound, two-hand, level, attribute, slot, and profession
  restrictions remain enforced.
- [ ] Gold, jade denomination conversion/change, rewards, refunds, duplicate
  purchase, insufficient funds, and forged price are exact and atomic.
- [ ] Hidden, task, and Boss rewards cannot roll twice or be credited to the
  wrong player when summons, teams, or fast-PK resolution are involved.

## 5. Tasks, world, onboarding, and progression

- [ ] State-based newbie guide checks real actions: equipment, learning, combat,
  medicine, class mechanic, team use, and task completion.
- [ ] Teacher/NPC task list shows every eligible task, not a hard-coded two-item
  subset; completed steps provide a completion popup and next navigation.
- [ ] Level-20 reward is profession-restricted and level-53 tasks enforce order,
  granting NPC, completion NPC, reward, and direct-ID skip prevention.
- [ ] Growth/level-gap tasks cover every intended level band and use the correct
  profession title/reward.
- [ ] Direct navigation reaches the objective map and safely handles missing or
  stale task targets.
- [ ] Fixed monsters have no progression gap; dynamic monsters begin only at the
  configured threshold and low-level visitors restore shared NPC state.
- [ ] Smart auto-fight finds a safe target, changes map when empty/unsafe, avoids
  route loops, casts learned skills, rests, heals, loots, sells/stores/destroys,
  and resumes after failed pickup or refresh.
- [ ] Dungeons, 70+, 120+, VIP cap expansion, 999 maps, death recovery, offline
  AFK, gathering, and high-level hidden drops have explicit coverage.

## 6. Neutral, social, and shared systems

- [ ] Define facility access separately for `human`, `monst`, and `third` rooms;
  never depend on a binary `else` branch.
- [ ] Neutral players can use intended transfers, cities, warehouses, post,
  rest, honor shops, teachers, tasks, guards, and public NPC services.
- [ ] Team, invite, follow, guild, home, ranking, honor, chat, whisper, friends,
  trade, send, auction, warehouse, dungeon, feedback, and admin operations
  accept the profession intentionally.
- [ ] Cross-faction social behavior is symmetric when either participant is
  neutral without making ordinary human/monster players friendly.
- [ ] Faction conversion is rejected before consuming an item or mutating race.
- [ ] PvP, city guards, duel, guild war, summon/pet credit, and fast-decision
  rules cannot treat the new neutral profession as Fangshi automatically.
- [ ] Home ownership and merged-zone conflict handling preserve old data and
  isolate/merge correctly across logical zones.

## 7. UI, assets, accessibility, and deployment

- [ ] Character selection explains role, difficulty, resource, team value, and
  first actions in legacy and Vue paths.
- [ ] Logo plus male/female avatars exist, are nonempty and intentionally
  distinct, and appear under both `images/` and `web/images/`.
- [ ] Init selection, avatar choice, Vue header, identity panel, rank, skills,
  battle window, task UI, guide, map, shop, and profession assistant use them.
- [ ] Unknown/missing avatar falls back without a broken image or wrong class.
- [ ] `restart-docker.sh`, image rebuild, Tomcat/container copy, Vue build, and
  cache-busting manifest include the current files.
- [ ] Responsive phone/tablet/browser layouts, compact controls, font settings,
  reduced motion, screen-reader labels, and actionable errors remain usable.
- [ ] Battle target name, combat state, HP/mofa, effect feedback, skill animation,
  refresh, login/session compatibility, and request-overlap guards work.
- [ ] Multi-target combat feedback survives the last target's death long enough
  to show hit, resisted, defeated, and auto-revived outcomes; moving rooms or
  expiry clears the transient report, and collapsed/mobile docks do not hide it.

## 8. Automation, VIP, concurrency, and security

- [ ] Core learning, manual skills, class mechanic, equipment, tasks, drops, and
  progression remain available without VIP.
- [ ] Optional profession automation uses `PROFESSIONVIPD`, is PVE-only, calls
  authoritative manual functions, and cannot bypass costs, cooldowns, cadence,
  level, target, equipment, or learned-skill checks.
- [ ] Trial raises only assistant capability; active/expired/downgraded VIP
  preserves configuration while execution pauses safely.
- [ ] Cosmetics are permanent, confirmation-gated, server-priced, stat-neutral,
  and reduced-motion compatible.
- [ ] Player mutations are serialized; shared economy/team/combat mutations use
  the correct global transaction lock; pure reads are the only parallel work.
- [ ] Battle/status serializers perform pure reads: mastery/revive/resource
  queries must not lazily load objects, mutate registries, or accept client
  counters while running on parallel HTTP read paths.
- [ ] New mutating commands appear in every mirrored HTTP core-command list.
- [ ] Rate/body/queue/command limits, malformed inputs, duplicate requests,
  timeouts, cleanup, and reconnect are tested.
- [ ] Real input and accepted gameplay commands renew idle activity; read-only
  HTTP status/room/battle polling does not; socket and Vue timeouts plus online
  labels use the same ordinary/active-VIP policy.

## 9. Documentation and release proof

- [ ] Both guide builders enumerate the profession without fixed stale totals;
  Markdown and PDF describe current mechanics, numbers, acquisition, maps, VIP,
  equipment, hidden skills, and intentional differences.
- [ ] Changed PDFs are rebuilt, rendered, visually inspected, text-checked, and
  versioned; temporary renders and `__pycache__` remain uncommitted.
- [ ] Static audit passes with race, hidden-book, and asset expectations.
- [ ] A legacy/nonstandard image prefix is supplied explicitly with
  `--asset-prefix`; every `--allow-missing` exemption records why the generic
  runtime path is valid and which runtime test proves it.
- [ ] Dedicated runtime test clones real users, performs real reads/actions, and
  covers the class mechanic plus all failure and cleanup boundaries.
- [ ] Old-profession, Fangshi, Zhenyue, Tianxiang, Lingyi, shared combat, auto-fight, hidden drop,
  equipment, task, persistence, HTTP, Vue, and deployment regressions pass.
- [ ] Final change is followed by `git diff --check`, targeted tests, real
  restart/full TestUnit, ports 13800/8888, error-log scan, and changed UI build.
- [ ] Review staged paths; exclude runtime saves/logs/cache/temp files; use an
  English commit message and push only when requested.
