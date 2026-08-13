#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "snapshot_illicit_jade_candidates",
    ROOT / "scripts" / "snapshot_illicit_jade_candidates.py",
)
assert SPEC and SPEC.loader
SNAPSHOT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SNAPSHOT
SPEC.loader.exec_module(SNAPSHOT)


class IllicitJadeSnapshotTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_only_candidates_are_read_and_all_holdings_are_counted(self):
        userid = "oldabuser"
        user_path = self.root / "u" / userid[-2:] / f"{userid}.o"
        user_path.parent.mkdir(parents=True)
        user_path.write_text(
            'all_fee 12\naccount_owner "oldaccount"\n'
            'inventory_data ({"#~/gamelib/clone/item/yushi/suiyu\\n'
            'amount 7\\n",})\n'
            'packaged_items ({({"suiyu","碎玉","(9)块碎玉",'
            '"yushi/suiyu",0,0,9,"' + "a" * 64 + '"}),})\n',
            encoding="utf-8",
        )
        account_dir = self.root / "accounts" / "nt"
        account_dir.mkdir(parents=True)
        (account_dir / "oldaccount.wallet.json").write_text(
            json.dumps({"balance": 3, "total_recharge_fee": 20}),
            encoding="utf-8",
        )
        (account_dir / "oldaccount.storage.json").write_text(
            json.dumps(
                {
                    "items": [
                        {
                            "source_character": userid,
                            "data": ["suiyu", "碎玉", "(4)块碎玉", "yushi/suiyu", 0, 0, 4],
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        manifest = {
            "schema_version": 2,
            "accounts": {},
            "review_only": {userid: {"exact_minted_suiyu": 100}},
        }

        result = SNAPSHOT.build_snapshot(self.root, manifest)

        row = result["accounts"][userid]
        self.assertEqual(row["current_physical_suiyu"], 7)
        self.assertEqual(row["current_personal_storage_suiyu"], 9)
        self.assertEqual(row["current_shared_source_suiyu"], 4)
        self.assertEqual(row["current_wallet_suiyu"], 3)
        self.assertEqual(row["all_fee"], 20)
        self.assertFalse(row["legal_ledger_complete"])

    def test_invalid_or_missing_candidate_is_aggregate_only(self):
        manifest = {
            "schema_version": 2,
            "accounts": {},
            "review_only": {"missinguser": {"exact_minted_suiyu": 1}},
        }

        result = SNAPSHOT.build_snapshot(self.root, manifest)

        self.assertEqual(result["accounts"], {})
        self.assertEqual(result["summary"]["missing_player"], 1)


if __name__ == "__main__":
    unittest.main()
