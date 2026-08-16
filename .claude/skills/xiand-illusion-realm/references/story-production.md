# 81-Chapter Story and Artwork Production

Use this workflow to ship a future 幻境 cycle as a complete playable campaign,
not as prose detached from game state. Treat story, tasks, maps, NPC attribution,
artwork, clients, persistence, and end-to-end tests as one versioned contract.

## 1. Freeze the campaign contract

Define these inputs before editing runtime code:

- immutable uppercase cycle ID, display name, start/end policy, entry and return rooms;
- one original premise and ending that do not reuse protected characters, brands,
  plots, logos, or visual designs;
- nine volumes with nine ordered chapters each;
- one five-beat emotional arc per chapter: situation, conflict, choice, reversal,
  and forward hook;
- exact task target for every chapter: room visit, ordinary hunt, named boss,
  route milestone, or explicit story event;
- reward schedule whose total and binding rules are known before implementation;
- level curve, monster tier, route gates, and deliberate progression bottlenecks;
- one unique chapter illustration per chapter and one 3x3 overview atlas per volume.

Use the 9x9 structure as a pacing scaffold, not as permission to pad chapters.
Each volume must change the world state or the player's understanding. Each chapter
must advance plot and gameplay. Keep calendar-day fields as analytics metadata;
never make a player wait for a real-world day unless the design explicitly requires
and tests that gate.

For a new cycle, create a new story file and image directory. Never rename, reuse,
or overwrite S1 IDs, S1 story JSON, S1 runtime receipts, or S1 art.

## 2. Author the data before the daemon

Keep prose in a tracked story JSON equivalent to
`gamelib/etc/illusion_s1_story.json`. Keep lifecycle and task targets in the tracked
cycle config equivalent to `gamelib/etc/illusion_realm.json`.

Require this story schema:

```json
{
  "illusion_id": "S2",
  "story_title": "original title",
  "story_premise": "original premise",
  "version": 1,
  "volumes": [{
    "id": "S2-V1",
    "title": "volume title",
    "atlas": "/xd/images/illusion_s2/story/volume_01.png",
    "chapters": [{
      "id": "S2-C1",
      "title": "chapter title",
      "intro": "the setup and conflict",
      "outro": "the result and next hook",
      "active_days": 1,
      "reward_count": 0
    }]
  }]
}
```

Add `story_event` only to a chapter with a configured canonical event. Require the
event's chapter, kind, player-facing Chinese location, room path, NPC path, title,
and completion message to agree. Use canonical paths, never display labels, as the
identity used for progress.

Validate before coding:

- exactly 9 volumes, 81 sequential IDs, and 81 unique nonempty titles;
- no missing or duplicate chapter number;
- intro and outro are substantive and the ending of chapter N leads into N+1;
- reward counts total the designed amount and do not accidentally award twice;
- every task room and NPC file exists and belongs to the new cycle tree;
- every named boss maps to one event and one canonical NPC path;
- route choice remains immutable inside the cycle;
- no chapter depends on future progress or an unreachable map.

## 3. Turn prose into a playable chapter

Render every open chapter as exactly five readable narrative lines. In S1 this is
done by `expanded_chapter_intro()` in
`gamelib/single/daemons/seasonal_chard.pike`: volume theme, three chapter beats,
and a forward hook. Keep the prose source authoritative and derive runtime display
text deterministically; do not persist generated display prose in player saves.

Give the player one primary action, `illusion_realm next`, that:

1. explains the current goal and exact Chinese location;
2. routes only to the current allowlisted room;
3. offers autofight after arrival when the target is combat;
4. shows current/required progress after every eligible action;
5. claims only the current ready chapter;
6. immediately presents the next chapter.

Keep old explicit commands and JSP bookmarks compatible. A failed movement page
must end with `[返回游戏:look]`; never strand the player on a text-only error.

Record facts at the authoritative action boundary:

- room progress after a successful move into the exact canonical room;
- kill progress after confirmed NPC death attribution, not after experience grant;
- boss progress only for the exact configured NPC in the player's exact room;
- team credit only for eligible same-instance participants;
- story choice at the confirmed choice mutation;
- claim progress only inside the save/rollback transaction.

A zero-experience kill is still a real kill. High-level characters killing a
lower-level story boss must advance the chapter even when the experience formula
returns zero. Do not change global experience, damage, drop, VIP, profession, or
monster formulas to make a story test pass.

Make recording idempotent. A duplicate request, repeated boss death callback,
reconnect, Worker handoff, or restart must not create duplicate progress or rewards.
Checkpoint thresholds and bosses; roll back progress if the required save fails.

## 4. Produce original chapter artwork

Use the image-generation skill for each illustration. Generate every chapter as an
independent image from that chapter's actual narrative, not as 81 crops of nine
atlases. Use a prompt template like:

```text
Create an original square Chinese xianxia story illustration for <cycle>,
chapter <NNN> “<title>”. Show <setting>, <characters and action>, <emotional beat>,
and <story symbol>. Cinematic lighting, readable silhouettes, rich environmental
storytelling, no text, no logo, no watermark, no UI, no copyrighted character,
no imitation of a named artist, game, animation, film, or novel.
```

Keep visual continuity by defining an original character sheet in the prompt notes:
age, silhouette, clothing palette, weapon, recurring symbol, companion traits, and
how these change by volume. Do not put words inside generated images; localized
chapter titles remain HTML text and are accessible independently of the art.

Inspect every result before accepting it:

