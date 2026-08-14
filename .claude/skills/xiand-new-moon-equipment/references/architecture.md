# Architecture and schemas

## Collection catalog

The production lineage uses one common denominator of 300000. Weights describe
probability per successful equipment-drop opportunity, not per NPC kill.

| Rank | ID | Name | Quality | Min NPC level | Min affixes | Weight | Probability |
|---:|---|---|---|---:|---:|---:|---:|
| 1 | `newmoon` | 新月 | 稀世 | 69 | 1 | 300 | 1/1000 |
| 2 | `starshine` | 曜星 | 绝世 | 90 | 2 | 100 | 1/3000 |
| 3 | `firmament` | 天穹 | 传说 | 110 | 3 | 30 | 1/10000 |
| 4 | `greatvoid` | 太虚 | 神话 | 130 | 4 | 10 | 1/30000 |
| 5 | `primordial` | 太初 | 太古 | 160 | 5 | 3 | 1/100000 |
| 6 | `hongmeng` | 鸿蒙 | 至尊 | 200 | 6 | 1 | 1/300000 |

At all six ranks the exclusive roll bands are:

- Hongmeng: 1
- Primordial: 2..4
- Great Void: 5..14
- Firmament: 15..44
- Starshine: 45..144
- New Moon: 145..444
- no collection: 445..300000

If the NPC misses a rank's level gate, that rank's band yields no collection; it
must not fall through. This keeps every lower-rank probability invariant.

## Quality

Base attack/attack limit/armor defense percentages are 100, 105, 110, 116, 123,
and 132. Apply them in equipment getters so dynamic level scaling remains the
single source of raw base values. Do not scale affixes or set bonuses again.

All ranks reuse the same profession-specific five milestones at 2/4/6/8/10
pieces. A full ten-piece set reaches 200% profession resonance. Collection IDs
must match; different ranks cannot be combined to satisfy a milestone.

## Templates and generated files

- `orgItems.list` must contain exactly 120 unique New Moon base paths.
- `allItems.list` must contain exactly one effective affix profile for each path.
- Every profile must provide at least six valid affix choices for Hongmeng.
- The physical bases remain level 69 and retain old images and profession metadata.
- Generated ranks 2..6 append `_nm<rank>` after the ordinary attribute/level
  suffix and inject `set_newmoon_collection("<id>")` into source.
- Rank-to-ID and suffix assignments are permanent. Never reorder an existing rank.
- Generated publication uses `write_item_file()` and its cross-process atomic
  lock. Do not replace it with direct writes.

## Binding and trading

Raw collection drops begin unbound and keep ordinary drop/send/trade/storage
permissions. `ITEMSD->bind_newmoon_item_to_player()` binds on:

- equip or legacy equipped-item migration;
- reforge/reset;
- socket/change socket;
- artisan mutation;
- controlled pity, choice, or compensation delivery.

After binding, immutable account ownership is authoritative. All transaction
daemons must recheck it even if mutable permission flags were tampered with.

## Personal/shared warehouse row

The historical row starts with indices 0..6. Extensions are:

- 7: permanent item ID (empty before shared storage assigns it)
- 8: gem/socket snapshot
- 9: New Moon binding snapshot, or an empty mapping placeholder
- 10: higher-collection snapshot

The collection snapshot is exactly:

```pike
(["version":1,"collection_id":"starshine"])
```

Rank-1 New Moon needs no collection snapshot because resonance metadata with no
explicit ID defaults to `newmoon`. Rows of lengths 7 through 10 remain valid.
Length 11 is valid only with a recognized rank-2..6 snapshot at index 10.

## Display

Base source names retain `【新月·职业】` for compatibility. At runtime, remove
that one legacy fragment and prefix `【集合·品质·职业】`. Apply the transformation
to both `query_name_cn()` and `query_short()` without changing `name`, program
path, raw source name, or command IDs.
