# S1 Journey, Secret, and Moon-Memory Production

Use this reference when extending S1 with deterministic side quests, narrative
abilities, gate substitutes, or cycle-only companions. Preserve the existing 81
chapter story, ten set rewards, profession formulas, random souvenir items, and
single-character archive.

## Contents

1. Freeze the overlay contract
2. Preserve chronology and climax
3. Store and validate state
4. Design narrative abilities
5. Design cycle companions
6. Preserve Worker and settlement safety
7. Validate the overlay

## 1. Freeze the overlay contract

Author the tracked overlay in `gamelib/etc/illusion_s1_journey.json`. Require:

- immutable `illusion_id=S1`, an explicit schema version, and a feature revision;
- exactly one four-act side quest per volume;
- deterministic acts bound to canonical static S1 rooms;
- one existing authoritative volume-end story event per quest;
- one unique journey secret and one unique story-gate substitute per quest;
- a bounded companion species catalog and one memory event per volume;
- no probability, wallet, payment, tradable item, or ordinary combat formula.

Use four acts: discovery, investigation, interpretation, and emotional closure.
The first three acts may be completed before the volume finale. The fourth act
must require the existing authoritative finale event. A side quest may add context
to the main story, but cannot mark a chapter, boss, or reward complete by itself.

Keep the overlay additive. Do not edit the already published S1 prose or clone a
second campaign record just to add side content.

## 2. Preserve chronology and climax

Never require a later boss before its formal story chapter. In particular, a
route gate before chapter 81 cannot require the chapter-81 final boss. Replace the
early route target with an earlier canonical guardian and accept the old final-boss
mark only as grandfathered route credit. The chapter-81 story event must still be
completed normally.

Do not put a long random hunt after a volume boss. Preserve physical story items
and their pity counters as collectible legacy paths, but allow a deterministic
side quest to satisfy the same progression gate:

```text
ready = owner-matching physical item count is sufficient
     OR strict deterministic substitute validation succeeds
```

The substitute is not an item and must never change physical item count or pity.
Validate all of these before accepting it:

- journey schema and owner match the current character and registered account;
- the exact matching four-act quest is complete;
- its completion timestamp and secret unlock are valid;
- its gate ID matches the configured main-story gate;
- the existing volume-end story event is recorded.

A lone `gate_substitutions[id]` field is never sufficient. Corrupt, unknown, or
partially written records fail closed to the original physical-item path.

## 3. Store and validate state

Store the entire overlay only under:

```text
/plus/illusion_realm/S1/newmoon_journey
```

Keep `owner_id` and `registration_account` in the record. Bound the number and
shape of quests, secrets, substitutes, species, memories, traits, IDs, and
timestamps. Reject duplicate or unknown IDs. Querying a V0 player may construct an
in-memory default, but must not save until a real mutation occurs.

For every mutation:

1. acquire the journey mutation mutex;
2. copy the complete old illusion progress;
3. validate owner and current state;
4. apply one bounded mutation in memory;
5. call the normal fenced `save_with_result()`;
6. restore the complete old progress on failure;
7. return success only after the save succeeds.

Do not create per-Worker journey files or authoritative daemon caches. Do not copy
the overlay into account JSON, ranking snapshots, shared warehouses, or a second
player archive.

## 4. Design narrative abilities

Treat S1 journey secrets as context actions, not ordinary character skills.
Do not write `player->skills`, `f_skills`, skill proficiency, automatic combo
slots, cooldown tables, or physical skill books.

Safe first-version effects include:

- reveal erased names or hidden writing in marked scenes;
- compare testimony and label witnessed, reported, inferred, or forged evidence;
- summarize the next real chapter action;
- replay a saved companion memory;
- show a character's completed journey ledger.

They may change text, clues, collection records, and endings. They must not alter
damage, healing, control, PVP, drops, experience, currency, difficulty, AFK time,
or profession balance. If a later release adds combat effects, treat it as a new
combat feature with a separate 12-profession x 8-difficulty and PVP-zero review;
never silently expand this narrative contract.

## 5. Design cycle companions

Keep S1 moon-memory companions distinct from both existing pet systems:

```text
shared pet: account .pets.json
personal companion: /spirit_companion/record
S1 moon-memory companion: /plus/illusion_realm/S1/newmoon_journey/companion
```

Never read or write the first two stores while choosing, collecting, switching,
or remembering a moon companion. Give every collected species one immutable
64-character server-generated ID. Use deterministic story rescue, never duplicate
eggs, fragments, fusion, random draws, or paid acceleration.

For the first version, moon companions provide exploration identity, dialogue,
collection, traits, and a single active travel companion. They do not occupy or
overwrite the old battle-pet source and do not introduce a new damage formula.
State this clearly in the UI. If combat participation is later approved, add one
unified `shared | personal | seasonal` battle-source resolver and prove that only
one data pet can act; do not bolt a second action onto existing combat.

Keep personality choices non-economic. Let them change dialogue, memory text,
animation, or final journey summaries, not combat or ranking strength. On cycle
settlement, retain the collection in the same character archive for Eternal Echo
viewing. Do not mint a second permanent pet or skill item.

## 6. Preserve Worker and settlement safety

Route side-quest travel only through the existing `user::move()` and map-Worker
handoff path. Accept only canonical static rooms inside the active S1 content root.
Reject combat travel and stop ordinary autofight through its normal daemon before
moving. If already in the exact room, record only the ordinary idempotent room
visit; do not fabricate the side-quest act.

Put every journey mutation command in the HTTP core/world queue. A successful
handoff carries the one player archive, including journey state, under the existing
owner and lease epoch. A stale Worker must not maintain its own copy or save through
a side channel.

Because settlement retains the same `.o` archive, the overlay returns with the
character automatically. Never add copy/merge logic. Closed Eternal Echo access
may display and finish narrative collection, but must not reactivate active-cycle
rankings, duplicate set rewards, or create combat inheritance.

## 7. Validate the overlay

Add focused TestUnit that proves:

- exact config counts, unique IDs, canonical rooms, and deterministic four acts;
- every gate ID and final event maps to the matching main-story volume;
- real room movement followed by four separately saved acts;
- final act rejection before its authoritative story event;
- physical item count and pity remain unchanged after substitute completion;
- an isolated forged substitute field does not satisfy a gate;
- starter choice, duplicate prevention, five-species collection, nine memories,
  bounded traits, and immutable 64-character IDs;
- save failure rollback and destroy/restore persistence;
- no writes to ordinary skills, shared pets, personal companions, wallets, PVP,
  difficulty, ranking, or combat formulas;
- new route chronology and legacy final-boss route-mark compatibility;
- command compilation and HTTP world-queue placement.

Then rerun the existing S1 focused suite, 12-profession 81-chapter journey,
map-Worker architecture, ordinary Eternal autofight/task regressions, and the full
restart suite. Require zero failures and three healthy active Workers. Inspect the
exact diff and exclude account files, runtime JSON, rankings, logs, caches, and
other generated data.
