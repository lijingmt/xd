import json
import os
import tempfile
import threading
import time
import unittest
import urllib.parse
from unittest import mock

import gateway


class Headers(dict):
    def get(self, key, default=None):
        for existing, value in self.items():
            if existing.lower() == key.lower():
                return value
        return default


class RepeatedHeaders(Headers):
    def __init__(self, values):
        super().__init__()
        self.values = values

    def get_all(self, key):
        return self.values if key.lower() == "content-length" else None


def encode_legacy_txd(userid: str, password: str = "secret") -> str:
    encoded_user = "".join(
        chr(ord(character) + (2 if index // 2 == 0 else 1))
        for index, character in enumerate(userid)
    )
    encoded_password = "".join(
        chr(ord(character) + (1 if index // 2 == 0 else 2))
        for index, character in enumerate(password)
    )
    return encoded_user + "~" + encoded_password


class GatewayParsingTests(unittest.TestCase):

    def test_only_one_gateway_process_can_claim_a_topology(self):
        with tempfile.TemporaryDirectory() as directory:
            lock_path = os.path.join(directory, "controller.lock")
            pid_path = os.path.join(directory, "gateway.pid")
            first = gateway.GatewayProcessClaim(lock_path, pid_path)
            try:
                with self.assertRaises(RuntimeError):
                    gateway.GatewayProcessClaim(lock_path, pid_path)
                with self.assertRaises(RuntimeError):
                    gateway.GatewayProcessClaim(lock_path, pid_path)
                with open(pid_path, encoding="ascii") as handle:
                    self.assertEqual(handle.read(), str(os.getpid()))
            finally:
                first.close()
            self.assertFalse(os.path.exists(pid_path))

    def test_gateway_server_has_a_fixed_request_thread_limit(self):
        server = gateway.BoundedThreadingHTTPServer(
            ("127.0.0.1", 0), gateway.GatewayHandler, 8
        )
        try:
            for _index in range(8):
                self.assertTrue(server._request_slots.acquire(blocking=False))
            self.assertFalse(server._request_slots.acquire(blocking=False))
            for _index in range(8):
                server._request_slots.release()
        finally:
            server.server_close()

    def test_gateway_applies_client_socket_deadline_before_threading(self):
        server = gateway.BoundedThreadingHTTPServer(
            ("127.0.0.1", 0), gateway.GatewayHandler, 8, 17
        )
        request = mock.Mock()
        server._request_slots.acquire = mock.Mock(return_value=False)
        try:
            server.process_request(request, ("127.0.0.1", 12345))
            request.settimeout.assert_called_once_with(17)
        finally:
            server.server_close()

    def test_head_uses_the_same_fenced_proxy_path_without_a_body(self):
        handler = object.__new__(gateway.GatewayHandler)
        handler._handle = mock.Mock()
        handler.do_HEAD()
        handler._handle.assert_called_once_with()

    def test_worker_endpoints_are_loopback_only(self):
        parsed = gateway.parse_worker_endpoints(
            "w01=http://127.0.0.1:18881,w02=http://localhost:18882"
        )
        self.assertEqual(parsed["w01"], "http://127.0.0.1:18881")
        with self.assertRaises(SystemExit):
            gateway.parse_worker_endpoints("w01=http://192.168.1.205:18881")

    def test_invalid_internal_rpc_json_is_a_controlled_routing_failure(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b"{truncated"
        response.__exit__.return_value = False
        coordinator = gateway.CoordinatorClient(
            "http://127.0.0.1:18880", "x" * 32, 5
        )
        with mock.patch("gateway.urllib.request.urlopen", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "coordinator unavailable"):
                coordinator.call("status")

        pool = gateway.WorkerPool(
            {"w01": "http://127.0.0.1:18881"}, coordinator, "x" * 32, 5
        )
        with mock.patch("gateway.urllib.request.urlopen", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "worker w01 unavailable"):
                pool._worker_call("w01", "local_status")

    def test_legacy_txd_userid_route_is_compatible(self):
        token = encode_legacy_txd("xd01player")
        self.assertEqual(gateway.decode_txd_userid(token), "xd01player")
        path = "/api/json?txd=" + urllib.parse.quote_plus(token) + "&cmd=look"
        self.assertEqual(gateway.extract_userid(path, Headers(), b""), "xd01player")

    def test_plain_json_and_form_userids_route_identically(self):
        json_headers = Headers({"Content-Type": "application/json"})
        form_headers = Headers(
            {"Content-Type": "application/x-www-form-urlencoded"}
        )
        self.assertEqual(
            gateway.extract_userid(
                "/api", json_headers, json.dumps({"userid": "XD01Player"}).encode()
            ),
            "xd01player",
        )
        account_token = "a" * 64
        self.assertEqual(
            gateway.extract_account_token(
                "/api/account/characters",
                json_headers,
                json.dumps({"token": account_token}).encode(),
            ),
            account_token,
        )
        self.assertEqual(
            gateway.extract_account_id(
                "/api/account/characters/select",
                json_headers,
                json.dumps({"account_id": "XD01Account"}).encode(),
            ),
            "xd01account",
        )
        self.assertEqual(
            gateway.extract_userid(
                "/api", form_headers, b"userid=XD01Player&cmd=look"
            ),
            "xd01player",
        )

    def test_conflicting_valid_identity_fields_are_rejected(self):
        txd = urllib.parse.quote_plus(encode_legacy_txd("xd01second"))
        with self.assertRaisesRegex(ValueError, "conflicting"):
            gateway.extract_userid(
                f"/api/json?userid=xd01first&txd={txd}", Headers(), b""
            )
        self.assertEqual(
            gateway.extract_userid(
                f"/api/json?userid=xd01second&txd={txd}", Headers(), b""
            ),
            "xd01second",
        )
        self.assertTrue(
            gateway.account_identity_matches("xd01account", "xd01account")
        )
        self.assertFalse(
            gateway.account_identity_matches("xd01account", "xd01other")
        )

    def test_invalid_or_oversized_identity_is_not_routed(self):
        self.assertEqual(
            gateway.extract_userid("/api?userid=../admin", Headers(), b""), ""
        )
        self.assertEqual(
            gateway.extract_userid("/api?userid=" + "a" * 65, Headers(), b""), ""
        )
        self.assertEqual(
            gateway.extract_userid("/api?userid=玩家01", Headers(), b""), ""
        )

    def test_parameter_limits_do_not_accept_unbounded_query_fields(self):
        query = "&".join(f"k{index}=v" for index in range(200))
        with self.assertRaises(ValueError):
            gateway.extract_params("/api?" + query, Headers(), b"")

    def test_ambiguous_http_request_framing_is_rejected(self):
        self.assertEqual(gateway.request_content_length(Headers()), 0)
        self.assertEqual(
            gateway.request_content_length(Headers({"Content-Length": "12"})),
            12,
        )
        with self.assertRaises(ValueError):
            gateway.request_content_length(
                Headers({"Transfer-Encoding": "chunked"})
            )
        with self.assertRaises(ValueError):
            gateway.request_content_length(RepeatedHeaders(["1", "2"]))
        with self.assertRaises(ValueError):
            gateway.request_content_length(
                Headers({"Content-Length": str(gateway.MAX_BODY_BYTES + 1)})
            )

    def test_worker_response_does_not_duplicate_gateway_owned_headers(self):
        self.assertFalse(gateway.response_header_allowed("Server"))
        self.assertFalse(gateway.response_header_allowed("Date"))
        self.assertFalse(gateway.response_header_allowed("X-Xiand-Request-Id"))
        self.assertFalse(gateway.response_header_allowed("Connection"))
        self.assertTrue(gateway.response_header_allowed("Content-Type"))

    def test_env_int_rejects_out_of_range_values(self):
        original = gateway.os.environ.get("TEST_MAP_GATEWAY_INT")
        try:
            gateway.os.environ["TEST_MAP_GATEWAY_INT"] = "70000"
            with self.assertRaises(SystemExit):
                gateway.env_int("TEST_MAP_GATEWAY_INT", 8888, 1024, 65535)
        finally:
            if original is None:
                gateway.os.environ.pop("TEST_MAP_GATEWAY_INT", None)
            else:
                gateway.os.environ["TEST_MAP_GATEWAY_INT"] = original

    def test_public_gateway_never_exposes_internal_rpc(self):
        self.assertFalse(gateway.public_path_allowed("/internal/map-worker"))
        self.assertFalse(gateway.public_path_allowed("/internal/anything?x=1"))
        self.assertTrue(gateway.public_path_allowed("/api/json?cmd=look"))

    def test_account_session_endpoints_are_detected_for_primary_routing(self):
        self.assertTrue(gateway.account_api_path("/api/account/login"))
        self.assertTrue(
            gateway.account_api_path("/api/account/characters/select?x=1")
        )
        self.assertFalse(gateway.account_api_path("/api/json?cmd=look"))

    def test_only_auction_commands_use_cluster_global_command_lock(self):
        headers = Headers({"Content-Type": "application/json"})
        self.assertTrue(gateway.auction_command("vendue_buy_now 7"))
        self.assertTrue(gateway.auction_command("vendue_getback_item 7"))
        self.assertFalse(gateway.auction_command("inventory"))
        self.assertEqual(
            gateway.extract_game_command(
                "/api/json",
                headers,
                json.dumps({"cmd": " VENDUE_BUY_NOW 7 "}).encode(),
            ),
            "vendue_buy_now 7",
        )

    def test_shadow_controller_never_runs_auction_settlement(self):
        with mock.patch.dict(
            gateway.os.environ, {"XIAND_MAP_WORKER_SHADOW": "1"}
        ):
            pool = gateway.WorkerPool(
                {"w01": "http://127.0.0.1:18881"},
                FakeCoordinator(),
                "x" * 32,
                5,
            )
        pool._worker_call = mock.Mock()
        pool._run_auction_scheduler()
        pool._worker_call.assert_not_called()

    def test_direct_active_gateway_requires_isolated_trial_acknowledgement(self):
        with mock.patch.dict(gateway.os.environ, {}, clear=True):
            self.assertFalse(gateway.active_trial_authorized())
        with mock.patch.dict(
            gateway.os.environ,
            {"XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK": "isolated-test-server-only"},
            clear=True,
        ):
            self.assertTrue(gateway.active_trial_authorized())
        with mock.patch.dict(
            gateway.os.environ, {"XIAND_MAP_WORKER_SHADOW": "1"}, clear=True
        ):
            self.assertTrue(gateway.active_trial_authorized())

    def test_migration_delivery_plan_distinguishes_old_and_current_commands(self):
        cross_redirect = (
            "w02", 8, True, "/gamelib/d/target_map/room"
        )
        cross_drift = (
            "w02", 8, False, "/gamelib/d/target_map/room"
        )
        same_redirect = (
            "w01", 7, True, "/gamelib/d/target_map/room"
        )
        self.assertEqual(
            gateway.migration_delivery_plan("w01", cross_redirect, True),
            (True, False),
        )
        self.assertEqual(
            gateway.migration_delivery_plan("w01", same_redirect, True),
            (False, False),
        )
        self.assertEqual(
            gateway.migration_delivery_plan("w01", cross_drift, False),
            (True, False),
        )
        self.assertEqual(
            gateway.migration_delivery_plan("w01", same_redirect, False),
            (True, True),
        )


class FakeCoordinator:
    def __init__(self, responses=None):
        self.responses = responses or {}
        self.calls = []

    def call(self, action, **params):
        self.calls.append((action, params))
        response = self.responses.get(action, {"ok": 1})
        return response(action, params) if callable(response) else dict(response)


class GatewayFencingTests(unittest.TestCase):
    def make_pool(self, coordinator=None):
        return gateway.WorkerPool(
            {
                "w01": "http://127.0.0.1:18881",
                "w02": "http://127.0.0.1:18882",
            },
            coordinator or FakeCoordinator(),
            "x" * 32,
            5,
        )

    def test_same_character_uses_same_bounded_gateway_lock(self):
        pool = self.make_pool()
        self.assertIs(pool.user_lock("xd01player"), pool.user_lock("xd01player"))
        self.assertEqual(len(pool._user_locks), 4096)

    def test_assignment_rpc_distinguishes_destination_from_owner_field(self):
        pool = self.make_pool()
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b'{"ok":1}'
        with mock.patch("gateway.urllib.request.urlopen", return_value=response) \
                as urlopen:
            pool._sync_assignment(
                "wugongdong",
                {
                    "worker_id": "w02",
                    "placement_generation": 8,
                },
            )
        self.assertEqual(urlopen.call_count, 2)
        for call in urlopen.call_args_list:
            payload = json.loads(call.args[0].data)
            self.assertEqual(payload["worker_id"], "w02")
            self.assertEqual(payload["affinity"], "wugongdong")

    def test_only_failed_command_routes_enter_precommand_reconciliation(self):
        pool = self.make_pool()
        self.assertFalse(pool.reconciliation_pending("xd01player"))
        pool.mark_reconciliation_pending("xd01player")
        self.assertTrue(pool.reconciliation_pending("xd01player"))
        pool.clear_reconciliation_pending("xd01player")
        self.assertFalse(pool.reconciliation_pending("xd01player"))

    def test_shared_account_characters_use_one_gateway_transaction_lock(self):
        pool = self.make_pool()
        first = pool.user_lock("xd01char1", "xd01account")
        second = pool.user_lock("xd01char2", "xd01account")
        self.assertIs(first, second)

    def test_account_cache_capability_changes_only_when_worker_changes(self):
        pool = self.make_pool()
        first = pool.account_cache_token("xd01account", "w01")
        same = pool.account_cache_token("xd01account", "w01")
        moved = pool.account_cache_token("xd01account", "w02")
        self.assertEqual(first, same)
        self.assertNotEqual(first, moved)

    def test_successful_account_response_binds_opaque_token_to_owner(self):
        pool = self.make_pool()
        token = "b" * 64
        response = gateway.ProxyResponse(
            200,
            "OK",
            [],
            json.dumps({"token": token, "account_id": "xd01account"}).encode(),
        )
        pool.observe_account_response("/api/account/login", "", response)
        self.assertEqual(pool.account_for_token(token), "xd01account")
        pool.observe_account_response(
            "/api/account/logout", token,
            gateway.ProxyResponse(200, "OK", [], b"{}"),
        )
        self.assertEqual(pool.account_for_token(token), "")

    def test_shared_account_lock_identity_is_resolved_authoritatively(self):
        coordinator = FakeCoordinator(
            {
                "resolve_account": lambda _action, _params: {
                    "ok": 1,
                    "account_id": "xd01account",
                }
            }
        )
        pool = self.make_pool(coordinator)
        first_owner = pool.resolve_account("xd01char1")
        second_owner = pool.resolve_account("xd01char2")
        self.assertEqual(first_owner, "xd01account")
        self.assertEqual(second_owner, "xd01account")
        self.assertIs(
            pool.user_lock("xd01char1"), pool.user_lock("xd01char2")
        )
        pool.resolve_account("xd01char1")
        resolved_users = [
            call[1]["userid"]
            for call in coordinator.calls
            if call[0] == "resolve_account"
        ]
        self.assertEqual(resolved_users, ["xd01char1", "xd01char2"])

    def test_token_only_account_maintenance_waits_for_character_write(self):
        pool = self.make_pool()
        player_lock = pool.user_lock("xd01character")
        player_lock.acquire()
        entered = threading.Event()

        def account_maintenance():
            with pool.account_management_lock():
                entered.set()

        thread = threading.Thread(target=account_maintenance)
        thread.start()
        self.assertFalse(entered.wait(0.05))
        player_lock.release()
        self.assertTrue(entered.wait(1))
        thread.join(timeout=1)

    def test_uncertain_request_pauses_until_done_and_inventory_reconciles(self):
        pool = self.make_pool()
        pool._routing_ready.set()
        pool._worker_call = mock.Mock(
            return_value={"ok": 1, "state": "done"}
        )
        pool._recover_local_players = mock.Mock()
        pool.quarantine_uncertain_request("w01", "c" * 64)
        self.assertFalse(pool._routing_ready.is_set())
        deadline = time.monotonic() + 2
        while not pool._routing_ready.is_set() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue(pool._routing_ready.is_set())
        pool._recover_local_players.assert_called_once()

    def test_request_queued_on_transaction_lock_rechecks_routing_gate(self):
        pool = self.make_pool()
        pool._routing_ready.set()
        pool.begin_request()
        pool._routing_ready.clear()
        with self.assertRaises(RuntimeError):
            pool.ensure_routing_ready()
        pool.end_request()

    def test_startup_inventory_rejects_unfinished_worker_request(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(
            return_value={"ok": 1, "count": 1, "running": [{}]}
        )
        with self.assertRaises(RuntimeError):
            pool._recover_local_players()

    def test_frozen_lease_is_never_reacquired(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 1,
                    "worker_id": "w01",
                    "epoch": 7,
                    "state": "frozen",
                }
            }
        )
        pool = self.make_pool(coordinator)
        with self.assertRaisesRegex(RuntimeError, "handoff"):
            pool.route_user("xd01player")
        self.assertEqual([call[0] for call in coordinator.calls], ["route"])

    def test_first_login_allocates_a_new_lease_instead_of_expired_recovery(self):
        coordinator = FakeCoordinator(
            {
                "route": {"ok": 0, "code": "lease_missing"},
                "assign_affinity": {"ok": 1, "worker_id": "w01"},
                "lease_acquire": {"ok": 1, "epoch": 1},
            }
        )
        pool = self.make_pool(coordinator)
        pool._sync_assignment = mock.Mock()
        worker, epoch, affinity, arrival = pool.route_user("xd01firstlogin")
        self.assertEqual((worker, epoch, arrival), ("w01", 1, ""))
        self.assertTrue(affinity.startswith("session:"))
        self.assertEqual(
            [call[0] for call in coordinator.calls],
            ["route", "assign_affinity", "lease_acquire"],
        )

    def test_expired_lease_reopens_only_on_its_previous_worker(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 0,
                    "code": "lease_expired",
                    "worker_id": "w02",
                    "affinity": "wugongdong",
                    "epoch": 7,
                },
                "lease_acquire": {
                    "ok": 1,
                    "epoch": 8,
                    "arrival_room_path": "/gamelib/d/target_map/room",
                },
            }
        )
        pool = self.make_pool(coordinator)
        self.assertEqual(
            pool.route_user("xd01player"),
            ("w02", 8, "wugongdong", "/gamelib/d/target_map/room"),
        )
        acquire = coordinator.calls[-1]
        self.assertEqual(acquire[0], "lease_acquire")
        self.assertEqual(acquire[1]["worker_id"], "w02")
        self.assertEqual(acquire[1]["expected_epoch"], 7)

    def test_committed_arrival_is_forwarded_until_worker_ack(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 1,
                    "worker_id": "w02",
                    "epoch": 8,
                    "state": "active",
                    "affinity": "target_map",
                    "arrival_room_path": "/gamelib/d/target_map/room",
                },
                "lease_renew": {"ok": 1},
                "arrival_ack": {"ok": 1},
            }
        )
        pool = self.make_pool(coordinator)
        self.assertEqual(
            pool.route_user("xd01player"),
            ("w02", 8, "target_map", "/gamelib/d/target_map/room"),
        )
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "lease_epoch": 8,
                "affinity": "target_map",
                "room_path": "/gamelib/d/target_map/room",
            }
        )
        pool.acknowledge_arrival(
            "xd01player",
            "w02",
            8,
            "target_map",
            "/gamelib/d/target_map/room",
        )
        self.assertEqual(coordinator.calls[-1][0], "arrival_ack")

    def test_arrival_ack_fails_closed_on_worker_or_coordinator_mismatch(self):
        coordinator = FakeCoordinator({"arrival_ack": {"ok": 0}})
        pool = self.make_pool(coordinator)
        pool._worker_call = mock.Mock(return_value={"ok": 0})
        with self.assertRaisesRegex(RuntimeError, "worker arrival"):
            pool.acknowledge_arrival(
                "xd01player", "w02", 8, "target_map",
                "/gamelib/d/target_map/room",
            )
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "lease_epoch": 8,
                "affinity": "target_map",
                "room_path": "/gamelib/d/target_map/room",
            }
        )
        with self.assertRaisesRegex(RuntimeError, "coordinator arrival"):
            pool.acknowledge_arrival(
                "xd01player", "w02", 8, "target_map",
                "/gamelib/d/target_map/room",
            )

    def test_arrival_ack_rejects_a_different_room_in_the_same_affinity(self):
        coordinator = FakeCoordinator({"arrival_ack": {"ok": 1}})
        pool = self.make_pool(coordinator)
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "lease_epoch": 8,
                "affinity": "target_map",
                "room_path": "/gamelib/d/target_map/wrong_room",
            }
        )
        with self.assertRaisesRegex(RuntimeError, "worker arrival"):
            pool.acknowledge_arrival(
                "xd01player", "w02", 8, "target_map",
                "/gamelib/d/target_map/room",
            )
        self.assertFalse(
            any(action == "arrival_ack" for action, _params in coordinator.calls)
        )

    def test_confirmed_route_rejects_stale_owner_or_epoch(self):
        pool = self.make_pool(
            FakeCoordinator({
                "route": {
                    "ok": 1,
                    "state": "active",
                    "worker_id": "w01",
                    "epoch": 6,
                    "affinity": "source_map",
                }
            })
        )
        with self.assertRaisesRegex(RuntimeError, "route confirmation"):
            pool.confirmed_route("xd01player", "w02", 8)

    def test_failed_worker_probe_emits_no_false_heartbeat_metrics(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(side_effect=OSError("worker down"))
        self.assertIsNone(pool._collect_worker_metrics("w02"))
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "active_players": 3,
                "active_rooms": 2,
                "pending_commands": 1,
                "heartbeat_ms": 7,
            }
        )
        self.assertEqual(
            pool._collect_worker_metrics("w02"),
            {
                "active_players": 3,
                "active_rooms": 2,
                "pending_commands": 1,
                "heartbeat_ms": 7,
            },
        )

    def test_empty_recovery_cannot_resume_without_coordinator_generation_ack(self):
        class UnavailableCoordinator(FakeCoordinator):
            def call(self, action, **params):
                self.calls.append((action, params))
                raise RuntimeError("coordinator unavailable")

        coordinator = UnavailableCoordinator()
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_status":
                return {"ok": 1, "active_players": 0, "active_rooms": 0}
            if action == "local_inventory":
                return {"ok": 1, "players": []}
            return {"ok": 1, "count": 0}

        pool._worker_call = worker_call
        pool._monitor_worker("w01")
        self.assertFalse(pool._worker_reachable["w01"])
        self.assertEqual([call[1] for call in calls], ["local_status"])
        self.assertEqual([call[0] for call in coordinator.calls], ["heartbeat"])

    def test_generation_ack_precedes_empty_worker_resume(self):
        coordinator = FakeCoordinator({"heartbeat": {"ok": 1}})
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_status":
                return {"ok": 1, "active_players": 0, "active_rooms": 0}
            if action == "local_inventory":
                return {"ok": 1, "players": []}
            return {"ok": 1, "count": 0}

        pool._worker_call = worker_call
        pool._monitor_worker("w01")
        self.assertTrue(pool._worker_reachable["w01"])
        self.assertEqual(coordinator.calls[0][0], "heartbeat")
        self.assertEqual(calls[-1][1], "local_control_resume")

    def test_failed_generation_recovery_keeps_global_routing_paused(self):
        coordinator = FakeCoordinator(
            {"heartbeat": {"ok": 0, "code": "stale_generation"}}
        )
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        pool._routing_ready.set()
        pool._worker_call = mock.Mock(
            return_value={"ok": 1, "active_players": 0, "active_rooms": 0}
        )
        pool._register_all = mock.Mock(side_effect=RuntimeError("register failed"))
        pool._monitor_worker("w01")
        self.assertFalse(pool._routing_ready.is_set())
        self.assertFalse(pool._worker_reachable["w01"])

    def test_failed_worker_inventory_recovery_keeps_global_routing_paused(self):
        coordinator = FakeCoordinator({"heartbeat": {"ok": 1}})
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        pool._routing_ready.set()
        pool._worker_call = mock.Mock(
            return_value={"ok": 1, "active_players": 0, "active_rooms": 0}
        )
        pool._reconcile_recovered_worker = mock.Mock(
            side_effect=RuntimeError("inventory failed")
        )
        pool._monitor_worker("w01")
        self.assertFalse(pool._routing_ready.is_set())
        self.assertFalse(pool._worker_reachable["w01"])

    def test_live_player_leases_renew_after_generation_ack_before_control(self):
        coordinator = FakeCoordinator(
            {
                "heartbeat": {"ok": 1},
                "lease_renew_batch": {"ok": 1, "count": 1},
            }
        )
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        pool._worker_reachable["w01"] = True
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_status":
                return {"ok": 1, "active_players": 1, "active_rooms": 1}
            if action == "local_live_leases":
                return {
                    "ok": 1,
                    "leases": [
                        {
                            "userid": "xd01player",
                            "account_id": "xd01account",
                            "epoch": 9,
                            "affinity": "wugongdong",
                        }
                    ],
                    "next_offset": 1,
                    "done": 1,
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._monitor_worker("w01")
        self.assertTrue(pool._worker_reachable["w01"])
        self.assertEqual(
            [call[0] for call in coordinator.calls],
            ["heartbeat", "lease_renew_batch"],
        )
        self.assertEqual(
            [call[1] for call in calls],
            ["local_status", "local_live_leases", "local_live_leases",
             "local_control_heartbeat"],
        )
        self.assertEqual(
            coordinator.calls[1][1],
            {
                "worker_id": "w01",
                "generation": 7,
                "leases": [
                    {
                        "userid": "xd01player",
                        "epoch": 9,
                        "affinity": "wugongdong",
                    }
                ],
            },
        )

    def test_stale_live_lease_withholds_worker_control_heartbeat(self):
        coordinator = FakeCoordinator(
            {
                "heartbeat": {"ok": 1},
                "lease_renew_batch": {"ok": 0, "code": "stale_lease"},
            }
        )
        pool = self.make_pool(coordinator)
        pool.generations["w01"] = 7
        pool._worker_reachable["w01"] = True
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_status":
                return {"ok": 1, "active_players": 1, "active_rooms": 1}
            if action == "local_live_leases":
                return {
                    "ok": 1,
                    "leases": [{
                        "userid": "xd01stale",
                        "account_id": "xd01account",
                        "epoch": 2,
                        "affinity": "wugongdong",
                    }],
                    "next_offset": 1,
                    "done": 1,
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._monitor_worker("w01")
        self.assertFalse(pool._worker_reachable["w01"])
        self.assertNotIn("local_control_heartbeat", [call[1] for call in calls])

    def test_busy_player_lock_skips_renewal_without_blocking_control_monitor(self):
        coordinator = FakeCoordinator()
        pool = self.make_pool(coordinator)
        lease_page = {
            "ok": 1,
            "leases": [{"userid": "xd01busy", "account_id": "xd01account",
                        "epoch": 3, "affinity": "wugongdong"}],
            "next_offset": 1,
            "done": 1,
        }
        pool._worker_call = mock.Mock(return_value=lease_page)
        lock = pool.user_lock("xd01busy", "xd01account")
        lock.acquire()
        try:
            pool._renew_live_player_leases("w01", 7)
        finally:
            lock.release()
        self.assertFalse(
            any(action == "lease_renew_batch"
                for action, _params in coordinator.calls)
        )
        self.assertEqual(pool._worker_call.call_count, 2)

    def test_recovered_worker_discards_copy_owned_by_new_epoch_elsewhere(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 1,
                    "state": "active",
                    "worker_id": "w02",
                    "epoch": 9,
                }
            }
        )
        pool = self.make_pool(coordinator)
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_inventory":
                return {
                    "ok": 1,
                    "players": [
                        {
                            "userid": "xd01stale",
                            "affinity": "wugongdong",
                            "lease_epoch": 7,
                        }
                    ],
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._reconcile_recovered_worker("w01")
        discard = next(call for call in calls if call[1] == "local_discard")
        self.assertEqual(discard[2], {"userid": "xd01stale", "epoch": 7})
        self.assertEqual(calls[-1][1], "local_control_resume")
        self.assertFalse(any(call[0] == "lease_recover" for call in coordinator.calls))

    def test_recovered_exact_owner_renews_before_resume(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 1,
                    "state": "active",
                    "worker_id": "w01",
                    "epoch": 7,
                    "affinity": "wugongdong",
                },
                "lease_renew": {"ok": 1},
            }
        )
        pool = self.make_pool(coordinator)
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_inventory":
                return {
                    "ok": 1,
                    "players": [
                        {
                            "userid": "xd01owner",
                            "affinity": "wugongdong",
                            "lease_epoch": 7,
                        }
                    ],
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._reconcile_recovered_worker("w01")
        self.assertTrue(any(call[1] == "local_epoch" for call in calls))
        self.assertFalse(any(call[1] == "local_discard" for call in calls))
        self.assertEqual(calls[-1][1], "local_control_resume")

    def test_full_recovery_rebinds_same_worker_affinity_mismatch(self):
        coordinator = FakeCoordinator(
            {
                "route": {
                    "ok": 1,
                    "state": "active",
                    "worker_id": "w01",
                    "epoch": 7,
                    "affinity": "old_map",
                },
                "assign_affinity": {
                    "ok": 1,
                    "worker_id": "w01",
                    "placement_generation": 3,
                },
                "lease_rebind": {"ok": 1, "epoch": 7},
            }
        )
        pool = self.make_pool(coordinator)

        def worker_call(worker, action, **_params):
            if action == "local_inflight":
                return {"ok": 1, "count": 0}
            if action == "local_inventory":
                return {
                    "ok": 1,
                    "players": [{
                        "userid": "xd01owner",
                        "affinity": "new_map",
                        "account_id": "xd01account",
                        "lease_epoch": 7,
                    }] if worker == "w01" else [],
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._recover_local_players()
        actions = [action for action, _params in coordinator.calls]
        self.assertIn("lease_rebind", actions)
        self.assertNotIn("lease_recover", actions)

    def test_recovery_waits_for_inflight_request_before_inventory(self):
        pool = self.make_pool()
        pool._routing_ready.set()
        pool.begin_request()
        paused = threading.Event()

        def pause():
            pool._pause_routing()
            paused.set()

        thread = threading.Thread(target=pause)
        thread.start()
        self.assertFalse(paused.wait(0.05))
        pool.end_request()
        self.assertTrue(paused.wait(1))
        thread.join(timeout=1)
        self.assertFalse(pool._routing_ready.is_set())
        with self.assertRaisesRegex(RuntimeError, "recovery"):
            pool.begin_request()
        pool._resume_routing()

    def test_reconciled_lease_gc_uploads_bounded_inventory_chunks(self):
        coordinator = FakeCoordinator({
            "lease_reconcile_begin": {"ok": 1},
            "lease_reconcile_add": {"ok": 1},
            "lease_reconcile_commit": {
                "ok": 1,
                "pruned_leases": 3,
                "pruned_assignments": 2,
            },
        })
        pool = self.make_pool(coordinator)
        users = [f"xd01player{index}" for index in range(1001)]
        result = pool._prune_reconciled_tombstones(users)
        chunks = [
            params["users"] for action, params in coordinator.calls
            if action == "lease_reconcile_add"
        ]
        self.assertEqual([len(chunk) for chunk in chunks], [500, 500, 1])
        self.assertEqual(result["pruned_leases"], 3)

    def test_periodic_lease_gc_reopens_only_after_complete_inventory(self):
        pool = self.make_pool()
        pool._routing_ready.set()
        observed = []

        def recover():
            observed.append(pool._routing_ready.is_set())

        pool._recover_local_players = mock.Mock(side_effect=recover)
        pool._run_lease_gc_once()
        self.assertEqual(observed, [False])
        self.assertTrue(pool._routing_ready.is_set())

    def test_failed_periodic_lease_gc_keeps_routing_paused(self):
        pool = self.make_pool()
        pool._routing_ready.set()
        pool._recover_local_players = mock.Mock(
            side_effect=RuntimeError("inventory failed")
        )
        with self.assertRaisesRegex(RuntimeError, "inventory failed"):
            pool._run_lease_gc_once()
        self.assertFalse(pool._routing_ready.is_set())

    def test_catalog_snapshot_is_installed_on_every_worker(self):
        coordinator = FakeCoordinator(
            {
                "assign_catalog": {"ok": 1},
                "status": {
                    "ok": 1,
                    "placement_generation": 9,
                    "placements": [
                        {"affinity": "wugongdong", "worker_id": "w02"}
                    ],
                },
            }
        )
        pool = self.make_pool(coordinator)
        calls = []
        pool._worker_call = lambda worker, action, **params: (
            calls.append((worker, action, params)) or {"ok": 1}
        )
        pool._sync_catalog()
        self.assertEqual([call[0] for call in calls], ["w01", "w02"])
        self.assertTrue(all(call[1] == "local_assignments" for call in calls))
        self.assertTrue(all(call[2]["generation"] == 9 for call in calls))

    def test_duplicate_live_player_copies_are_discarded_without_saving(self):
        pool = self.make_pool()
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_inflight":
                return {"ok": 1, "count": 0, "running": []}
            if action == "local_inventory":
                return {
                    "ok": 1,
                    "players": [{
                        "userid": "xd01same",
                        "affinity": worker + "map",
                        "lease_epoch": 7,
                    }],
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        pool._recover_local_players()
        discards = [call for call in calls if call[1] == "local_discard"]
        self.assertEqual(len(discards), 2)
        self.assertEqual(
            {call[0] for call in discards}, {"w01", "w02"}
        )
        self.assertFalse(
            any(call[0] == "lease_recover" for call in pool.coordinator.calls)
        )

    def test_cross_worker_move_releases_source_then_commits_and_replays(self):
        coordinator = FakeCoordinator(
            {
                "assign_affinity": {
                    "ok": 1,
                    "worker_id": "w02",
                    "placement_generation": 12,
                },
                "handoff_begin": {
                    "ok": 1,
                    "state": "prepared",
                    "target_worker": "w02",
                },
                "handoff_commit": {"ok": 1, "target_epoch": 8},
            }
        )
        pool = self.make_pool(coordinator)
        worker_calls = []

        def worker_call(worker, action, **params):
            worker_calls.append((worker, action, params))
            if action == "local_route":
                return {
                    "ok": 1,
                    "handoff_safe": 1,
                    "affinity": "source_map",
                    "move_redirect": {
                        "ok": 1,
                        "target_affinity": "target_map",
                        "target_room_path": "/gamelib/d/target_map/room",
                    },
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        result = pool.reconcile("xd01player", "w01", 7, "source_map")
        self.assertEqual(
            result,
            ("w02", 8, True, "/gamelib/d/target_map/room"),
        )
        release = next(call for call in worker_calls if call[1] == "local_release")
        self.assertEqual(release[2]["affinity"], "source_map")
        self.assertEqual(release[2]["epoch"], 7)
        actions = [call[0] for call in coordinator.calls]
        self.assertLess(actions.index("handoff_begin"), actions.index("handoff_commit"))
        begin = next(call for call in coordinator.calls if call[0] == "handoff_begin")
        self.assertEqual(
            begin[1]["target_room_path"], "/gamelib/d/target_map/room"
        )

    def test_background_arrival_uses_internal_cache_and_epoch_capabilities(self):
        pool = self.make_pool()
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            return {"ok": 1, "affinity": "target_map"}

        pool._worker_call = worker_call
        pool.confirmed_route = mock.Mock(
            side_effect=[
                ("target_map", "/gamelib/d/target_map/room"),
                ("target_map", ""),
            ]
        )
        pool.acknowledge_arrival = mock.Mock()
        pool._deliver_background_arrival(
            "xd01player", "w02", 8, "/gamelib/d/target_map/room",
            "xd01account",
        )
        arrival = calls[0]
        self.assertEqual(arrival[1], "local_arrival")
        self.assertEqual(arrival[2]["epoch"], 8)
        self.assertEqual(arrival[2]["account_owner"], "xd01account")
        self.assertEqual(len(arrival[2]["account_cache_token"]), 64)
        pool.acknowledge_arrival.assert_called_once_with(
            "xd01player", "w02", 8, "target_map",
            "/gamelib/d/target_map/room",
        )

    def test_timer_move_reconciles_under_lease_and_keeps_failed_arrival(self):
        coordinator = FakeCoordinator({
            "route": {
                "ok": 1,
                "state": "active",
                "worker_id": "w01",
                "epoch": 7,
                "affinity": "source_map",
            }
        })
        pool = self.make_pool(coordinator)
        pool._routing_ready.set()
        pool.reconcile = mock.Mock(return_value=(
            "w02", 8, True, "/gamelib/d/target_map/room"
        ))
        pool._deliver_background_arrival = mock.Mock(
            side_effect=RuntimeError("target temporarily unavailable")
        )
        with self.assertRaisesRegex(RuntimeError, "temporarily unavailable"):
            pool._settle_background_move("w01", {
                "userid": "xd01player",
                "account_id": "xd01account",
                "lease_epoch": 7,
            })
        pool.reconcile.assert_called_once_with(
            "xd01player", "w01", 7, "source_map", require_settled=True
        )
        self.assertEqual(
            pool._background_arrivals["xd01player"],
            ("w02", 8, "/gamelib/d/target_map/room", "xd01account"),
        )

    def test_completed_public_arrival_clears_background_retry(self):
        coordinator = FakeCoordinator({
            "route": {
                "ok": 1,
                "state": "active",
                "worker_id": "w02",
                "epoch": 8,
                "affinity": "target_map",
                "arrival_room_path": "",
            }
        })
        pool = self.make_pool(coordinator)
        pool._routing_ready.set()
        pending = (
            "w02", 8, "/gamelib/d/target_map/room", "xd01account"
        )
        pool._background_arrivals["xd01player"] = pending
        pool._deliver_background_arrival = mock.Mock()
        pool._retry_background_arrival("xd01player", pending)
        self.assertNotIn("xd01player", pool._background_arrivals)
        pool._deliver_background_arrival.assert_not_called()

    def test_handoff_target_or_state_drift_is_rejected_before_source_release(self):
        for prepared in (
            {"ok": 1, "state": "committed", "target_worker": "w02"},
            {"ok": 1, "state": "prepared", "target_worker": "w03"},
        ):
            with self.subTest(prepared=prepared):
                coordinator = FakeCoordinator({
                    "assign_affinity": {
                        "ok": 1,
                        "worker_id": "w02",
                        "placement_generation": 12,
                    },
                    "handoff_begin": prepared,
                })
                pool = self.make_pool(coordinator)
                calls = []

                def worker_call(worker, action, **params):
                    calls.append((worker, action, params))
                    if action == "local_route":
                        return {
                            "ok": 1,
                            "handoff_safe": 1,
                            "affinity": "source_map",
                            "move_redirect": {
                                "ok": 1,
                                "target_affinity": "target_map",
                                "target_room_path": "/gamelib/d/target_map/room",
                            },
                        }
                    return {"ok": 1}

                pool._worker_call = worker_call
                with self.assertRaisesRegex(RuntimeError, "cannot prepare"):
                    pool.reconcile("xd01player", "w01", 7, "source_map")
                self.assertFalse(any(call[1] == "local_release" for call in calls))

    def test_dynamic_clone_room_move_fails_closed_without_arrival_path(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "handoff_safe": 1,
                "affinity": "source_map",
                "move_redirect": {
                    "ok": 1,
                    "target_affinity": "fb:test",
                    "target_room_path": "",
                },
            }
        )
        self.assertIsNone(pool.reconcile("xd01player", "w01", 7, "source_map"))
        self.assertEqual(pool.coordinator.calls, [])

    def test_pending_route_fails_closed_while_player_is_in_combat(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "handoff_safe": 0,
                "affinity": "source_map",
            }
        )
        with self.assertRaisesRegex(RuntimeError, "not handoff-safe"):
            pool.reconcile(
                "xd01player", "w01", 7, "source_map",
                require_settled=True,
            )

    def test_reconcile_failure_is_not_reported_as_no_route_change(self):
        coordinator = FakeCoordinator(
            {"assign_affinity": {"ok": 0, "code": "no_capacity"}}
        )
        pool = self.make_pool(coordinator)
        pool._worker_call = mock.Mock(
            return_value={
                "ok": 1,
                "handoff_safe": 1,
                "affinity": "source_map",
                "move_redirect": {
                    "ok": 1,
                    "target_affinity": "target_map",
                    "target_room_path": "/gamelib/d/target_map/room",
                },
            }
        )
        with self.assertRaisesRegex(RuntimeError, "cannot place"):
            pool.reconcile("xd01player", "w01", 7, "source_map")

    def test_same_worker_redirect_completes_move_without_replaying_command(self):
        coordinator = FakeCoordinator(
            {
                "assign_affinity": {
                    "ok": 1,
                    "worker_id": "w01",
                    "placement_generation": 12,
                },
                "handoff_begin": {
                    "ok": 1,
                    "local": 1,
                    "worker_id": "w01",
                    "epoch": 7,
                },
            }
        )
        pool = self.make_pool(coordinator)
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_route":
                return {
                    "ok": 1,
                    "handoff_safe": 1,
                    "affinity": "source_map",
                    "move_redirect": {
                        "ok": 1,
                        "target_affinity": "target_map",
                        "target_room_path": "/gamelib/d/target_map/room",
                    },
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        self.assertEqual(
            pool.reconcile("xd01player", "w01", 7, "source_map"),
            ("w01", 7, True, "/gamelib/d/target_map/room"),
        )
        completed = next(
            call for call in calls if call[1] == "local_redirect_complete"
        )
        self.assertEqual(completed[2]["epoch"], 7)
        self.assertFalse(any(call[1] == "local_release" for call in calls))
        self.assertIn("lease_rebind", [call[0] for call in coordinator.calls])
        self.assertNotIn("handoff_begin", [call[0] for call in coordinator.calls])

    def test_same_worker_completed_move_rebinds_lease_affinity(self):
        coordinator = FakeCoordinator(
            {
                "assign_affinity": {
                    "ok": 1,
                    "worker_id": "w01",
                    "placement_generation": 4,
                },
                "lease_rebind": {"ok": 1},
            }
        )
        pool = self.make_pool(coordinator)
        calls = []

        def worker_call(worker, action, **params):
            calls.append((worker, action, params))
            if action == "local_route":
                return {
                    "ok": 1,
                    "account_id": "xd01account",
                    "handoff_safe": 1,
                    "affinity": "target_map",
                    "room_path": "/gamelib/d/target_map/room",
                    "move_redirect": 0,
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        self.assertEqual(
            pool.reconcile("xd01player", "w01", 7, "source_map"),
            ("w01", 7, False, ""),
        )
        rebind = next(
            params for action, params in coordinator.calls
            if action == "lease_rebind"
        )
        self.assertEqual(
            rebind,
            {
                "userid": "xd01player",
                "worker_id": "w01",
                "epoch": 7,
                "affinity": "target_map",
            },
        )
        self.assertFalse(any(call[1] == "local_release" for call in calls))

    def test_unreconstructable_dynamic_room_never_crosses_workers(self):
        coordinator = FakeCoordinator(
            {
                "assign_affinity": {
                    "ok": 1,
                    "worker_id": "w02",
                    "placement_generation": 4,
                }
            }
        )
        pool = self.make_pool(coordinator)

        def worker_call(_worker, action, **_params):
            if action == "local_route":
                return {
                    "ok": 1,
                    "handoff_safe": 1,
                    "affinity": "home:xd01owner",
                    "room_path": "/gamelib/d/home/template/main#17",
                    "move_redirect": 0,
                }
            return {"ok": 1}

        pool._worker_call = worker_call
        with self.assertRaisesRegex(RuntimeError, "dynamic instance"):
            pool.reconcile("xd01player", "w01", 7, "source_map")

    def test_proxy_strips_forged_internal_headers_and_adds_lease_fence(self):
        pool = self.make_pool()
        pool._wait_for_request_done = mock.Mock()
        connection = mock.Mock()
        response = mock.Mock()
        response.read.return_value = b"{}"
        response.getheaders.side_effect = lambda: [
            ("Content-Length", "2"),
            (
                "X-Xiand-Request-Accepted",
                connection.request.call_args.kwargs["headers"][
                    "X-Xiand-Request-Id"
                ],
            ),
        ]
        response.status = 200
        response.reason = "OK"
        connection.getresponse.return_value = response
        with mock.patch(
            "gateway.http.client.HTTPConnection", return_value=connection
        ):
            pool.proxy(
                "w01",
                "GET",
                "/api/json",
                Headers({"X-Xiand-Worker-Token": "forged", "Accept": "*/*"}),
                b"",
                "xd01player",
                7,
                "/gamelib/d/wugongdong/room",
                "xd01account",
            )
        sent_headers = connection.request.call_args.kwargs["headers"]
        self.assertEqual(sent_headers["X-Xiand-Worker-Token"], "x" * 32)
        self.assertEqual(sent_headers["X-Xiand-Lease-Worker"], "w01")
        self.assertEqual(sent_headers["X-Xiand-Lease-Userid"], "xd01player")
        self.assertEqual(sent_headers["X-Xiand-Lease-Epoch"], "7")
        self.assertEqual(len(sent_headers["X-Xiand-Request-Id"]), 64)
        self.assertEqual(sent_headers["X-Xiand-Command-Kind"], "general")
        self.assertEqual(
            sent_headers["X-Xiand-Arrival-Room"],
            "/gamelib/d/wugongdong/room",
        )
        self.assertEqual(sent_headers["X-Xiand-Account-Owner"], "xd01account")
        self.assertEqual(len(sent_headers["X-Xiand-Account-Cache-Token"]), 64)
        waited_worker, waited_request = (
            pool._wait_for_request_done.call_args.args
        )
        self.assertEqual(waited_worker, "w01")
        self.assertEqual(waited_request, sent_headers["X-Xiand-Request-Id"])

    def test_prefence_rejection_does_not_create_false_uncertain_request(self):
        pool = self.make_pool()
        pool._wait_for_request_done = mock.Mock()
        pool.quarantine_uncertain_request = mock.Mock()
        connection = mock.Mock()
        response = mock.Mock()
        response.read.return_value = b'{"code":"user_request_running"}'
        response.getheaders.return_value = [("Content-Length", "31")]
        response.status = 409
        response.reason = "Conflict"
        connection.getresponse.return_value = response
        with mock.patch(
            "gateway.http.client.HTTPConnection", return_value=connection
        ):
            proxied = pool.proxy(
                "w01", "GET", "/api/json", Headers(), b"",
                "xd01player", 7,
            )
        self.assertEqual(proxied.status, 409)
        pool._wait_for_request_done.assert_not_called()
        pool.quarantine_uncertain_request.assert_not_called()

    def test_success_without_request_fence_proof_is_quarantined(self):
        pool = self.make_pool()
        pool.quarantine_uncertain_request = mock.Mock()
        connection = mock.Mock()
        response = mock.Mock()
        response.read.return_value = b"{}"
        response.getheaders.return_value = [("Content-Length", "2")]
        response.status = 200
        response.reason = "OK"
        connection.getresponse.return_value = response
        with mock.patch(
            "gateway.http.client.HTTPConnection", return_value=connection
        ):
            with self.assertRaises(gateway.UncertainProxyError):
                pool.proxy(
                    "w01", "GET", "/api/json", Headers(), b"",
                    "xd01player", 7,
                )
        pool.quarantine_uncertain_request.assert_called_once()

    def test_request_done_fence_waits_through_running_state(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(
            side_effect=[
                {"ok": 1, "state": "running"},
                {"ok": 1, "state": "done"},
            ]
        )
        with mock.patch("gateway.time.sleep"):
            pool._wait_for_request_done("w02", "d" * 64)
        self.assertEqual(pool._worker_call.call_count, 2)

    def test_request_done_fence_fails_closed_on_unknown_status(self):
        pool = self.make_pool()
        pool._worker_call = mock.Mock(
            return_value={"ok": 0, "code": "unknown_request"}
        )
        with self.assertRaisesRegex(RuntimeError, "prove request completion"):
            pool._wait_for_request_done("w02", "e" * 64)

    def test_proxy_socket_failure_quarantines_uncertain_request(self):
        pool = self.make_pool()
        connection = mock.Mock()
        connection.request.side_effect = TimeoutError("timed out")
        pool.quarantine_uncertain_request = mock.Mock()
        with mock.patch(
            "gateway.http.client.HTTPConnection", return_value=connection
        ):
            with self.assertRaises(gateway.UncertainProxyError):
                pool.proxy(
                    "w01", "POST", "/api", Headers(), b"{}",
                    "xd01player", 7,
                )
        worker_id, request_id = pool.quarantine_uncertain_request.call_args.args
        self.assertEqual(worker_id, "w01")
        self.assertEqual(len(request_id), 64)


if __name__ == "__main__":
    unittest.main()
