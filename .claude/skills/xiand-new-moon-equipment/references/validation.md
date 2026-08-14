# Validation and review

## Focused TestUnit coverage

Primary tests:

- `test_unit/test_new_moon_equipment.pike`
- `test_unit/test_new_moon_binding.pike`
- `test_unit/test_account_shared_storage.pike`

Keep these proofs:

1. Exactly 120 unique bases compile for 12 professions and 10 slots.
2. All six identities map over all bases (720 combinations).
3. Catalog values, rank ordering, exact roll boundaries, and level gates match.
4. Every base has at least six supported, positive, correctly slotted affixes.
5. Each rank scales base attack/defense by the expected percentage.
6. Each complete ten-piece rank activates only its own 200% resonance.
7. Mixed ranks, themes, duplicate objects, duplicate slots, and broken items do not
   inflate set counts.
8. Ranks 2..6 generate distinct suffixes, display the correct identity, and retain
   it across another reforge.
9. Ordinary legacy equipment still reforges with no collection identity or suffix.
10. Higher collection identity survives `pikenv` save/restore and personal/shared
    warehouse round trips; binding owner survives with it.
11. Unknown IDs and malformed snapshots fail without changing the current item.
12. Old `query_name_cn()` and Vue/API `query_short()` show the same collection.

## Real restart

From `/usr/local/games/xiand`, run:

```bash
./scripts/restart_map_workers_with_testunit.sh --workers 3
```

Require a line equivalent to:

```text
[TESTUNITD] COMPLETE passed=<all> failed=0 skipped=<expected>
```

Then require active cluster health and HTTP health:

```bash
./scripts/map_worker_cluster.sh health
curl -fsS http://127.0.0.1:8888/health
```

Inspect `log/stderr.13800` for the focused assertions and for new `FAIL`, compile,
storage, transaction, null-object, or backtrace output. Startup fixture messages
that intentionally exercise fallback are not production fallback if final health
reports active and healthy.

## Ten-pass final review

1. Drop math and invariant probabilities.
2. Level gates, affix capacity, and stat monotonicity.
3. 120-base/720-identity completeness and slot uniqueness.
4. Dynamic suffix/source identity and atomic multi-Worker publication.
5. Reforge, reset, socket, artisan, and generated-file cleanup.
6. Bind ownership and all cross-account market exits.
7. Personal/shared storage schemas, legacy rows, saves, and handoff.
8. Set counting, mixed ranks/themes, durability, duplicates, and PVP getters.
9. Legacy JSP, auction, inventory, JSON/Vue names, images, and command IDs.
10. Full restart, complete TestUnit, HTTP/Worker health, logs, staged diff, and
    standalone English commit scope.

If a review finds a gap, add the failing TestUnit assertion first, fix it, and run
the complete restart again. Do not waive a failure as “only a test” until the test
state and production state are proven different.
