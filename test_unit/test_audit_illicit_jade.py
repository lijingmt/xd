#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "audit_illicit_jade", ROOT / "scripts" / "audit_illicit_jade.py"
)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


class IllicitJadeAuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.log_root = self.root / "log"
        self.registration_root = self.root / "new_users"
        (self.log_root / "fee_log").mkdir(parents=True)
        (self.log_root / "stat" / "consume").mkdir(parents=True)
        self.registration_root.mkdir(parents=True)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, relative: str, source: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")

    def financial_row(
        self,
        physical: int,
        all_fee: int = 0,
        legal: int = 0,
        complete: bool = True,
    ):
        return AUDIT.FinancialSnapshot(
            current_physical_suiyu=physical,
            current_personal_storage_suiyu=0,
            current_shared_source_suiyu=0,
            current_wallet_suiyu=0,
            all_fee=all_fee,
            legal_non_all_fee_suiyu=legal,
            legal_ledger_complete=complete,
            captured_at=int(AUDIT.time.time()),
            fingerprint="b" * 64,
        )

    def build_manifest(self, financial=None):
        evidence = []
        bursts = AUDIT.Counter()
        totals = AUDIT.Counter()
        AUDIT.scan_conversion_logs(self.log_root, evidence, bursts, totals)
        AUDIT.scan_consume_logs(self.log_root, evidence)
        AUDIT.scan_vip_free_log(self.log_root, evidence)
        created = AUDIT.registration_dates(self.registration_root)
        return AUDIT.manifest_for(
            evidence, created, "2026-08-01", bursts, totals, financial
        )

    def test_only_exact_old_account_evidence_becomes_executable_candidate(self):
        self.write(
            "new_users/xd.20260601.txt",
            "oldabuser\nreviewonly\n",
        )
        self.write("new_users/xd.20260802.txt", "newabuser\n")
        conversion = (
            "Thu Jun  4 12:00:00 2026:甲(oldabuser) 将 (10)suiyu "
            "合成为了 (1)xuantianbaoyu\n"
            "Thu Jun  4 12:00:01 2026:乙(newabuser) 将 (10)suiyu "
            "合成为了 (1)xuantianbaoyu\n"
            "Thu Jun  4 12:00:02 2026:甲(oldabuser) 将 (10)suiyu "
            "合成为了 (1)xianyuanyu\n"
        )
        self.write("log/fee_log/yushi_change-2026-06.log", conversion)
        consume = (
            "[2026-06-04 12:00:03]-[xd][oldabuser][baoshi]"
            "[xuantianbaoyu][【玉】玄天宝玉][2][0][0]\n"
        )
        self.write("log/stat/consume/xd_consume_2026-06-04.log", consume)

        manifest = self.build_manifest(
            {
                "oldabuser": self.financial_row(30_000),
                "newabuser": self.financial_row(30_000),
            }
        )

        self.assertFalse(manifest["enabled"])
        self.assertEqual(manifest["state"], "review")
        self.assertEqual(set(manifest["accounts"]), {"oldabuser"})
        # 9,990 from the forged conversion and 20,000 from the direct grant.
        self.assertEqual(
            manifest["accounts"]["oldabuser"]["proven_suiyu"], 29_990
        )
        self.assertFalse(manifest["accounts"]["oldabuser"]["approved"])
        self.assertEqual(
            manifest["summary"]["excluded"], {"created_after_cutoff": 1}
        )

    def test_frequency_is_review_only_and_never_supplies_an_amount(self):
        self.write("new_users/xd.20260601.txt", "reviewonly\n")
        line = (
            "Thu Jun  4 12:00:00 2026:甲(reviewonly) 将 (10)suiyu "
            "合成为了 (1)xianyuanyu\n"
        )
        self.write("log/fee_log/yushi_change-2026-06.log", line * 3)

        manifest = self.build_manifest()

        self.assertEqual(manifest["accounts"], {})
        self.assertEqual(set(manifest["review_only"]), {"reviewonly"})
        review = manifest["review_only"]["reviewonly"]
        self.assertFalse(review["executable"])
        self.assertNotIn("proven_suiyu", review)

    def test_home_round_trip_recovers_only_proven_profit(self):
        self.write("new_users/xd.20260601.txt", "homeabuser\n")
        consume = (
            "[2026-06-04 12:00:00]-[xd][homeabuser][home_functionroom]"
            "[力道小筑][力道小筑][1][0][0]\n"
            "[2026-06-04 12:00:01]-[xd][homeabuser][home_sell]"
            "[lidaoxiaozhu][][1][-40][0]\n"
        )
        self.write("log/stat/consume/xd_consume_2026-06-04.log", consume)

        manifest = self.build_manifest(
            {"homeabuser": self.financial_row(40)}
        )

        self.assertEqual(
            manifest["accounts"]["homeabuser"]["proven_suiyu"], 40
        )

    def test_legacy_two_item_split_recovers_the_hidden_remainder_mint(self):
        self.write("new_users/xd.20260601.txt", "splitabuser\n")
        self.write(
            "log/fee_log/yushi_change-2026-06.log",
            "Thu Jun  4 12:00:00 2026:甲(splitabuser) "
            "打算打碎(2)linglongyu,结果为: "
            "将(2)linglongyu打碎获得(20)xianyuanyu,\n"
            "Thu Jun  4 12:00:01 2026:甲(splitabuser) "
            "打算打碎(1)linglongyu,结果为: "
            "将(1)linglongyu打碎获得(10)xianyuanyu,\n",
        )

        manifest = self.build_manifest(
            {"splitabuser": self.financial_row(100)}
        )

        # The old command claimed two source items in its log, but its
        # remainder branch removed only one.  The first line therefore minted
        # exactly 10 xianyuanyu (100 suiyu); the one-item split was correct.
        entry = manifest["accounts"]["splitabuser"]
        self.assertEqual(entry["proven_suiyu"], 100)
        self.assertEqual(entry["routes"], {"legacy_split_remainder_bug": 1})

    def test_old_evidence_event_proves_creation_when_registration_log_is_gone(self):
        self.write(
            "log/fee_log/yushi_change-2026-06.log",
            "Thu Jun  4 12:00:00 2026:甲(oldnolog) "
            "打算打碎(2)linglongyu,结果为: "
            "将(2)linglongyu打碎获得(20)xianyuanyu,\n",
        )

        manifest = self.build_manifest({"oldnolog": self.financial_row(100)})

        entry = manifest["accounts"]["oldnolog"]
        self.assertEqual(entry["registered_on"], "2026-06-04")
        self.assertEqual(entry["creation_proof"], "earliest_evidence_event")

    def test_vip_free_parser_uses_item_field_not_character_id(self):
        self.write("new_users/xd.20260601.txt", "suiyu\nvipabuser\n")
        self.write(
            "log/get_vip_free_item.log",
            "甲(suiyu)获得免费物品普通药品(putongyao)\n"
            "乙(vipabuser)获得免费物品碎玉(yushi/suiyu)\n",
        )

        manifest = self.build_manifest(
            {"vipabuser": self.financial_row(1)}
        )

        self.assertNotIn("suiyu", manifest["accounts"])
        self.assertEqual(
            manifest["accounts"]["vipabuser"]["proven_suiyu"], 1
        )

    def test_all_fee_gap_requires_complete_non_all_fee_ledger(self):
        self.write(
            "new_users/xd.20260601.txt",
            "completegap\nincompletegap\n",
        )
        financial = {
            # 1,700 - (100 yuan * 10) - 200 reviewed rewards = 500.
            "completegap": self.financial_row(1_700, 100, 200, True),
            "incompletegap": self.financial_row(50_000, 100, 0, False),
        }

        manifest = self.build_manifest(financial)

        self.assertEqual(
            manifest["accounts"]["completegap"]["proven_suiyu"], 500
        )
        self.assertEqual(
            manifest["accounts"]["completegap"]["routes"],
            {"complete_fee_balance_ledger": 1},
        )
        self.assertNotIn("incompletegap", manifest["accounts"])
        self.assertEqual(
            manifest["review_only"]["incompletegap"]["reason"],
            "fee_gap_legal_ledger_incomplete",
        )

    def test_shared_storage_jade_stays_review_only(self):
        self.write("new_users/xd.20260601.txt", "sharedjade\n")
        self.write(
            "log/fee_log/yushi_change-2026-06.log",
            "Thu Jun  4 12:00:00 2026:甲(sharedjade) "
            "打算打碎(2)linglongyu,结果为: "
            "将(2)linglongyu打碎获得(20)xianyuanyu,\n",
        )
        snapshot = self.financial_row(0)
        snapshot = AUDIT.dataclasses.replace(
            snapshot, current_shared_source_suiyu=100
        )

        manifest = self.build_manifest({"sharedjade": snapshot})

        self.assertNotIn("sharedjade", manifest["accounts"])
        self.assertEqual(
            manifest["review_only"]["sharedjade"]["reason"],
            "shared_storage_jade_requires_manual_isolation",
        )

    def test_exact_mint_is_capped_by_proven_remaining_fee_gap(self):
        self.write("new_users/xd.20260601.txt", "partiallyspent\n")
        self.write(
            "log/fee_log/yushi_change-2026-06.log",
            "Thu Jun  4 12:00:00 2026:甲(partiallyspent) 将 (10)suiyu "
            "合成为了 (1)xuantianbaoyu\n",
        )

        manifest = self.build_manifest(
            {"partiallyspent": self.financial_row(1_500, 100, 0, True)}
        )

        # Exact mint was 9,990, but only 500 remains above the conservative
        # recharge allowance, so already-spent jade is forgiven.
        self.assertEqual(
            manifest["accounts"]["partiallyspent"]["proven_suiyu"], 500
        )

    def test_snapshot_parser_rejects_incomplete_or_boolean_amounts(self):
        snapshot = self.root / "financial.json"
        snapshot.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "captured_at": int(AUDIT.time.time()),
                    "accounts": {
                        "validuser": {
                            "current_physical_suiyu": 100,
                            "current_personal_storage_suiyu": 0,
                            "current_shared_source_suiyu": 0,
                            "current_wallet_suiyu": 0,
                            "all_fee": 5,
                            "legal_non_all_fee_suiyu": 10,
                            "legal_ledger_complete": True,
                        }
                    },
                }
            ),
            encoding="utf-8",
        )
        parsed = AUDIT.load_financial_snapshot(snapshot)
        self.assertEqual(parsed["validuser"].all_fee, 5)

        broken = json.loads(snapshot.read_text(encoding="utf-8"))
        broken["accounts"]["validuser"]["all_fee"] = True
        snapshot.write_text(json.dumps(broken), encoding="utf-8")
        with self.assertRaises(ValueError):
            AUDIT.load_financial_snapshot(snapshot)

        broken["schema_version"] = True
        broken["accounts"]["validuser"]["all_fee"] = 5
        snapshot.write_text(json.dumps(broken), encoding="utf-8")
        with self.assertRaises(ValueError):
            AUDIT.load_financial_snapshot(snapshot)

    def test_cli_output_is_private_and_disabled(self):
        self.write("new_users/xd.20260601.txt", "normaluser\n")
        output = self.root / "security" / "manifest.json"
        result = AUDIT.main(
            [
                "--log-root",
                str(self.log_root),
                "--registration-root",
                str(self.registration_root),
                "--created-before",
                "2026-08-01",
                "--output",
                str(output),
            ]
        )
        self.assertEqual(result, 0)
        decoded = json.loads(output.read_text(encoding="utf-8"))
        self.assertFalse(decoded["enabled"])
        self.assertEqual(decoded["accounts"], {})
        self.assertEqual(os.stat(output).st_mode & 0o777, 0o600)

    def test_explicit_auto_approval_only_accepts_exact_split_bug(self):
        self.write("new_users/xd.20260601.txt", "splitapprove\n")
        self.write(
            "log/fee_log/yushi_change-2026-06.log",
            "Thu Jun  4 12:00:00 2026:甲(splitapprove) "
            "打算打碎(2)linglongyu,结果为: "
            "将(2)linglongyu打碎获得(20)xianyuanyu,\n",
        )
        snapshot = self.root / "financial.json"
        snapshot.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "captured_at": int(AUDIT.time.time()),
                    "accounts": {
                        "splitapprove": {
                            "current_physical_suiyu": 100,
                            "current_personal_storage_suiyu": 0,
                            "current_shared_source_suiyu": 0,
                            "current_wallet_suiyu": 0,
                            "all_fee": 0,
                            "legal_non_all_fee_suiyu": 0,
                            "legal_ledger_complete": False,
                        }
                    },
                }
            ),
            encoding="utf-8",
        )
        output = self.root / "security" / "approved.json"

        result = AUDIT.main(
            [
                "--log-root",
                str(self.log_root),
                "--registration-root",
                str(self.registration_root),
                "--financial-snapshot",
                str(snapshot),
                "--approve-exact-evidence",
                "--output",
                str(output),
            ]
        )

        self.assertEqual(result, 0)
        decoded = json.loads(output.read_text(encoding="utf-8"))
        self.assertTrue(decoded["enabled"])
        self.assertEqual(decoded["state"], "approved")
        self.assertTrue(decoded["accounts"]["splitapprove"]["approved"])
        self.assertEqual(decoded["summary"]["approved_accounts"], 1)

    def test_auto_approval_rejects_mixed_evidence_routes(self):
        manifest = {
            "enabled": False,
            "state": "review",
            "accounts": {
                "mixeduser": {
                    "routes": {
                        "legacy_split_remainder_bug": 1,
                        "consume_baoshi": 1,
                    },
                    "exact_minted_suiyu": 100,
                    "proven_suiyu": 100,
                    "approved": False,
                }
            },
            "summary": {},
        }

        approved = AUDIT.approve_exact_split_evidence(manifest)

        self.assertEqual(approved, 0)
        self.assertFalse(manifest["enabled"])
        self.assertFalse(manifest["accounts"]["mixeduser"]["approved"])


if __name__ == "__main__":
    unittest.main()
