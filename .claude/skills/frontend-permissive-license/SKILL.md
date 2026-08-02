---
name: frontend-permissive-license
description: Audit frontend npm, JavaScript, and CSS libraries for Xiand before adding, upgrading, vendoring, or distributing them. Use when introducing or updating a frontend dependency, checking an open-source license, confirming free commercial use, changing package.json or package-lock.json, or copying third-party code or assets into Vue build output.
---

# Frontend Permissive License Review

Only admit an exact library version after proving that it is open source, permissively licensed, free for commercial use, and practical to distribute with all required notices. Treat ambiguity as a failed review, not as permission.

## Admission Policy

The conservative eligible list is:

- MIT
- ISC
- BSD-2-Clause
- BSD-3-Clause
- Apache-2.0
- 0BSD
- Zlib

This list makes a package eligible for review; it does not waive attribution, LICENSE, NOTICE, patent, or redistribution obligations.

Block the dependency when any of these conditions applies:

- GPL, AGPL, LGPL, MPL, EPL, CDDL, or another copyleft license;
- SSPL, BSL, PolyForm, Commons Clause, source-available, noncommercial, no-derivatives, field-of-use, user-count, or fee restrictions;
- a custom, missing, ambiguous, conflicting, or unrecognized license;
- a compound or multi-license expression without a documented approved selection;
- no traceable exact-version source or release artifact;
- any direct or transitive dependency that fails the same policy.

Do not create automatic exceptions. If a package fails, choose a compliant alternative or pause for explicit legal review.

## Review Workflow

1. Inspect the intended change and identify every exact direct version, all lockfile dependencies, and whether code will be linked, bundled, vendored, copied, or merely used as a tool.
2. Gather three matching sources of evidence for each direct dependency:
   - package registry or installed `package.json` metadata;
   - the actual LICENSE or COPYING file shipped by that exact package version;
   - the official repository or release tag for that exact version.
3. Never approve from a README badge or repository homepage alone. Stop if the version, license, owner, or text conflicts.
4. Require exact versions in `package.json` and a synchronized lockfile. Reject `^`, `~`, `*`, branches, moving tags, and unpinned URLs.
5. Run the repository gate:

   ```bash
   python3 .claude/skills/frontend-permissive-license/scripts/audit_frontend_licenses.py --project vue_source
   ```

6. Preserve every required LICENSE and NOTICE in the product. For Xiand, update `vue_source/build.js`, the development/shared build paths, and `web/web_vue/vendor/` where applicable.
7. Update `docs/frontend-open-source-license-memo.md` with package name, exact version, license, source, purpose, obligations, and review date.
8. Treat security and license checks independently. Run the relevant frontend validation, including:

   ```bash
   cd vue_source
   npm audit --omit=dev
   npm test
   npm run build
   ```

9. Report an approval or rejection with evidence and remaining obligations. Describe the result as an engineering compliance review, never as a legal guarantee.

## Important Boundaries

- A code package's license does not automatically cover its sample images, fonts, audio, video, icons, animations, models, data, trademarks, or third-party services. Review those separately.
- Review every upgrade again. A package may change its own license or acquire new transitive dependencies.
- Preserve Apache-2.0 NOTICE and modification notices when they apply.
- Confirm whether an apparently free package requires a separate paid commercial license. If it does, it does not meet this Skill's default admission rule.
- Do not claim that a permissive license removes trademark, patent, privacy, export, platform, or content-law obligations.

## Included Tool

`scripts/audit_frontend_licenses.py` performs a deterministic local gate over `package.json`, `package-lock.json`, installed package metadata, and LICENSE/COPYING files. It deliberately fails closed when evidence is missing or outside the allowlist.
