# Common pitfalls (Wuxiang-era lessons)

Specific bugs and surprises hit while shipping the Wuxiang hidden profession
(2026-08-05). Each entry has the symptom, root cause, fix, and a search
pattern to spot it in new work. Cross-reference `integration-map.md` for
*what to wire*; this file is for *what breaks*.

## Account and multi-character

### Two parallel character-creation paths

**Symptom**: A new profession can be selected from the legacy MUD init room but
the Vue API returns `阵营与职业组合无效`.

**Root cause**: `gamelib/d/init` and `gamelib/single/daemons/account_characterd.pike`
each keep their *own* `valid_professions` mapping. Updating one does not update
the other; the API path silently rejects the new profession.

**Fix**: Update both. In `account_characterd.pike` search for
`private mapping(string:array(string)) valid_professions` and add the new
ID to the right race bucket. In `gamelib/d/init` add the equivalent
`else if(u_p=="<id>")` branch with `setup_player(...)` and starter-skill
migration.

**Search**: `grep -n 'valid_professions\|u_p=="' gamelib/d/init gamelib/single/daemons/account_characterd.pike`

### Manifest limit vs online limit are different knobs

**Symptom**: Test that creates 11 characters on one account fails with
`valid_record rejected`; or a player can create 20 characters but only
1 can be online.

**Root cause**: `ACCOUNT_CHARACTER_LIMIT` (manifest size, in
`account_characterd.pike`) and `max_online_characters` (in
`gamelib/etc/account_characters.conf`, default 1 on misread) are separate.
Static default `ACCOUNT_ONLINE_SAFE_DEFAULT=1` kicks in when the config
file is unreadable or malformed.

**Fix**: Bump `ACCOUNT_CHARACTER_LIMIT` when tests need more slots. Always
check the live config value (`max_online_characters=N`), and never delete
that file on a production server.

**Search**: `grep -n 'ACCOUNT_CHARACTER_LIMIT\|max_online_characters\|ACCOUNT_ONLINE_SAFE_DEFAULT'`

### Save file path uses last-2-chars of userid as subdir

**Symptom**: Fake-account characters report `人物物理档案不可用` even though
the `.o` file exists somewhere under `data_xiand/u/`.

**Root cause**: Path is `data_xiand/u/<userid[-2:]>/<userid>.o`. Using an
MD5 hash or first-2-chars lands the file in the wrong subdir.

**Fix**: Always derive subdir as the last 2 characters of the userid
(`userid[sizeof(userid)-2..]`). `account_characterd.pike` and
`_http_api_mod/auth.pike::get_user_password` both use this convention.

**Search**: `grep -n 'userid\[sizeof(userid)-2\|userid\[-2..\]'`

### Fake-account `.o` files must include `skills` and `password`

**Symptom**: Logging in as a freshly-cloned character throws
`Indexing the NULL value with "lingzhen"` (or `yueji`, `xingmang`,
`wuxiangquan`) from `gamelib/d/init::start()`.

**Root cause**: A minimal `.o` file with just `name / raceId / profeId / level`
makes `me->skills` NULL. The migration line
`if(me->query_profeId()=="lingyi" && !me->skills["lingzhen"])` then errors
because indexing NULL is illegal, even with `!` guard.

**Fix**: Always include `skills ([])` (empty mapping, not NULL) and
`password "..."` (so `get_user_password` succeeds) in any hand-crafted
`.o`. The migration code in `init.pike::start()` now does
`if(!mappingp(me->skills)) me->skills=([]);` before any profession-specific
indexing — keep that guard.

**Search**: `grep -n 'me->skills\["' gamelib/d/init`

### Same-character kick vs same-account coexistence

**Symptom**: Two characters on one account cannot autofight in parallel; one
kicks the other.

**Root cause**: `account_characterd.pike::prepare_character_login_locked`
allows up to `max_online_characters` concurrent logins per account, but
**rejects two clones of the same character_id** (same `.o` file). A
stale browser tab reconnecting with the same TXD can also trigger a
single-character replacement (`player_id==incoming_id` path is silent).

