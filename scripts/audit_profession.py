#!/usr/bin/env python3
"""Project-level read-only coverage audit for a Xiand profession ID."""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
from pathlib import Path


CHECKS = (
    ("creation", ("gamelib/d/init",), True),
    ("initial_stats", ("lowlib/mudlib/inherit/user.pike",), True),
    ("identity", ("lowlib/mudlib/inherit/feature/char.pike",), True),
    ("shared_identity", (
        "lowlib/system/inherit/base.pike",
        "gamelib/cmds/look_top.pike",
        "gamelib/cmds/my_games.pike",
    ), True),
    ("level_growth", ("lowlib/mudlib/inherit/feature/level.pike",), True),
    ("combat_formula", (
        "lowlib/mudlib/inherit/feature/attack.pike",
        "lowlib/wapmud2/inherit/feature/fight.pike",
    ), False),
    ("user_lifecycle", ("gamelib/clone/user.pike", "gamelib/d/init"), True),
    ("book_store", (
        "gamelib/data/can_buy_book_list.csv",
        "gamelib/cmds/buy_items.pike",
    ), True),
    ("store_security", (
        "gamelib/single/daemons/buyd.pike",
        "gamelib/cmds/buy_items.pike",
    ), True),
    ("skill_ui", (
        "gamelib/cmds/myskills.pike",
        "gamelib/cmds/newbie_guide.pike",
    ), True),
    ("equipment", (
        "lowlib/mudlib/inherit/feature/equip.pike",
        "gamelib/single/daemons/itemsd.pike",
        "gamelib/single/daemons/bossdropd.pike",
        "gamelib/cmds/auto_equip.pike",
    ), False),
    ("tasks", (
        "gamelib/single/daemons/taskd.pike",
        "gamelib/data/task/task_list.csv",
    ), True),
    ("newbie", (
        "gamelib/cmds/newbie_guide.pike",
        "gamelib/single/daemons/newbied.pike",
    ), True),
    ("autofight", ("gamelib/single/daemons/autofightd.pike",), True),
    ("documentation", (
        "docs/build_xiand_profession_guide.py",
        "docs/build_xiand_skill_guide.py",
    ), True),
)

CONDITIONAL_CHECKS = (
    ("profession_vip", (
        "gamelib/single/daemons/professionvipd.pike",
        "gamelib/cmds/profession_assistant.pike",
    )),
    ("http_serialization", (
        "gamelib/single/d/http_api/thread_manager.pike",
        "gamelib/single/daemons/_http_api_mod/thread_manager.pike",
    )),
    ("vue_identity", (
        "vue_source/index.html",
        "vue_source/js/app.js",
        "vue_source/css/app.css",
    )),
)

ITEM_DIRS = ("food", "water", "liandan", "teyao")
MOVEMENT_FLAGS = (
    "set_item_canDrop(1)",
    "set_item_canGet(1)",
    "set_item_canTrade(1)",
    "set_item_canSend(1)",
    "set_item_canStorage(1)",
)
IMAGE_SUFFIXES = {".gif", ".jpeg", ".jpg", ".png", ".webp"}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def contains_any(root: Path, relative: str, needles: list[str]) -> bool:
    text = read_text(root / relative)
    return any(needle and needle in text for needle in needles)


def report(status: str, area: str, detail: str) -> None:
    print(f"{status:5} {area:22} {detail or '-'}")


