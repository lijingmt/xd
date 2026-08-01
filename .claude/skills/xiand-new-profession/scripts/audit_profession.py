#!/usr/bin/env python3
"""Read-only static coverage audit for a Xiand profession ID."""

from __future__ import annotations

import argparse
from pathlib import Path


CHECKS = {
    "creation": ("gamelib/d/init",),
    "initial_stats": ("lowlib/mudlib/inherit/user.pike",),
    "identity": ("lowlib/mudlib/inherit/feature/char.pike",),
    "level_growth": ("lowlib/mudlib/inherit/feature/level.pike",),
    "combat_formula": ("lowlib/mudlib/inherit/feature/attack.pike",),
    "book_store": (
        "gamelib/data/can_buy_book_list.csv",
        "gamelib/cmds/buy_items.pike",
    ),
    "skill_ui": (
        "gamelib/cmds/myskills.pike",
        "gamelib/cmds/newbie_guide.pike",
    ),
    "equipment": (
        "lowlib/mudlib/inherit/feature/equip.pike",
        "gamelib/single/daemons/itemsd.pike",
        "gamelib/single/daemons/bossdropd.pike",
        "gamelib/cmds/auto_equip.pike",
    ),
    "tasks": (
        "gamelib/single/daemons/taskd.pike",
        "gamelib/data/task/task_list.csv",
    ),
}


def contains(root: Path, relative: str, needle: str) -> bool:
    path = root / relative
    try:
        return needle in path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profession", help="lowercase Xiand profession ID")
    parser.add_argument(
        "--name-cn",
        default="",
        help="optional Chinese display name used by book profession limits",
    )
    parser.add_argument("--root", default=".", help="Xiand repository root")
    args = parser.parse_args()
    profession = args.profession.strip().lower()
    root = Path(args.root).resolve()
    if not profession or not profession.replace("_", "").isalnum():
        parser.error("profession must be a non-empty ASCII-style ID")

    failures = 0
    print(f"Xiand profession static audit: {profession}")
    for area, files in CHECKS.items():
        hits = [path for path in files if contains(root, path, profession)]
        status = "PASS" if hits else "MISS"
        print(f"{status:4} {area:16} {', '.join(hits) or '-'}")
        failures += not hits

    skills = sorted((root / "gamelib/single/skills").glob("*"))
    books = sorted((root / "gamelib/clone/item/book").glob("*"))
    needles = [profession]
    if args.name_cn.strip():
        needles.append(args.name_cn.strip())
    skill_hits = sum(
        any(contains(root, str(p.relative_to(root)), needle) for needle in needles)
        for p in skills
        if p.is_file()
    )
    book_hits = sum(
        any(contains(root, str(p.relative_to(root)), needle) for needle in needles)
        for p in books
        if p.is_file()
    )
    print(f"INFO skill_files      {skill_hits}")
    print(f"INFO book_files       {book_hits}")
    print(f"SUMMARY missing_areas={failures}; runtime validation still required")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