**Fix**: Run different character IDs in different browser tabs; never
duplicate a TXD. If a tab is stuck after a forced logout, the
`recent_forced_logouts` marker (10-min TTL) blocks auto-relogin —
manually choose the character from the Vue center to clear it.

**Search**: `grep -n 'prepare_character_login_locked\|recent_forced_logouts'`

## Skill objects and Pike editing

### `performs_mofa_attack[N]=({a,b})` needs braces, not parens

**Symptom**: Skill file compiles but `query_performs_mofa_attack_low/high`
returns wrong values, or compile error on the array literal.

**Root cause**: Code generation tools sometimes emit `({80,80})` as
`(80,80)` — without the curly braces Pike reads this as something else.

**Fix**: Always verify the literal is `({n,n})` after any bulk edit:
`grep -nE 'performs_\w+\[[0-9]+\]=\([0-9]+,[0-9]+\)' gamelib/single/skills/*`
(any hit is broken).

### Armor/weapon base classes have no `level_limit` field

**Symptom**: Compile error `Undefined identifier level_limit` on
`gamelib/clone/item/armor/<x>` or `.../weapon/<x>`.

**Root cause**: Starter armor/weapon objects inherit `WAP_ARMOR`/`WAP_WEAPON`
which don't declare `level_limit`. Books do have it (via `WAP_BOOK`).

**Fix**: Remove `level_limit=N;` from armor/weapon create bodies. Use
`set_item_level(N)` if a level gate is needed.

### CRLF corruption when Python edits Pike files

**Symptom**: Git diff explodes to 1000+ lines for a 5-line logical change.

**Root cause**: Python's `open(path, "w")` writes LF only. Many legacy Pike
files in this repo are CRLF; rewriting them as LF looks like every line
changed.

**Fix**: Read/write as bytes with explicit `\r\n` line endings:
`with open(path,"rb") as f: data=f.read(); data=data.replace(b"old", b"new");
with open(path,"wb") as f: f.write(data)`. Or run `dos2unix` first and
commit the LF conversion separately before the real edit.

**Search**: `file <path>` reports `ASCII text, with CRLF line terminators`.

### Never `destruct()` a cached skill object in tests

**Symptom**: After one TestUnit case runs, the next case (or production)
fails to load the same skill because `MUD_SKILLSD` cache was nuked.

**Root cause**: `MUD_SKILLSD[name]` caches skill objects. Calling
`destruct(skill)` in a test pollutes the cache for the rest of the run.

**Fix**: Just remove the variable holding the local reference; let the
test binary tear down at end of process. If cleanup is required,
`destruct` only objects you `clone()`-ed yourself, never daemons or
globally cached skills.

## Skills and book assets

### Skill `picture` field naming — collision with book covers

**Symptom**: A skill icon and a book cover for the same content step on
each other's image file.

**Root cause**: Skills inherit `WAP_F_VIEW_PICTURE` and render via
`query_picture_url()` in `skill_detail` view. Books use `picture=name`
(where `name` is the book id). If a skill is named `wuxiangguixu` and a
book is also `wuxiangguixu`, they share `images/wuxiangguixu.gif`.

**Fix**: Skills use the `_logo` suffix: `picture="wuxiangguixu_logo"`.
Books keep `picture=name` (no suffix). 60×60 PNG+GIF for skills, 48×64
PNG+GIF for book covers, both in `images/` and `web/images/`.

**Search**: `grep -n 'picture="[^"]*_logo"' gamelib/single/skills/`

### Skill icon needs `is_skill()` and `pic_flag["skill"]`

**Symptom**: Skill sets `picture="X_logo"` but the icon never renders in
the `skill_detail` view.

**Root cause**: `picture.pike::query_picture_url` only emits imgurl for
`room` / `item` / `character` types. Skills get filtered out because the
skill base has no `is_skill()` method (the base dispatcher in
`lowlib/system/inherit/base.pike` looks up `is_<type>()`).