- it depicts the correct chapter rather than a generic fight;
- key characters, time, location, and emotional beat match the prose;
- no malformed hands/faces, accidental modern objects, signatures, logos, or text;
- no close resemblance to a known franchise or public figure;
- important subjects survive a square center composition and small mobile display;
- each chapter has a distinct SHA-256 digest.

Store source assets using strict sequential names:

```text
images/illusion_s2/story/volume_01.png ... volume_09.png
images/illusion_s2/story/chapters/chapter_001.png ... chapter_081.png
```

S1 uses 418x418 chapter PNGs and 1254x1254 volume atlases. Future cycles may use a
higher square source resolution, but keep consistent dimensions within one cycle,
compress without visible degradation, and set explicit minimum-byte checks that
reject placeholders. Never fix a missing chapter by copying another image.

Create each volume atlas only after its nine chapter images pass review. An atlas is
a browseable overview; runtime chapter pages must load the independent chapter file.

## 5. Wire every rendering path

Use one allowlisted image protocol. S1 emits:

```text
[imgurl picture:/xd/images/illusion_s1/story/chapters/chapter_009.png]
```

The path is data, not a general URL. Require the cycle ID, chapter number, filename,
and allowlisted root to agree. Reject traversal, remote URLs, wrong chapter/path
pairs, and out-of-range numbers in the HTTP parser and every renderer.

Update all affected surfaces together:

- runtime story output in `seasonal_chard.pike` and `illusion_realm.pike`;
- JSON parsing and `_http_api_mod/html_renderer.pike`;
- Vue source CSS/tests and rebuilt `vue_source/dist` plus `web/web_vue` output;
- `html5.pike`, `html6.pike`, `html6_dark.pike`, and `html6 copy.pike`;
- `scripts/build/build_vue_frontend.sh`, `vue_source/build.js`, and Docker copy rules;
- active-cycle config validation and TestUnit image checks.

Keep images inside the device viewport. For chapter art use width no greater than
`min(100%, 34rem, 72vh)` with a modern `72svh` override, `height:auto`, and
`object-fit:contain`. Verify portrait phone, landscape phone, tablet, split view,
and desktop. Preserve the `vh` fallback for old JSP browsers and add `loading=lazy`
where supported. Do not crop story-critical content.

The tracked `images/` tree is authoritative. The build must copy byte-identical art
to `web/images/`; Docker must package that built web tree. Never hand-edit only the
generated copy.

## 6. Build the mandatory regression matrix

Add focused TestUnit coverage before running a server:

- JSON schema, exact order/count, unique titles, reward total, and original-brand
  denylist review;
- every configured room/NPC load and canonical event mapping;
- all 81 source images exist, exceed the placeholder threshold, have unique digests,
  and equal their deployed copies;
- all runtime chapter intros have exactly five substantive lines;
- future chapter/event attempts fail before the previous chapter is claimed;
- zero-XP ordinary and boss kills still advance through the real NPC death hook;
- wrong NPC, wrong room, wrong realm, duplicate callback, and nonparticipant do not;
- a failed save rolls back progress, level top-up, items, and claim state;
- restart/reload preserves the unique player archive and exact chapter;
- Vue and all four legacy filters render valid art and reject forged paths;
- failed travel includes a working return-game action.

Keep a real all-profession matrix. For the current 12 professions and 81 chapters,
require 12 x 81 = 972 ordered chapter traversals. For each profession:

1. create a fresh account and ordinary character through `choice_profe`;
2. enter a real cycle room;
3. defeat a real level-appropriate cycle NPC through the production combat loop;
4. satisfy every room, kill, boss, route, and story event in order;
5. claim the exact designed rewards and equip the full cycle set;
6. save, destroy/reload the object, and verify progress/equipment;
7. settle the same archive to 永恒服 and reload again.

Distribute professions across every route. Never make the test pass by directly
writing level, injecting complete progress, calling only the daemon instead of the
real NPC hook, or replacing combat with an artificial kill counter.

## 7. Validate in production order

Run checks in this order:

```bash
git diff --check
cd vue_source && npm test
cd vue_source && npm run build
cd /usr/local/games/xiand && ./restart-local-workers.sh 3
cd /usr/local/games/xiand && ./scripts/map_worker_cluster.sh health
curl -fsS http://127.0.0.1:8888/health
```

Use the repository's current safe restart wrapper when names change; do not run a
second standalone server beside an active gateway. A successful restart must compile
the Pike files, run the complete TestUnit suite with zero failures, restore active
Worker topology, and keep gateway/Worker health green.

Then execute `scripts/test_local_player_entry_smoke.sh` with credentials supplied
only through environment variables. Verify the rendered 进入游戏 button, room,
status, inventory, equipment, skills, one real battle, story progress, return-game
link, save/reload, and reconnect. Never commit credentials or runtime player data.

## 8. Definition of done

Do not call a cycle story finished until all of these are true:

- 81 ordered chapters form one coherent original story and every chapter is playable;
- 81 reviewed independent illustrations and 9 atlases are present and deployable;
- one primary next action can carry a new player through the entire campaign;
- all facts are recorded at authoritative boundaries, including zero-XP kills;
- Vue, old JSP themes, bookmarks, phone, tablet, and desktop all remain usable;
- all professions finish, equip, persist, reload, and settle through real flows;
- full restart TestUnit reports zero failures and active Workers are healthy;
- staged diff excludes accounts, runtime JSON, rankings, logs, secrets, and generated
  local state;
- the feature remains on its feature branch until the user explicitly authorizes a
  merge to `main`.
