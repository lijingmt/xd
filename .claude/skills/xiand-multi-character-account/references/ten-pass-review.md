# Ten-pass review

Perform these as independent passes. Re-read the changed diff and gather fresh
evidence in each pass instead of treating one successful test as proof for all.

1. **Legacy compatibility** — Trace old registration, first login, direct TXD,
   Socket/JSP, automatic browser, Vue auto-entry, old password change, and an
   account that never creates another character. Confirm zero manifest writes.
2. **Persistence and recovery** — Trace child creation, manifest atomicity,
   valid-main, valid-backup, invalid-main, dual-corruption, missing-child,
   rollback, crash leftovers, backup/restore, and lazy directory creation.
3. **Authorization and privacy** — Try foreign IDs, forged ownership, invalid
   pairs, expired/random tokens, method misuse, URL/log/cache leakage, session
   flooding, path traversal, and direct-child authentication boundaries.
4. **Concurrency and causality** — Examine simultaneous creates, duplicate
   clicks, parallel same-character commands, sibling switching, autosave,
   password changes, connection cleanup, mutex order, partial failure, and
   bounded tables/queues.
5. **Profession initialization** — Check every supported pair, pending-state
   retry, duplicate prevention, starter skill/equipment/medicine, auto-equip,
   guide, spawn, registration side effects, save/relogin, and future profession
   catalog growth.
6. **Independent gameplay state** — Compare two characters' level, skills,
   inventory, wallet, tasks, home, social IDs, guild/team, storage, VIP,
   auto-fight, drops, death, and high-level progression for accidental sharing.
7. **Vue and device UX** — Test one/many profiles, create/select/cancel/logout,
   expired token, unavailable save, failed request, refresh, URL TXD login,
   polling pause/resume, autofight, focus, scrolling, phone/tablet/desktop, and
   built artifact parity.
8. **Password and recovery** — Exercise settings, admin, and mobile/security-code
   recovery from default and child profiles; inspect every main/backup file,
   live object, HTTP cache, session, old TXD, new TXD, rollback, and sanitized
   logs.
9. **Zones and deployment** — Verify generated IDs retain zone prefixes,
   isolation policy still applies, containers mount the full data root,
   first deployment needs no seed, rebuild/restart preserves data, permissions
   work, and `u/` plus `accounts/` restore together.
10. **Release hygiene** — Run static audit, Vue tests/build, targeted Pike tests,
    full restart, HTTP method/auth checks, port checks, artifact comparisons,
    error-log scans, test cleanup, `git diff --check`, selective staging, and
    remote commit verification. Confirm main remains unmerged when requested.
