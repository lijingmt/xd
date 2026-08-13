#!/usr/bin/env python3
"""Create a private, read-only balance snapshot for exact jade evidence.

Only character ids already selected by the evidence scanner are opened.  The
script never edits a player, wallet, or storage file and prints aggregate
counts only; the private output is the input to ``audit_illicit_jade.py``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path


MAX_INPUT_SIZE = 32 * 1024 * 1024
MAX_VALUE = 1_000_000_000_000
JADE_VALUES = {
    "suiyu": 1,
    "xianyuanyu": 10,
    "linglongyu": 100,
    "biluanyu": 1_000,
    "xuantianbaoyu": 10_000,
}
VALID_USERID = re.compile(r"^[A-Za-z0-9_]{2,64}$")
INVENTORY_JADE = re.compile(
    r"#~/gamelib/clone/item/yushi/"
    r"(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)"
    r"\\n(?:(?!\\n\"[,}]).)*?amount (\d+)\\n"
)
PERSONAL_STORAGE_JADE = re.compile(
    r'\(\{(?:"(?:\\.|[^"\\])*",){3}"yushi/'
    r'(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)",'
    r"-?\d+,-?\d+,(\d+),"
)


def read_private_file(path: Path, maximum: int = MAX_INPUT_SIZE) -> str:
    if path.is_symlink() or not path.is_file():
        raise ValueError("missing or symlinked input")
    size = path.stat().st_size
    if size <= 0 or size > maximum:
        raise ValueError("input size is invalid")
    return path.read_text(encoding="utf-8", errors="replace")


def scalar_int(source: str, name: str) -> int:
    match = re.search(rf"(?m)^{re.escape(name)} (-?\d+)\s*$", source)
    value = int(match.group(1)) if match else 0
    if value < 0 or value > MAX_VALUE:
        raise ValueError(f"{name} is outside the accepted range")
    return value


def account_owner(source: str, userid: str) -> str:
    match = re.search(
        r'(?m)^account_owner "([A-Za-z0-9_]{2,64})"\s*$', source
    )
    owner = match.group(1) if match else userid
    if not VALID_USERID.fullmatch(owner):
        raise ValueError("invalid account owner")
    return owner


def jade_value(matches: list[tuple[str, str]]) -> int:
    total = sum(int(amount) * JADE_VALUES[name] for name, amount in matches)
    if total < 0 or total > MAX_VALUE:
        raise ValueError("jade holding is outside the accepted range")
    return total


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    source = read_private_file(path, 16 * 1024 * 1024)
    decoded = json.loads(source)
    if not isinstance(decoded, dict):
        raise ValueError("JSON record must be an object")
    return decoded


def nonnegative_int(value: object, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{field} must be an integer")
    if value < 0 or value > MAX_VALUE:
        raise ValueError(f"{field} is outside the accepted range")
    return value


def shared_source_jade(record: dict, userid: str) -> int:
    items = record.get("items", [])
    if not isinstance(items, list):
        raise ValueError("shared storage items must be an array")
    total = 0
    for item in items:
        if not isinstance(item, dict) or item.get("source_character") != userid:
            continue
        data = item.get("data")
        if not isinstance(data, list) or len(data) < 7:
            raise ValueError("shared storage item is invalid")
        path = data[3]
        if not isinstance(path, str) or not path.startswith("yushi/"):
            continue
        name = path.rsplit("/", 1)[-1]
        if name not in JADE_VALUES:
            continue
        amount = nonnegative_int(data[6], "shared jade amount")
        total += amount * JADE_VALUES[name]
        if total > MAX_VALUE:
            raise ValueError("shared jade holding is outside the accepted range")
    return total


def candidate_ids(manifest: dict) -> list[str]:
    if manifest.get("schema_version") != 2:
        raise ValueError("candidate manifest schema_version must be 2")
    result: set[str] = set()
    for section in ("accounts", "review_only"):
        rows = manifest.get(section, {})
        if not isinstance(rows, dict):
            raise ValueError("candidate manifest section is invalid")
        for userid, row in rows.items():
            if (
                isinstance(userid, str)
                and VALID_USERID.fullmatch(userid)
                and isinstance(row, dict)
                and nonnegative_int(row.get("exact_minted_suiyu", 0), "evidence")
                > 0
            ):
                result.add(userid)
    return sorted(result)


def write_private_json(path: Path, value: dict) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    encoded = (
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    ).encode("utf-8")
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        if temporary.exists():
            temporary.unlink()


def build_snapshot(data_root: Path, candidate_manifest: dict) -> dict:
    captured_at = int(time.time())
    accounts: dict[str, dict] = {}
    errors = {"missing_player": 0, "invalid_player": 0, "invalid_account": 0}
    for userid in candidate_ids(candidate_manifest):
        player_path = data_root / "u" / userid[-2:] / f"{userid}.o"
        try:
            source = read_private_file(player_path)
            physical = jade_value(INVENTORY_JADE.findall(source))
            personal = jade_value(PERSONAL_STORAGE_JADE.findall(source))
            personal_fee = scalar_int(source, "all_fee")
            owner = account_owner(source, userid)
        except ValueError as exc:
            if "missing" in str(exc):
                errors["missing_player"] += 1
            else:
                errors["invalid_player"] += 1
            continue
        try:
            wallet_path = (
                data_root / "accounts" / owner[-2:] / f"{owner}.wallet.json"
            )
            wallet = load_json(wallet_path)
            wallet_balance = (
                nonnegative_int(wallet.get("balance", 0), "wallet balance")
                if wallet
                else 0
            )
            total_fee = max(
                personal_fee,
                nonnegative_int(
                    wallet.get("total_recharge_fee", 0), "total recharge fee"
                )
                if wallet
                else 0,
            )
            storage_path = (
                data_root / "accounts" / owner[-2:] / f"{owner}.storage.json"
            )
            shared = shared_source_jade(load_json(storage_path), userid)
        except (OSError, ValueError, json.JSONDecodeError):
            errors["invalid_account"] += 1
            continue
        canonical = json.dumps(
            {
                "userid": userid,
                "captured_at": captured_at,
                "physical": physical,
                "personal_storage": personal,
                "shared_source": shared,
                "wallet": wallet_balance,
                "all_fee": total_fee,
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        accounts[userid] = {
            "current_physical_suiyu": physical,
            "current_personal_storage_suiyu": personal,
            "current_shared_source_suiyu": shared,
            "current_wallet_suiyu": wallet_balance,
            "all_fee": total_fee,
            "legal_non_all_fee_suiyu": 0,
            "legal_ledger_complete": False,
            "source_snapshot_sha256": hashlib.sha256(canonical).hexdigest(),
        }
    return {
        "schema_version": 1,
        "captured_at": captured_at,
        "accounts": accounts,
        "summary": {"captured_accounts": len(accounts), **errors},
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", required=True, type=Path)
    parser.add_argument("--candidate-manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        manifest = json.loads(read_private_file(args.candidate_manifest))
        if not isinstance(manifest, dict):
            raise ValueError("candidate manifest must be an object")
        snapshot = build_snapshot(args.data_root, manifest)
        write_private_json(args.output, snapshot)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: snapshot failed: {exc}", file=sys.stderr)
        return 2
    summary = snapshot["summary"]
    print(
        "snapshot complete: "
        f"captured_accounts={summary['captured_accounts']} "
        f"missing_player={summary['missing_player']} "
        f"invalid_player={summary['invalid_player']} "
        f"invalid_account={summary['invalid_account']} "
        f"output={args.output} mode=0600"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