**Fix**:
1. Add `int is_skill() { return 1; }` to `lowlib/wapmud2/inherit/skill.pike`.
2. Add `||(flags["skill"]=="open"&&ob->is("skill"))` to both
   `query_picture_url` and `query_mini_picture_url` in `picture.pike`.
3. Default `pic_flag["skill"]="open"` for new accounts in `gamelib/d/init`
   and backfill old accounts on login.
4. Add a toggle row in `gamelib/cmds/pic_switch_list.pike` (bump
   `SWICTH` from 4 to 5) and add `skill` to the `all` action in
   `pic_switch_confirm.pike`.

**Search**: `grep -n 'is_skill\|pic_flag\["skill"\]\|SWICTH'`

### ImageMagick layered draw pitfalls

**Symptom**: A 60×60 icon renders as mostly empty/transparent instead of
the intended colored sprite.

**Root cause** (most common): `magick -fill <color> -draw "circle 30,30 30,2"`
paints a 28-radius disc that **overwrites** the central glyph. Border
layering must use strokes (`fill none -stroke ...`), not filled circles.

**Other pitfalls**:
- `roundrectangle x1,y1 x2,y2 rx` (one radius) fails — needs `rx,ry`
  (two numbers).
- macOS CJK glyphs: font path is
  `/System/Library/Fonts/STHeiti Medium.ttc`. Use
  `magick -font "$FONT" -pointsize 36 -fill white -gravity center -annotate +0+2 "$GLYPH"`
  to render.
- Vision-model checks confuse similar characters at 60×60
  (击/古/无/元). Players recognize them in context — don't over-rely on
  AI assessment of small icons.

**Search**: `identify <path>` shows file size; under 1.5KB usually means
content was lost during draw.

## Vue and frontend

### Bump test assertion counts when profession list grows

**Symptom**: `vue_source/tests/account-characters.test.js` fails
`assert.strictEqual(client.professionOptions.length, 10)` after adding
Wuxiang.

**Root cause**: Test hardcodes the previous profession count.

**Fix**: Bump `length` and `Set.size` checks to the new count, and add
an assertion that the new ID is present. When hide-on-lock is implemented,
don't try to assert `visibleProfessionOptions.length` from the test —
that computed property is not exposed by the
`Object.assign(data(), methods)` pattern.

### Hide profession button when unlock condition not met

**Symptom**: Player clicks a "（未解锁）" profession button and sees a
cryptic error; better UX is to hide the button entirely.

**Root cause**: Backend rejects the request, but the front-end still shows
the entry.

**Fix**:
1. Backend: in `query_account_characters` response, add
   `result["wuxiang_unlocked"] = query_wuxiang_unlocked_from_summary(result);`
2. Vue `applyAccountData`: read `data.wuxiang_unlocked === true` into a
   `wuxiangUnlocked` data field.
3. Vue computed: `visibleProfessionOptions()` filters out `wuxiang`
   unless `wuxiangUnlocked` is true.
4. Template: use `v-for="option in visibleProfessionOptions"`, not the
   raw array.

**Search**: `grep -n 'visibleProfessionOptions\|wuxiangUnlocked\|wuxiang_unlocked'`

### Deploy script hardcoded counts go stale silently

**Symptom**: `restart-docker.sh` prints "校验31本原隐藏秘籍" after you
expanded the pool to 34. The actual `rsync` and verification loop *do*
cover the new files (because the array lists them), but the log line
lies.

**Root cause**: `print_success "...31本..."` was hardcoded.

**Fix**: Use shell parameter length:
`${#HIDDEN_MYTHIC_SKILL_IDS[@]}` instead of a literal. Same for ancient
pools and any future list. After the fix the message tracks the array
automatically.

**Search**: `grep -nE '本(原)?隐藏|套(原)?隐藏|print_success.*[0-9]+本' restart-docker.sh restart-all-docker.sh`

### Hidden pool expansion — keep numerator and denominator in sync

