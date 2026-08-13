#!/usr/bin/env python3
"""Build a review-only, evidence-backed illicit-jade recovery manifest.

The scanner never edits player data.  An executable candidate requires a
fresh balance snapshot plus either an exact mint event or an explicitly
complete ledger for legitimate jade not represented by ``all_fee``. High
balances, conversion volume and same-second bursts by themselves remain review
hints, not confiscation proof.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable


SCHEMA_VERSION = 2
FEE_TO_SUIYU = 10
MAX_AUDIT_VALUE = 1_000_000_000_000
RUNTIME_MAX_RECOVERY = 20_000_000
SNAPSHOT_TTL_SECONDS = 3_600
JADE_VALUES = {
    "suiyu": 1,
    "xianyuanyu": 10,
    "linglongyu": 100,
    "biluanyu": 1_000,
    "xuantianbaoyu": 10_000,
}
DIRECT_GRANT_TYPES = {
    "baoshi",
    "vip_off",
    "yblh",
}
ROOM_CN_TO_KEY = {
    "飞天小屋": "feitianxiaowu",
    "飘香小谢": "piaoxiangxiaoxie",
    "练功草庐": "liangongcaolu",
    "书卷轩室": "shujuanxuanshi",
    "灵光小筑": "lingguangxiaozhu",
    "延寿小榭": "yanshouxiaoxie",
    "延法小榭": "yanfaxiaoxie",
    "力道小筑": "lidaoxiaozhu",
    "流法小筑": "liufaxiaozhu",
    "书香阁楼": "shuxianggelou",
    "灵韵轩室": "lingyunxuanshi",
    "飘影草庐": "piaoyingcaolu",
    "蛮力草屋": "manlicaowu",
    "风雪斋": "fengxuezhai",
}
ROOM_PRICES = {
    "feitianxiaowu": 10,
    "piaoxiangxiaoxie": 5,
    "liangongcaolu": 5,
    "shujuanxuanshi": 5,
    "lingguangxiaozhu": 5,
    "yanshouxiaoxie": 50,
    "yanfaxiaoxie": 50,
    "lidaoxiaozhu": 50,
    "liufaxiaozhu": 50,
    "shuxianggelou": 50,
    "lingyunxuanshi": 50,
    "piaoyingcaolu": 50,
    "manlicaowu": 50,
    "fengxuezhai": 5,
}
ROOM_REFUNDS = {name: int(price * 0.8) for name, price in ROOM_PRICES.items()}

VALID_USERID = re.compile(r"^[A-Za-z0-9_]{2,64}$")
LEGACY_USER = re.compile(r"\(([^()]+)\)\s*(?:将|打算)")
LEGACY_COMBINE = re.compile(
    r"\((\d+)\)\s*(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)"
    r"\s*合成为了\s*\((\d+)\)\s*"
    r"(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)"
)
LEGACY_SPLIT = re.compile(
    r"将\s*\((\d+)\)\s*"
    r"(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)"
    r"\s*打碎获得\s*\((\d+)\)\s*"
    r"(suiyu|xianyuanyu|linglongyu|biluanyu|xuantianbaoyu)"
)
CONSUME = re.compile(
    r"^\[([^]]+)\]-\[([^]]*)\]\[([^]]*)\]\[([^]]*)\]"
    r"\[([^]]*)\]\[([^]]*)\]\[(-?\d+)\]\[(-?\d+)\]\[(-?\d+)\]"
)
VIP_FREE_EVENT = re.compile(
    r"\(([^()]+)\)获得免费物品.*\(([^()]+)\)\s*$"
)
REGISTRATION_FILE = re.compile(r"^xd\.(\d{8})\.txt$")


@dataclasses.dataclass(frozen=True)
class Evidence:
    userid: str
    amount: int
    route: str
    fingerprint: str
    occurred_on: str = ""


@dataclasses.dataclass(frozen=True)
class FinancialSnapshot:
    current_physical_suiyu: int
    current_personal_storage_suiyu: int
    current_shared_source_suiyu: int
    current_wallet_suiyu: int
    all_fee: int
    legal_non_all_fee_suiyu: int
    legal_ledger_complete: bool
    captured_at: int
    fingerprint: str


def valid_userid(value: str) -> bool:
    return bool(VALID_USERID.fullmatch(value))


def line_fingerprint(relative: str, line_number: int, line: str) -> str:
    material = f"{relative}\0{line_number}\0{line}".encode(
        "utf-8", errors="surrogatepass"
    )
    return hashlib.sha256(material).hexdigest()


def load_financial_snapshot(path: Path | None) -> dict[str, FinancialSnapshot]:
    """Read an operator-produced balance snapshot without trusting its shape.

    ``all_fee`` is deliberately multiplied by ten later.  That is exact for
    the current recharge wallet and an over-allowance for the recursive legacy
    counter, so it cannot increase a confiscation amount.
    """

    if path is None:
        return {}
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 16_777_216:
        raise ValueError("financial snapshot is missing, symlinked, or too large")
    decoded = json.loads(path.read_text(encoding="utf-8"))
    schema_version = decoded.get("schema_version") if isinstance(decoded, dict) else None
    if (
        not isinstance(decoded, dict)
        or isinstance(schema_version, bool)
        or schema_version != 1
    ):
        raise ValueError("financial snapshot schema_version must be 1")
    captured_at = decoded.get("captured_at")
    accounts = decoded.get("accounts")
    if (
        isinstance(captured_at, bool)
        or not isinstance(captured_at, int)
        or captured_at <= 0
        or captured_at > int(time.time()) + 300
        or not isinstance(accounts, dict)
    ):
        raise ValueError("financial snapshot metadata is invalid")

    result: dict[str, FinancialSnapshot] = {}
    for userid, raw in accounts.items():
        if not isinstance(userid, str) or not valid_userid(userid):
            raise ValueError("financial snapshot contains an invalid userid")
        if not isinstance(raw, dict):
            raise ValueError("financial snapshot account row must be an object")
        values: list[int] = []
        for field in (
            "current_physical_suiyu",
            "current_personal_storage_suiyu",
            "current_shared_source_suiyu",
            "current_wallet_suiyu",
            "all_fee",
            "legal_non_all_fee_suiyu",
        ):
            value = raw.get(field)
            if (
                isinstance(value, bool)
                or not isinstance(value, int)
                or value < 0
                or value > MAX_AUDIT_VALUE
            ):
                raise ValueError(f"financial snapshot {field} is invalid")
            values.append(value)
        complete = raw.get("legal_ledger_complete") is True
        canonical = json.dumps(
            {
                "userid": userid,
                "captured_at": captured_at,
                "current_physical_suiyu": values[0],
                "current_personal_storage_suiyu": values[1],
                "current_shared_source_suiyu": values[2],
                "current_wallet_suiyu": values[3],
                "all_fee": values[4],
                "legal_non_all_fee_suiyu": values[5],
                "legal_ledger_complete": complete,
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        result[userid] = FinancialSnapshot(
            current_physical_suiyu=values[0],
            current_personal_storage_suiyu=values[1],
            current_shared_source_suiyu=values[2],
            current_wallet_suiyu=values[3],
            all_fee=values[4],
            legal_non_all_fee_suiyu=values[5],
            legal_ledger_complete=complete,
            captured_at=captured_at,
            fingerprint=hashlib.sha256(canonical).hexdigest(),
        )
    return result


def jade_key(value: str) -> str | None:
    candidate = value.rsplit("/", 1)[-1]
    return candidate if candidate in JADE_VALUES else None


def parse_structured_conversion(line: str) -> tuple[str, int] | None:
    if "event=yushi_conversion" not in line:
        return None
    fields: dict[str, str] = {}
    for part in line.rstrip("\n").split("\t"):
        if "=" in part:
            key, value = part.split("=", 1)
            fields[key] = value
    userid = fields.get("player", "")
    if not valid_userid(userid) or fields.get("status") not in {"success", "partial"}:
        return None
    try:
        source_value = int(fields.get("source_value", "0"))
        target_value = int(fields.get("target_value", "0"))
    except ValueError:
        return None
    minted = target_value - source_value
    return (userid, minted) if minted > 0 else None


def registration_dates(registration_root: Path) -> dict[str, str]:
    created: dict[str, str] = {}
    if not registration_root.is_dir():
        return created
    for path in sorted(registration_root.iterdir()):
        match = REGISTRATION_FILE.fullmatch(path.name)
        if not match or not path.is_file() or path.is_symlink():
            continue
        day = match.group(1)
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            userid = raw.strip()
            if valid_userid(userid) and (userid not in created or day < created[userid]):
                created[userid] = day
    return created


def safe_files(paths: Iterable[Path], root: Path) -> Iterable[Path]:
    resolved_root = root.resolve()
    for path in sorted(set(paths)):
        if path.is_symlink() or not path.is_file():
            continue
        try:
            path.resolve().relative_to(resolved_root)
        except ValueError:
            continue
        yield path


def scan_conversion_logs(
    log_root: Path,
    evidence: list[Evidence],
    bursts: Counter[tuple[str, str, str]],
    conversion_totals: Counter[str],
) -> int:
    parsed = 0
    fee_root = log_root / "fee_log"
    for path in safe_files(fee_root.glob("yushi_change-*.log"), log_root):
        relative = str(path.relative_to(log_root))
        with path.open(encoding="utf-8", errors="replace") as stream:
            for line_number, line in enumerate(stream, 1):
                occurred_on = ""
                try:
                    occurred_on = dt.datetime.strptime(
                        line[:24].strip(), "%a %b %d %H:%M:%S %Y"
                    ).date().isoformat()
                except ValueError:
                    pass
                structured = parse_structured_conversion(line)
                if structured:
                    userid, amount = structured
                    evidence.append(
                        Evidence(
                            userid,
                            amount,
                            "structured_conversion",
                            line_fingerprint(relative, line_number, line),
                            occurred_on,
                        )
                    )
                    parsed += 1
                    continue

                user_match = LEGACY_USER.search(line)
                if not user_match or not valid_userid(user_match.group(1)):
                    continue
                userid = user_match.group(1)
                action = "combine" if "合成为了" in line else "split"
                stamp_match = re.match(r"^(.{10}\s\d\d:\d\d:\d\d)", line)
                stamp = stamp_match.group(1) if stamp_match else line[:24]
                bursts[(userid, stamp, action)] += 1
                conversion_totals[userid] += 1
                for route, pattern in (
                    ("legacy_combine", LEGACY_COMBINE),
                    ("legacy_split", LEGACY_SPLIT),
                ):
                    for match in pattern.finditer(line):
                        source_count, source, target_count, target = match.groups()
                        actual_source_count = int(source_count)
                        evidence_route = route
                        # The historical split implementation logged the
                        # intended two-item removal for a 20-item remainder,
                        # but actually removed only one source item.  A
                        # successful ``2 -> 20`` segment therefore proves an
                        # exact mint even though the legacy text looks value
                        # conserving.  Structured events were introduced with
                        # the fixed transaction and never enter this branch.
                        if (
                            route == "legacy_split"
                            and int(source_count) == 2
                            and int(target_count) == 20
                        ):
                            actual_source_count = 1
                            evidence_route = "legacy_split_remainder_bug"
                        minted = (
                            int(target_count) * JADE_VALUES[target]
                            - actual_source_count * JADE_VALUES[source]
                        )
                        if minted > 0:
                            evidence.append(
                                Evidence(
                                    userid,
                                    minted,
                                    evidence_route,
                                    line_fingerprint(relative, line_number, line),
                                    occurred_on,
                                )
                            )
                        parsed += 1
    return parsed


def scan_consume_logs(log_root: Path, evidence: list[Evidence]) -> int:
    parsed = 0
    ownership: dict[tuple[str, str], tuple[int, str]] = {}
    consume_root = log_root / "stat" / "consume"
    paths = consume_root.glob("*_consume_*.log") if consume_root.is_dir() else ()
    for path in safe_files(paths, log_root):
        relative = str(path.relative_to(log_root))
        with path.open(encoding="utf-8", errors="replace") as stream:
            for line_number, line in enumerate(stream, 1):
                match = CONSUME.match(line)
                if not match:
                    continue
                _, _, userid, route, item, item_cn, count, cost, _ = match.groups()
                if not valid_userid(userid):
                    continue
                count_i = int(count)
                cost_i = int(cost)
                fingerprint = line_fingerprint(relative, line_number, line)
                if route in DIRECT_GRANT_TYPES:
                    denomination = jade_key(item)
                    if denomination:
                        minted = count_i * JADE_VALUES[denomination] - max(0, cost_i)
                        if minted > 0:
                            evidence.append(
                                Evidence(userid, minted, f"consume_{route}", fingerprint)
                            )
                    parsed += 1
                elif route == "home_functionroom":
                    room = ROOM_CN_TO_KEY.get(item) or ROOM_CN_TO_KEY.get(item_cn)
                    if room:
                        ownership[(userid, room)] = (cost_i, fingerprint)
                        parsed += 1
                elif route == "home_sell" and item in ROOM_PRICES:
                    payout = -cost_i
                    prior = ownership.pop((userid, item), None)
                    # A matched purchase proves the complete round-trip profit.
                    # Without one, only refund above the authoritative entitlement
                    # is indisputably illicit.
                    minted = (
                        max(0, payout - prior[0])
                        if prior is not None
                        else max(0, payout - ROOM_REFUNDS[item])
                    )
                    if minted > 0:
                        evidence.append(
                            Evidence(userid, minted, "home_function_room", fingerprint)
                        )
                    parsed += 1
    return parsed


def scan_vip_free_log(log_root: Path, evidence: list[Evidence]) -> int:
    path = log_root / "get_vip_free_item.log"
    if not path.is_file() or path.is_symlink():
        return 0
    parsed = 0
    relative = str(path.relative_to(log_root))
    with path.open(encoding="utf-8", errors="replace") as stream:
        for line_number, line in enumerate(stream, 1):
            event_match = VIP_FREE_EVENT.search(line)
            if not event_match or not valid_userid(event_match.group(1)):
                continue
            # Only the final item-id field is authoritative.  Searching the
            # whole line would misclassify a normal grant when a character id
            # happened to equal a jade denomination.
            denomination = jade_key(event_match.group(2))
            if not denomination:
                continue
            evidence.append(
                Evidence(
                    event_match.group(1),
                    JADE_VALUES[denomination],
                    "vip_free_direct_jade",
                    line_fingerprint(relative, line_number, line),
                )
            )
            parsed += 1
    return parsed


def manifest_for(
    evidence: list[Evidence],
    created: dict[str, str],
    created_before: str,
    bursts: Counter[tuple[str, str, str]],
    conversion_totals: Counter[str],
    financial: dict[str, FinancialSnapshot] | None = None,
) -> dict[str, object]:
    financial = financial or {}
    cutoff_compact = created_before.replace("-", "")
    by_user: dict[str, list[Evidence]] = defaultdict(list)
    for event in evidence:
        by_user[event.userid].append(event)

    accounts: dict[str, object] = {}
    review_only: dict[str, object] = {}
    excluded = Counter()
    for userid in sorted(set(by_user) | set(financial)):
        registered = created.get(userid, "")
        creation_proof = "registration_log"
        if not registered:
            evidence_dates = sorted(
                event.occurred_on.replace("-", "")
                for event in by_user.get(userid, [])
                if event.occurred_on
            )
            if evidence_dates:
                # An authenticated account action is an upper bound on account
                # creation even when the much older registration file is gone.
                registered = evidence_dates[0]
                creation_proof = "earliest_evidence_event"
            else:
                excluded["creation_unknown"] += 1
                continue
        if registered >= cutoff_compact:
            excluded["created_after_cutoff"] += 1
            continue
        events = by_user.get(userid, [])
        exact_minted = sum(event.amount for event in events)
        snapshot = financial.get(userid)
        if snapshot is None:
            if exact_minted > 0:
                review_only[userid] = {
                    "userid": userid,
                    "reason": "exact_mint_missing_balance_snapshot",
                    "registered_on": (
                        f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                    ),
                    "exact_minted_suiyu": exact_minted,
                    "executable": False,
                }
            continue

        if int(time.time()) > snapshot.captured_at + SNAPSHOT_TTL_SECONDS:
            if exact_minted > 0 or snapshot.current_physical_suiyu > 0:
                review_only[userid] = {
                    "userid": userid,
                    "reason": "financial_snapshot_expired",
                    "registered_on": (
                        f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                    ),
                    "executable": False,
                }
            continue

        current_total = (
            snapshot.current_physical_suiyu
            + snapshot.current_personal_storage_suiyu
            + snapshot.current_shared_source_suiyu
        )
        fee_allowance = snapshot.all_fee * FEE_TO_SUIYU
        legal_allowance = fee_allowance + snapshot.legal_non_all_fee_suiyu
        fee_gap = max(0, current_total - legal_allowance)
        if snapshot.current_shared_source_suiyu > 0:
            review_only[userid] = {
                "userid": userid,
                "reason": "shared_storage_jade_requires_manual_isolation",
                "registered_on": (
                    f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                ),
                "exact_minted_suiyu": exact_minted,
                "executable": False,
            }
            continue
        if not snapshot.legal_ledger_complete and exact_minted <= 0:
            if exact_minted > 0 or fee_gap > 0:
                review_only[userid] = {
                    "userid": userid,
                    "reason": "fee_gap_legal_ledger_incomplete",
                    "registered_on": (
                        f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                    ),
                    "current_physical_suiyu": snapshot.current_physical_suiyu,
                    "all_fee": snapshot.all_fee,
                    "fee_allowance_suiyu": fee_allowance,
                    "unreviewed_gap_suiyu": fee_gap,
                    "exact_minted_suiyu": exact_minted,
                    "executable": False,
                }
            continue

        recoverable = fee_gap if exact_minted <= 0 else min(exact_minted, fee_gap)
        if recoverable <= 0:
            if exact_minted > 0:
                review_only[userid] = {
                    "userid": userid,
                    "reason": "exact_mint_has_no_proven_remaining_balance",
                    "registered_on": (
                        f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                    ),
                    "exact_minted_suiyu": exact_minted,
                    "executable": False,
                }
            continue
        if recoverable > RUNTIME_MAX_RECOVERY:
            review_only[userid] = {
                "userid": userid,
                "reason": "proven_amount_exceeds_runtime_safety_limit",
                "registered_on": (
                    f"{registered[:4]}-{registered[4:6]}-{registered[6:]}"
                ),
                "proven_suiyu": recoverable,
                "runtime_limit_suiyu": RUNTIME_MAX_RECOVERY,
                "executable": False,
            }
            continue

        fingerprints = [event.fingerprint for event in events]
        fingerprints.append(snapshot.fingerprint)
        evidence_digest = hashlib.sha256(
            "\n".join(sorted(fingerprints)).encode("ascii")
        ).hexdigest()
        case_id = "jade-" + hashlib.sha256(
            f"{userid}|{recoverable}|{evidence_digest}".encode("utf-8")
        ).hexdigest()[:32]
        routes = Counter(event.route for event in events)
        if not events:
            routes["complete_fee_balance_ledger"] = 1
        accounts[userid] = {
            "userid": userid,
            "case_id": case_id,
            "proven_suiyu": recoverable,
            "registered_on": f"{registered[:4]}-{registered[4:6]}-{registered[6:]}",
            "creation_proof": creation_proof,
            "evidence_sha256": evidence_digest,
            "balance_snapshot_sha256": snapshot.fingerprint,
            "balance_captured_at": snapshot.captured_at,
            "snapshot_expires_at": snapshot.captured_at + SNAPSHOT_TTL_SECONDS,
            "captured_physical_suiyu": snapshot.current_physical_suiyu,
            "captured_personal_storage_suiyu": (
                snapshot.current_personal_storage_suiyu
            ),
            "captured_shared_source_suiyu": snapshot.current_shared_source_suiyu,
            "captured_wallet_suiyu": snapshot.current_wallet_suiyu,
            "all_fee": snapshot.all_fee,
            "fee_allowance_suiyu": fee_allowance,
            "legal_non_all_fee_suiyu": snapshot.legal_non_all_fee_suiyu,
            "legal_ledger_complete": True,
            "unexplained_remaining_suiyu": fee_gap,
            "exact_minted_suiyu": exact_minted,
            "event_count": len(events),
            "routes": dict(sorted(routes.items())),
            "approved": False,
        }

    burst_users = {
        userid
        for (userid, _, _), count in bursts.items()
        if count >= 3
        and created.get(userid, "")
        and created[userid] < cutoff_compact
        and userid not in accounts
    }
    for userid in sorted(burst_users):
        if userid in review_only:
            continue
        review_only[userid] = {
            "userid": userid,
            "reason": "conversion_frequency_only_no_proven_mint",
            "registered_on": (
                f"{created[userid][:4]}-{created[userid][4:6]}-{created[userid][6:]}"
            ),
            "conversion_events": conversion_totals[userid],
            "max_same_second": max(
                count
                for (one_user, _, _), count in bursts.items()
                if one_user == userid
            ),
            "executable": False,
        }
    return {
        "schema_version": SCHEMA_VERSION,
        "enabled": False,
        "state": "review",
        "policy": "one_time_current_physical_only_no_future_debt",
        "created_before": created_before,
        "generated_at": int(time.time()),
        "accounts": accounts,
        "review_only": review_only,
        "summary": {
            "proven_accounts": len(accounts),
            "proven_suiyu": sum(
                int(entry["proven_suiyu"]) for entry in accounts.values()
            ),
            "review_only_accounts": len(review_only),
            "excluded": dict(sorted(excluded.items())),
        },
    }


def write_private_json(path: Path, value: dict[str, object]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    encoded = (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode(
        "utf-8"
    )
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


def approve_exact_split_evidence(manifest: dict[str, object]) -> int:
    """Approve only cases whose entire exact amount is the known split bug."""

    accounts = manifest.get("accounts", {})
    if not isinstance(accounts, dict):
        return 0
    approved_count = 0
    for row in accounts.values():
        if not isinstance(row, dict):
            continue
        routes = row.get("routes", {})
        exact = int(row.get("exact_minted_suiyu", 0))
        proven = int(row.get("proven_suiyu", 0))
        if (
            isinstance(routes, dict)
            and set(routes) == {"legacy_split_remainder_bug"}
            and int(routes.get("legacy_split_remainder_bug", 0)) > 0
            and exact >= proven > 0
        ):
            row["approved"] = True
            approved_count += 1
    manifest["enabled"] = approved_count > 0
    manifest["state"] = "approved" if approved_count > 0 else "review"
    summary = manifest.get("summary", {})
    if isinstance(summary, dict):
        summary["approved_accounts"] = approved_count
    return approved_count


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-root", required=True, type=Path)
    parser.add_argument("--registration-root", required=True, type=Path)
    parser.add_argument("--created-before", default="2026-08-01")
    parser.add_argument(
        "--financial-snapshot",
        type=Path,
        help=(
            "private JSON snapshot of current physical jade, all_fee and an "
            "reviewed legal-jade allowance not represented by all_fee"
        ),
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--approve-exact-evidence",
        action="store_true",
        help=(
            "enable only rows proven by the historical two-item split bug; "
            "all other candidates remain unapproved"
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        dt.date.fromisoformat(args.created_before)
    except ValueError:
        print("ERROR: --created-before must be YYYY-MM-DD", file=sys.stderr)
        return 2
    if not args.log_root.is_dir():
        print("ERROR: log root does not exist", file=sys.stderr)
        return 2

    evidence: list[Evidence] = []
    bursts: Counter[tuple[str, str, str]] = Counter()
    conversion_totals: Counter[str] = Counter()
    parsed_conversion = scan_conversion_logs(
        args.log_root, evidence, bursts, conversion_totals
    )
    parsed_consume = scan_consume_logs(args.log_root, evidence)
    parsed_vip = scan_vip_free_log(args.log_root, evidence)
    created = registration_dates(args.registration_root)
    try:
        financial = load_financial_snapshot(args.financial_snapshot)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: invalid financial snapshot: {exc}", file=sys.stderr)
        return 2
    manifest = manifest_for(
        evidence,
        created,
        args.created_before,
        bursts,
        conversion_totals,
        financial,
    )
    approved_count = 0
    if args.approve_exact_evidence:
        approved_count = approve_exact_split_evidence(manifest)
    write_private_json(args.output, manifest)

    summary = manifest["summary"]
    assert isinstance(summary, dict)
    print(
        "audit complete: "
        f"conversion_events={parsed_conversion} consume_events={parsed_consume} "
        f"vip_direct_events={parsed_vip} proven_accounts={summary['proven_accounts']} "
        f"review_only_accounts={summary['review_only_accounts']} "
        f"approved_accounts={approved_count} output={args.output} mode=0600 "
        f"enabled={str(bool(manifest['enabled'])).lower()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