def digest(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return ""


def asset_candidates(root: Path, prefix: str, role: str) -> list[Path]:
    return sorted(
        path for path in (root / "images").glob(f"{prefix}_{role}.*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def catalog_rows(root: Path, profession: str) -> list[list[str]]:
    path = root / "gamelib/data/can_buy_book_list.csv"
    try:
        with path.open(encoding="utf-8", errors="replace", newline="") as handle:
            return [row for row in csv.reader(handle)
                    if len(row) > 3 and row[3].strip() == profession]
    except OSError:
        return []


def referenced_skill(book_text: str) -> str:
    match = re.search(r'skill_bname\s*=\s*"([^"]+)"', book_text)
    return match.group(1) if match else ""


def skill_belongs_to_profession(text: str, profession: str) -> bool:
    return bool(re.search(
        r'skill_type\s*\+=\s*\(\{[^}]*"'
        + re.escape(profession) + r'"', text, re.S))


def book_belongs_to_profession(root: Path, text: str, profession: str,
                               name_cn: str) -> bool:
    if name_cn and re.search(
            r'profe_read_limit\s*=\s*"' + re.escape(name_cn) + r'"', text):
        return True
    skill = referenced_skill(text)
    return bool(skill and skill_belongs_to_profession(
        read_text(root / "gamelib/single/skills" / skill), profession))


def hidden_books(root: Path, profession: str, name_cn: str) -> list[Path]:
    results: list[Path] = []
    for path in sorted((root / "gamelib/clone/item/book").glob("*")):
        if not path.is_file():
            continue
        text = read_text(path)
        if (book_belongs_to_profession(root, text, profession, name_cn)
                and re.search(r"level_limit\s*=\s*80\b", text)
                and re.search(r"need_yushi\s*=\s*0\b", text)
                and re.search(r"need_money\s*=\s*0\b", text)):
            results.append(path)
    return results


def parse_hidden_pool(source: str) -> tuple[list[str], int]:
    block = re.search(
        r"hidden_skill_books\s*=\s*\(\{(.*?)\}\);", source, re.S)
    books = re.findall(r'"book/([^"]+)"', block.group(1)) if block else []
    rate_match = re.search(r"hidden_skill_drop_rate\s*=\s*(\d+)", source)
    rate = int(rate_match.group(1)) if rate_match else -1
    return books, rate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profession", help="lowercase Xiand profession ID")
    parser.add_argument("--name-cn", default="", help="Chinese display name")
    parser.add_argument("--race", default="", help="expected race ID, e.g. third")
    parser.add_argument("--expect-hidden", type=int, default=3,
                        help="expected level-80 drop-only books; -1 disables")
    parser.add_argument("--require-assets", action="store_true",
                        help="require profession-prefixed logo and gender avatars")
    parser.add_argument("--asset-prefix", default="",
                        help="asset prefix when it differs from profession ID")
    parser.add_argument("--allow-missing", action="append", default=[],
                        help="documented generic/intentional CHECKS area to exempt")
    parser.add_argument("--root", default=".", help="Xiand repository root")
    args = parser.parse_args()

    profession = args.profession.strip().lower()
    name_cn = args.name_cn.strip()
    race = args.race.strip().lower()
    root = Path(args.root).resolve()
    if not re.fullmatch(r"[a-z][a-z0-9_]*", profession):
        parser.error("profession must be a lowercase ASCII-style ID")
    if args.expect_hidden < -1:
        parser.error("--expect-hidden must be -1 or greater")

    needles = [profession]
    if name_cn:
        needles.append(name_cn)
    exemptions = set(args.allow_missing)
    known_areas = {area for area, _, _ in CHECKS}
    unknown_exemptions = sorted(exemptions.difference(known_areas))
    if unknown_exemptions:
        parser.error("unknown --allow-missing area(s): "
                     + ", ".join(unknown_exemptions))
    failures = 0

    print(f"Xiand profession static audit: {profession}")
    for area, files, require_all in CHECKS:
        hits = [path for path in files if contains_any(root, path, needles)]
        passed = len(hits) == len(files) if require_all else bool(hits)
        if passed:
            report("PASS", area, ", ".join(hits))
        elif area in exemptions:
            report("N/A", area, "documented generic/intentional route")
        else:
            report("MISS", area, ", ".join(hits))
            failures += 1

    for area, files in CONDITIONAL_CHECKS:
        hits = [path for path in files if contains_any(root, path, needles)]
        report("INFO", area, ", ".join(hits) or "explicit decision required")

    rows = catalog_rows(root, profession)
    missing_objects: list[str] = []
    missing_skills: list[str] = []
    catalog_paths: set[str] = set()
    for row in rows:
        relative = row[1].strip() if len(row) > 1 else ""
        if not relative:
            continue
        catalog_paths.add(relative.removeprefix("book/"))
        book_path = root / "gamelib/clone/item" / relative
        book_text = read_text(book_path)
        if not book_text:
            missing_objects.append(relative)
            continue
        skill = referenced_skill(book_text)
        if not skill or not (root / "gamelib/single/skills" / skill).is_file():
            missing_skills.append(f"{relative}->{skill or '?'}")
    catalog_ok = bool(rows) and not missing_objects and not missing_skills
    report("PASS" if catalog_ok else "MISS", "catalog_integrity",
           f"rows={len(rows)} missing_books={len(missing_objects)} "
           f"missing_skills={len(missing_skills)}")
    failures += not catalog_ok

    skills = [path for path in (root / "gamelib/single/skills").glob("*")
              if path.is_file() and skill_belongs_to_profession(
                  read_text(path), profession)]
    books = [path for path in (root / "gamelib/clone/item/book").glob("*")
             if path.is_file() and book_belongs_to_profession(
                 root, read_text(path), profession, name_cn)]
    runtime_files_ok = bool(skills) and bool(books)
    report("PASS" if runtime_files_ok else "MISS", "runtime_files",
           f"skills={len(skills)} books={len(books)}")
    failures += not runtime_files_ok

    hidden = hidden_books(root, profession, name_cn)
    item_source = read_text(root / "gamelib/single/daemons/itemsd.pike")
    pool, pool_rate = parse_hidden_pool(item_source)
    hidden_names = {path.name for path in hidden}
    pool_missing = sorted(hidden_names.difference(pool))
    movement_missing = [path.name for path in hidden
                        if any(flag not in read_text(path) for flag in MOVEMENT_FLAGS)]
    leaked_store = sorted(hidden_names.intersection(catalog_paths))
    hidden_ok = (args.expect_hidden == -1 or len(hidden) == args.expect_hidden)
    hidden_ok = hidden_ok and not pool_missing and not movement_missing and not leaked_store
    report("PASS" if hidden_ok else "MISS", "hidden_books",
           f"found={len(hidden)} expected={args.expect_hidden} "
           f"pool_missing={pool_missing or '-'} movement_missing={movement_missing or '-'} "
           f"store_leaks={leaked_store or '-'}")
    failures += not hidden_ok

    pool_ok = bool(pool) and pool_rate == len(pool)
    report("PASS" if pool_ok else "MISS", "hidden_pool_rate",
           f"pool={len(pool)} shared_rate={pool_rate}")
    failures += not pool_ok

    item_hits: list[str] = []
    for directory in ITEM_DIRS:
        for path in (root / "gamelib/clone/item" / directory).glob("*"):
            if path.is_file() and contains_any(root, str(path.relative_to(root)), needles):
                item_hits.append(str(path.relative_to(root)))
    item_ok = bool(item_hits)
    report("PASS" if item_ok else "MISS", "recovery_items",
           f"matching_files={len(item_hits)}")
    failures += not item_ok

    teacher = root / f"gamelib/clone/npc/{profession}_teacher.pike"
    plazas = (
        root / "gamelib/d/congxianzhen/congxianzhenguangchang",
        root / "gamelib/d/jinaodao/yuhuacunguangchang",
    )
    teacher_ok = (teacher.is_file()
                  and all(profession in read_text(path) for path in plazas))
    report("PASS" if teacher_ok else "MISS", "teacher_and_plazas",
           f"teacher={teacher.is_file()} plazas="
           f"{sum(profession in read_text(path) for path in plazas)}/2")
    failures += not teacher_ok

    test_files = sorted(path for path in (root / "test_unit").glob("*.pike")
                        if profession in path.name or contains_any(
                            root, str(path.relative_to(root)), needles))
    test_ok = any(profession in path.name for path in test_files)
    report("PASS" if test_ok else "MISS", "dedicated_test",
           ", ".join(path.name for path in test_files if profession in path.name) or "-")
    failures += not test_ok

    if race:
        init = read_text(root / "gamelib/d/init")
        char = read_text(root / "lowlib/mudlib/inherit/feature/char.pike")
        neutral_ok = race in init and race in char and profession in init and profession in char
        if race == "third":
            neutral_ok = neutral_ok and "fangshi" in init and "zhenyue" in init
        report("PASS" if neutral_ok else "MISS", "race_coexistence",
               f"race={race}; runtime social/faction tests still required")
        failures += not neutral_ok

    if args.require_assets:
        asset_prefix = args.asset_prefix.strip() or profession
        sources = {
            role: asset_candidates(root, asset_prefix, role)
            for role in ("logo", "male", "female")
        }
        selected = {role: paths[0] if paths else None
                    for role, paths in sources.items()}
        mirrors_ok = all(selected.values())
        if mirrors_ok:
            mirrors_ok = all(
                (root / "web/images" / path.name).is_file()
                and (root / "web/images" / path.name).stat().st_size > 0
                and path.stat().st_size > 0
                and digest(path) == digest(root / "web/images" / path.name)
                for path in selected.values()
            )
        source_male = selected["male"]
        source_female = selected["female"]
        distinct_gender = (source_male is not None and source_female is not None
                           and digest(source_male)
                           and digest(source_male) != digest(source_female))
        deploy = read_text(root / "restart-docker.sh")
        deploy_ok = all(path is not None and path.name in deploy
                        for path in selected.values())
        assets_ok = mirrors_ok and distinct_gender and deploy_ok
        report("PASS" if assets_ok else "MISS", "assets_and_deploy",
               f"prefix={asset_prefix} roles="
               f"{sum(bool(paths) for paths in sources.values())}/3 "
               f"mirrors={mirrors_ok} distinct_gender={bool(distinct_gender)} "
               f"deploy={deploy_ok}")
        failures += not assets_ok

    print(f"SUMMARY missing_areas={failures}; runtime validation still required")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