**Symptom**: Adding 3 hidden books to a uniform-pool implementation
either dilutes existing books (numerator unchanged, denominator grows)
or makes new books rarer than expected (denominator unchanged).

**Root cause**: `itemsd.pike` rolls once per kill, then uniformly selects
one book from the pool. The shared probability is `numerator/100000`. If
you add books to the pool without raising the numerator, every existing
book becomes less likely.

**Fix**: Grow both together. Wuxiang added 3 books → numerator and
denominator both grow from 31 to 34. Per-book probability stays at
`1/100000`. Document any deliberate exception (Lingyi has one intentional
extra group-heal book).

**Search**: `grep -nE '(31|34)/100000|HIDDEN_MYTHIC.*NUMERATOR' gamelib/ lowlib/ test_unit/`

## Pet and combat edge cases

### Pet basic attack must be independent of main skill cooldown

**Symptom**: Pet feels passive; only fires its main 灵技 every 24-36s.

**Fix pattern**: Add a `perform_pet_basic_assist(player, target)` in
`_pet_mod/assist.pike` that:
- validates PVE state (reject `target->is("player")` — preserves PVP
  charge balance),
- looks up species-specific basic attack name (`query_pet_basic_attack_name`),
- computes ~5% of main skill's amount via `query_pet_assist_profile`,
- applies damage/heal/mofa per the main profile's type,
- throttles chat output via a separate `basic_msg_at` timestamp
  (damage still fires every tick),
- has its own timestamp field — never touches `assist_at`.

Hook it from `lowlib/wapmud2/inherit/feature/fight.pike::heart_beat_action`
as a separate `PETD->perform_pet_basic_assist(...)` call right after
`perform_pet_combat_assist`.

**Search**: `grep -n 'perform_pet_basic_assist\|basic_msg_at\|basic_attack_throttle'`

### Pet state graceful when species=0

**Symptom**: A player without an equipped pet spams errors.

**Root cause**: `shanhai_catalog[species]` returns 0 when species is `""`
or `0`. Indexing 0 throws.

**Fix**: Always early-return after species lookup:
```pike
species = (string)(player["/tmp/wanling/species"] || "");
info = shanhai_catalog[species];
if(!info) return result;
```
The same pattern applies to any new function that reads pet state.

### Per-battle reset vs real-time cooldown — pick one

**Symptom**: Player expects main 灵技 to be reusable in the next battle,
but cooldown is real-time and persists across battles.

**Current behavior**: `fight.pike::heart_beat_action` at combat end calls
`PETD->reset_pet_combat_state(player)` which only resets PVP fields
(pvp_target/charge/uses). `assist_at` (PVE cooldown timestamp) is NOT
reset.

**Decision**: If you want per-battle reset, extend
`reset_pet_combat_state` to also clear `assist_at` and `basic_msg_at`.
Document the choice — PVE cooldown reset changes the long-run DPS.

## TestUnit patterns

### Test must not depend on real docker state

**Symptom**: Tests pass on dev machine but fail on production docker.

**Fix**: Use `clone(GAMELIB_USER)` + `setup_player(race, prof)` to spin up
a real player object, then test the function. Don't assume `MUD_SKILLSD`
or any global daemon state — start cold.

### Bump hidden-pool test counts when expanding the pool

**Symptom**: `test_ancient_hidden_skills.pike` fails after adding new
mythic books.

**Fix**: Search for hard-coded `31` or pool boundary assertions
(e.g., `roll=32 → expect miss`). Update to the new pool size. The
boundary should be `>=pool_size` for a miss, `<pool_size` for a hit.

### Compile-time tests are a smoke test, not completion evidence

**Symptom**: `compile_file()` succeeds for one profession's skills but
the profession is still broken at runtime.

**Fix**: Always add runtime effect tests (use the skill, verify damage /
heal / state). Compile-only checks belong in
`test_unit/test_compile_only.pike` as helpers, not as the main proof.

## Memory and review checklist

Before declaring a new profession done, scan this file's **Search**
patterns against your changes. Each hit is a potential regression
that the static audit script won't catch.
