#!/usr/bin/env python3
"""Fail-closed license audit for Xiand's locked frontend dependencies."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ALLOWED_LICENSES = {
    "0BSD",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "MIT",
    "Zlib",
}
EXACT_VERSION = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")
DIRECT_SECTIONS = ("dependencies", "devDependencies", "optionalDependencies")


def load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"missing required file: {path}")
        return {}
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"cannot read {path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"expected a JSON object in {path}")
        return {}
    return value


def license_id(value: Any) -> str | None:
    """Accept one unambiguous SPDX identifier only."""
    return value if isinstance(value, str) and value in ALLOWED_LICENSES else None


def package_dir(node_modules: Path, package_name: str) -> Path:
    return node_modules.joinpath(*package_name.split("/"))


def has_license_file(directory: Path) -> bool:
    try:
        return any(
            entry.is_file()
            and (entry.name.upper().startswith("LICENSE") or entry.name.upper().startswith("COPYING"))
            and entry.stat().st_size > 0
            for entry in directory.iterdir()
        )
    except OSError:
        return False


def direct_dependencies(package_json: dict[str, Any], errors: list[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for section in DIRECT_SECTIONS:
        values = package_json.get(section, {})
        if values is None:
            continue
        if not isinstance(values, dict):
            errors.append(f"package.json {section} must be an object")
            continue
        for name, version in values.items():
            if not isinstance(name, str) or not isinstance(version, str):
                errors.append(f"invalid dependency entry in {section}: {name!r}")
                continue
            previous = result.get(name)
            if previous is not None and previous != version:
                errors.append(f"{name} has conflicting direct versions: {previous} and {version}")
            result[name] = version
    return result


def audit(project: Path) -> int:
    errors: list[str] = []
    package_json = load_json(project / "package.json", errors)
    package_lock = load_json(project / "package-lock.json", errors)
    direct = direct_dependencies(package_json, errors)
    packages = package_lock.get("packages", {})
    if not isinstance(packages, dict):
        errors.append("package-lock.json packages must be an object")
        packages = {}

    lock_version = package_lock.get("lockfileVersion")
    if not isinstance(lock_version, int) or lock_version < 2:
        errors.append("package-lock.json must use lockfileVersion 2 or newer")

    print(f"Project: {project}")
    print(f"Allowed licenses: {', '.join(sorted(ALLOWED_LICENSES))}")

    node_modules = project / "node_modules"
    for name in sorted(direct):
        declared_version = direct[name]
        prefix = f"direct {name}@{declared_version}"
        before = len(errors)
        if not EXACT_VERSION.fullmatch(declared_version):
            errors.append(f"{prefix}: version must be an exact semantic version")

        lock_entry = packages.get(f"node_modules/{name}")
        if not isinstance(lock_entry, dict):
            errors.append(f"{prefix}: missing lockfile package entry")
            lock_entry = {}
        locked_version = lock_entry.get("version")
        if locked_version != declared_version:
            errors.append(f"{prefix}: lockfile version is {locked_version!r}")
        locked_license = license_id(lock_entry.get("license"))
        if locked_license is None:
            errors.append(f"{prefix}: lockfile license is missing, ambiguous, or not allowed: {lock_entry.get('license')!r}")

        installed_dir = package_dir(node_modules, name)
        installed_json = load_json(installed_dir / "package.json", errors)
        installed_version = installed_json.get("version")
        if installed_version != declared_version:
            errors.append(f"{prefix}: installed version is {installed_version!r}")
        installed_license = license_id(installed_json.get("license"))
        if installed_license is None:
            errors.append(f"{prefix}: installed license is missing, ambiguous, or not allowed: {installed_json.get('license')!r}")
        if locked_license and installed_license and locked_license != installed_license:
            errors.append(f"{prefix}: lockfile license {locked_license} disagrees with installed license {installed_license}")
        if not has_license_file(installed_dir):
            errors.append(f"{prefix}: installed package has no non-empty LICENSE/COPYING file")

        if len(errors) == before:
            print(f"PASS {name}@{declared_version} ({locked_license})")

    license_counts: Counter[str] = Counter()
    lock_package_count = 0
    for path, entry in sorted(packages.items()):
        if not path or not str(path).startswith("node_modules/"):
            continue
        lock_package_count += 1
        if not isinstance(entry, dict):
            errors.append(f"lock entry {path} is not an object")
            continue
        raw_license = entry.get("license")
        accepted_license = license_id(raw_license)
        if accepted_license is None:
            errors.append(f"lock entry {path} has missing, ambiguous, or disallowed license: {raw_license!r}")
            continue
        license_counts[accepted_license] += 1

    print(f"Locked packages checked: {lock_package_count}")
    print("License summary: " + ", ".join(f"{name}={license_counts[name]}" for name in sorted(license_counts)))

    if errors:
        print(f"FAIL: {len(errors)} issue(s)", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("PASS: every locked frontend dependency meets the permissive-license gate")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="vue_source", help="directory containing package.json and package-lock.json")
    args = parser.parse_args()
    return audit(Path(args.project).resolve())


if __name__ == "__main__":
    raise SystemExit(main())
