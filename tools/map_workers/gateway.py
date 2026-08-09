#!/usr/bin/env python3
"""Transparent HTTP gateway for a Xiand map-worker pool.

The gateway never interprets game commands and never mutates player data.  It
keeps the existing HTTP/login contract byte-for-byte, asks the Pike coordinator
for a fenced player lease, proxies to the owning worker, then reconciles the
player's room affinity after the response.  A cross-worker move is committed
only after the source worker has atomically saved and released the player.
"""

from __future__ import annotations

import hashlib
import http.client
import json
import os
import fcntl
import secrets
import signal
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from contextlib import ExitStack, contextmanager
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}
MAX_BODY_BYTES = 1_048_576


class GatewayProcessClaim:
    """Hold one OS-level controller lock and publish its validated PID."""

    def __init__(self, lock_path: str, pid_path: str) -> None:
        if not os.path.isabs(lock_path) or not os.path.isabs(pid_path):
            raise RuntimeError("absolute gateway lock and PID paths are required")
        os.makedirs(os.path.dirname(lock_path), mode=0o750, exist_ok=True)
        self._lock_file = open(lock_path, "a+", encoding="utf-8")
        os.chmod(lock_path, 0o640)
        try:
            fcntl.flock(self._lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self._lock_file.close()
            raise RuntimeError("another map-worker gateway controls this topology") from exc
        self._pid_path = pid_path
        self._pid = os.getpid()
        os.makedirs(os.path.dirname(pid_path), mode=0o750, exist_ok=True)
        temporary = f"{pid_path}.{self._pid}.tmp"
        with open(temporary, "w", encoding="ascii") as handle:
            handle.write(str(self._pid))
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o640)
        os.replace(temporary, pid_path)

    def close(self) -> None:
        try:
            with open(self._pid_path, encoding="ascii") as handle:
                owns_pid_file = handle.read().strip() == str(self._pid)
        except OSError:
            owns_pid_file = False
        if owns_pid_file:
            try:
                os.unlink(self._pid_path)
            except FileNotFoundError:
                pass
        if not self._lock_file.closed:
            fcntl.flock(self._lock_file.fileno(), fcntl.LOCK_UN)
            self._lock_file.close()


class UncertainProxyError(RuntimeError):
    """The worker may still be applying a request after the socket failed."""


class BoundedThreadingHTTPServer(ThreadingHTTPServer):
    """Bound gateway threads so stalled clients cannot exhaust server memory."""

    daemon_threads = False
    block_on_close = True

    def __init__(
        self,
        address: tuple[str, int],
        handler: Any,
        limit: int,
        client_timeout: float = 30.0,
    ) -> None:
        self._request_slots = threading.BoundedSemaphore(limit)
        self.client_timeout = client_timeout
        super().__init__(address, handler)

    def process_request(self, request: Any, client_address: Any) -> None:
        request.settimeout(self.client_timeout)
        if not self._request_slots.acquire(blocking=False):
            try:
                body = b'{"error":"gateway busy"}'
                request.sendall(
                    b"HTTP/1.1 503 Service Unavailable\r\n"
                    b"Content-Type: application/json\r\n"
                    + f"Content-Length: {len(body)}\r\n".encode("ascii")
                    + b"Connection: close\r\nRetry-After: 1\r\n\r\n"
                    + body
                )
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self._request_slots.release()
            raise

    def process_request_thread(self, request: Any, client_address: Any) -> None:
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._request_slots.release()


def env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    raw = os.environ.get(name, "")
    try:
        value = int(raw) if raw else default
    except ValueError as exc:
        raise SystemExit(f"[map-gateway] {name} must be an integer") from exc
    if value < minimum or value > maximum:
        raise SystemExit(
            f"[map-gateway] {name} must be between {minimum} and {maximum}"
        )
    return value


def parse_worker_endpoints(raw: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for entry in raw.split(","):
        entry = entry.strip()
        if not entry:
            continue
        worker_id, separator, endpoint = entry.partition("=")
        worker_id = worker_id.strip().lower()
        endpoint = endpoint.strip().rstrip("/")
        parsed = urllib.parse.urlsplit(endpoint)
        if (
            not separator
            or not worker_id
            or len(worker_id) > 48
            or parsed.scheme != "http"
            or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}
            or not parsed.port
        ):
            raise SystemExit(f"[map-gateway] invalid XIAND_WORKERS entry: {entry}")
        result[worker_id] = endpoint
    if not result:
        raise SystemExit("[map-gateway] XIAND_WORKERS contains no workers")
    return result


def decode_txd_userid(txd: str) -> str:
    """Decode only the userid portion of the unchanged legacy TXD format."""
    encoded, separator, _password = txd.partition("~")
    if not separator or not encoded or len(encoded) > 128:
        return ""
    decoded: list[str] = []
    try:
        for index, character in enumerate(encoded):
            # Preserve the legacy Pike expression `index / 2 == 0`.
            offset = 2 if index // 2 == 0 else 1
            value = ord(character) - offset
            if value < 0 or value > 127:
                return ""
            decoded.append(chr(value))
    except (TypeError, ValueError):
        return ""
    return "".join(decoded).strip().lower()


def valid_userid(userid: str) -> bool:
    return (
        2 <= len(userid) <= 64
        and ".." not in userid
        and all(character in "abcdefghijklmnopqrstuvwxyz0123456789_.-"
                for character in userid)
    )


def public_path_allowed(path: str) -> bool:
    return not urllib.parse.urlsplit(path).path.startswith("/internal/")


def account_api_path(path: str) -> bool:
    return urllib.parse.urlsplit(path).path.startswith("/api/account/")


def extract_params(path: str, headers: Any, body: bytes) -> dict[str, Any]:
    params: dict[str, Any] = {}
    query = urllib.parse.urlsplit(path).query
    if query:
        for key, values in urllib.parse.parse_qs(
            query, keep_blank_values=True, max_num_fields=128
        ).items():
            if values:
                params[key] = values[-1]
    content_type = (headers.get("Content-Type") or "").lower()
    if body and "json" in content_type:
        try:
            decoded = json.loads(body.decode("utf-8"))
            if isinstance(decoded, dict):
                params.update(decoded)
        except (UnicodeDecodeError, json.JSONDecodeError):
            pass
    elif body and "x-www-form-urlencoded" in content_type:
        try:
            form = urllib.parse.parse_qs(
                body.decode("utf-8"), keep_blank_values=True, max_num_fields=128
            )
            for key, values in form.items():
                if values:
                    params[key] = values[-1]
        except UnicodeDecodeError:
            pass
    return params


def extract_userid(path: str, headers: Any, body: bytes) -> str:
    params = extract_params(path, headers, body)
    candidates: set[str] = set()
    for key in ("userid", "character_id", "auth_userid"):
        value = params.get(key)
        if isinstance(value, str):
            candidate = value.strip().lower()
            if valid_userid(candidate):
                candidates.add(candidate)
    txd = params.get("txd")
    if isinstance(txd, str):
        candidate = decode_txd_userid(urllib.parse.unquote_plus(txd))
        if valid_userid(candidate):
            candidates.add(candidate)
    if len(candidates) > 1:
        raise ValueError("conflicting request user identities")
    return next(iter(candidates), "")


def account_identity_matches(account_id: str, token_account: str) -> bool:
    return not token_account or token_account == account_id


def extract_account_id(path: str, headers: Any, body: bytes) -> str:
    value = extract_params(path, headers, body).get("account_id")
    if isinstance(value, str):
        candidate = value.strip().lower()
        if valid_userid(candidate):
            return candidate
    return ""


def extract_account_token(path: str, headers: Any, body: bytes) -> str:
    value = extract_params(path, headers, body).get("token")
    if isinstance(value, str):
        candidate = value.strip().lower()
        if len(candidate) == 64 and all(one in "0123456789abcdef" for one in candidate):
            return candidate
    return ""


def extract_game_command(path: str, headers: Any, body: bytes) -> str:
    value = extract_params(path, headers, body).get("cmd")
    return value.strip().lower() if isinstance(value, str) else ""


def request_content_length(headers: Any) -> int:
    """Reject ambiguous framing which BaseHTTPRequestHandler cannot decode."""
    transfer_encoding = (headers.get("Transfer-Encoding") or "").strip()
    if transfer_encoding:
        raise ValueError("Transfer-Encoding is unsupported")
    values = headers.get_all("Content-Length") if hasattr(headers, "get_all") else None
    if values is None:
        raw = headers.get("Content-Length")
        values = [] if raw is None else [raw]
    if len(values) > 1:
        raise ValueError("multiple Content-Length headers")
    try:
        content_length = int(values[0]) if values else 0
    except (TypeError, ValueError) as exc:
        raise ValueError("invalid Content-Length") from exc
    if content_length < 0 or content_length > MAX_BODY_BYTES:
        raise ValueError("request body too large")
    return content_length


def auction_command(command: str) -> bool:
    first = command.split(" ", 1)[0] if command else ""
    return first == "vendue" or first.startswith("vendue_")


def active_trial_authorized() -> bool:
    """Active traffic remains an explicit isolated-test-only capability."""
    return (
        os.environ.get("XIAND_MAP_WORKER_SHADOW", "") == "1"
        or os.environ.get("XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK", "")
        == "isolated-test-server-only"
    )


def response_header_allowed(name: str) -> bool:
    """Avoid hop-by-hop, internal and gateway-generated duplicate headers."""
    lowered = name.lower()
    return (
        lowered not in HOP_BY_HOP_HEADERS
        and not lowered.startswith("x-xiand-")
        and lowered not in {"server", "date"}
    )


@dataclass(frozen=True)
class ProxyResponse:
    status: int
    reason: str
    headers: list[tuple[str, str]]
    body: bytes


def migration_delivery_plan(
    source_worker: str,
    migration: tuple[str, int, bool, str] | None,
    before_command: bool,
) -> tuple[bool, bool]:
    """Return (deliver_arrival, replace_response) for one reconciliation.

    A migration discovered before a new command must finish a cross-worker
    arrival first and then execute the new command once.  A migration caused by
    the command itself consumes the second proxy only as its arrival response.
    Same-worker redirects need that response only in the post-command phase.
    """
    if not migration:
        return False, False
    cross_worker = migration[0] != source_worker
    redirect_response = bool(migration[2])
    if before_command:
        return cross_worker, False
    return cross_worker or redirect_response, redirect_response


class CoordinatorClient:
    def __init__(self, endpoint: str, token: str, timeout: float) -> None:
        self.endpoint = endpoint.rstrip("/")
        self.token = token
        self.timeout = timeout

    def call(self, action: str, **params: Any) -> dict[str, Any]:
        payload = dict(params)
        payload["action"] = action
        request = urllib.request.Request(
            self.endpoint + "/internal/map-worker",
            data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "X-Xiand-Worker-Token": self.token,
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                decoded = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            try:
                decoded = json.loads(exc.read().decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                decoded = {"ok": 0, "code": f"coordinator_http_{exc.code}"}
        except (OSError, urllib.error.URLError, UnicodeDecodeError,
                json.JSONDecodeError) as exc:
            raise RuntimeError(f"coordinator unavailable: {exc}") from exc
        if not isinstance(decoded, dict):
            raise RuntimeError("coordinator returned a non-object response")
        return decoded


class WorkerPool:
    def __init__(
        self,
        workers: dict[str, str],
        coordinator: CoordinatorClient,
        token: str,
        timeout: float,
    ) -> None:
        self.workers = workers
        self.coordinator = coordinator
        self.token = token
        self.timeout = timeout
        self.generations: dict[str, int] = {}
        self._worker_reachable = {worker_id: False for worker_id in workers}
        self._primary = sorted(workers)[0]
        self._stop = threading.Event()
        self._routing_ready = threading.Event()
        self._cluster_recovery_lock = threading.Lock()
        self._request_condition = threading.Condition()
        self._active_requests = 0
        self._uncertain_requests: set[tuple[str, str]] = set()
        self._uncertain_done: set[tuple[str, str]] = set()
        self._pending_reconcile_lock = threading.Lock()
        self._pending_reconcile_users: set[str] = set()
        # A fixed stripe table bounds memory while serializing one character's
        # request, handoff and replay as a single gateway transaction.
        self._user_locks = [threading.Lock() for _ in range(4096)]
        self._identity_lock = threading.Lock()
        self._account_management_lock = threading.Lock()
        self._auction_lock = threading.Lock()
        self._last_auction_tick = time.monotonic()
        self._account_by_user: dict[str, str] = {}
        self._account_by_token: dict[str, tuple[str, float]] = {}
        self._account_last_worker: dict[str, str] = {}
        self._account_cache_epoch: dict[str, int] = {}
        self._background_arrivals: dict[str, tuple[str, int, str, str]] = {}
        self._controller_nonce = os.urandom(16).hex()
        self._shadow = os.environ.get("XIAND_MAP_WORKER_SHADOW", "") == "1"
        self._lease_gc_interval = env_int(
            "XIAND_MAP_WORKER_LEASE_GC_SECONDS", 3600, 300, 86400
        )
        self._monitor = threading.Thread(
            target=self._monitor_workers, name="map-worker-monitor", daemon=True
        )
        self._auction_scheduler = threading.Thread(
            target=self._run_auction_scheduler,
            name="map-worker-auction-scheduler",
            daemon=True,
        )
        self._async_handoff_scheduler = threading.Thread(
            target=self._run_async_handoff_scheduler,
            name="map-worker-async-handoff",
            daemon=True,
        )
        self._lease_gc_scheduler = threading.Thread(
            target=self._run_lease_gc_scheduler,
            name="map-worker-lease-gc",
            daemon=True,
        )

    def start(self) -> None:
        self._register_all()
        self._sync_catalog()
        self._recover_local_players()
        self._routing_ready.set()
        self._monitor.start()
        self._async_handoff_scheduler.start()
        self._lease_gc_scheduler.start()
        if not self._shadow:
            self._auction_scheduler.start()

    def stop(self) -> None:
        self._routing_ready.clear()
        self._stop.set()
        if self._monitor.is_alive():
            self._monitor.join(timeout=3)
        if self._async_handoff_scheduler.is_alive():
            self._async_handoff_scheduler.join(timeout=3)
        if self._lease_gc_scheduler.is_alive():
            self._lease_gc_scheduler.join(timeout=3)
        if self._auction_scheduler.is_alive():
            self._auction_scheduler.join(timeout=3)

    def _worker_call(
        self, target_worker: str, action: str, **params: Any
    ) -> dict[str, Any]:
        # `worker_id` is also a legitimate field inside several RPC payloads.
        # Keep the transport destination name distinct so assignment updates
        # cannot collide with Python argument binding on first login.
        endpoint = self.workers[target_worker]
        payload = dict(params)
        payload["action"] = action
        request = urllib.request.Request(
            endpoint + "/internal/map-worker",
            data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "X-Xiand-Worker-Token": self.token,
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                decoded = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            try:
                decoded = json.loads(exc.read().decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                decoded = {"ok": 0, "code": f"worker_http_{exc.code}"}
        except (OSError, urllib.error.URLError, UnicodeDecodeError,
                json.JSONDecodeError) as exc:
            raise RuntimeError(f"worker {target_worker} unavailable: {exc}") from exc
        if not isinstance(decoded, dict):
            raise RuntimeError("worker returned a non-object response")
        return decoded

    def _register_all(self) -> None:
        incarnation = f"gateway-{os.getpid()}-{int(time.time())}"
        capacity = env_int("XIAND_WORKER_CAPACITY", 100, 10, 10000)
        for worker_id, endpoint in self.workers.items():
            result = self.coordinator.call(
                "register",
                worker_id=worker_id,
                endpoint=endpoint,
                capacity=capacity,
                incarnation=incarnation + "-" + worker_id,
            )
            if not result.get("ok"):
                raise RuntimeError(f"cannot register {worker_id}: {result}")
            self.generations[worker_id] = int(result["generation"])

    def _sync_catalog(self) -> None:
        catalog = self.coordinator.call("assign_catalog", force=0)
        if not catalog.get("ok"):
            raise RuntimeError(f"cannot assign map catalog: {catalog}")
        status = self.coordinator.call("status")
        if not status.get("ok"):
            raise RuntimeError(f"cannot read map catalog: {status}")
        generation = int(status.get("placement_generation", 0))
        owners = {
            str(item["affinity"]): str(item["worker_id"])
            for item in status.get("placements", [])
            if isinstance(item, dict) and item.get("affinity") and item.get("worker_id")
        }
        if generation < 1 or not owners:
            raise RuntimeError("coordinator returned an empty placement catalog")
        for worker_id in self.workers:
            result = self._worker_call(
                worker_id,
                "local_assignments",
                owners=owners,
                generation=generation,
            )
            if not result.get("ok"):
                raise RuntimeError(
                    f"cannot install placement catalog on {worker_id}: {result}"
                )

    def _sync_assignment(self, affinity: str, placement: dict[str, Any]) -> None:
        owner = str(placement.get("worker_id") or "")
        generation = int(placement.get("placement_generation", 0))
        if not affinity or owner not in self.workers or generation < 1:
            raise RuntimeError(f"invalid affinity placement: {placement}")
        for worker_id in self.workers:
            result = self._worker_call(
                worker_id,
                "local_assignment",
                affinity=affinity,
                worker_id=owner,
                generation=generation,
            )
            if not result.get("ok"):
                raise RuntimeError(
                    f"cannot update {affinity} on {worker_id}: {result}"
                )

    def _recover_local_players(self) -> None:
        inventoried: dict[str, list[tuple[str, str, int]]] = {}
        for worker_id in self.workers:
            inflight = self._worker_call(worker_id, "local_inflight")
            if not inflight.get("ok") or int(inflight.get("count") or 0):
                raise RuntimeError(
                    f"worker {worker_id} has unresolved requests: {inflight}"
                )
            inventory = self._worker_call(worker_id, "local_inventory")
            if not inventory.get("ok") or not isinstance(inventory.get("players"), list):
                raise RuntimeError(f"cannot inventory {worker_id}: {inventory}")
            for item in inventory["players"]:
                if not isinstance(item, dict):
                    raise RuntimeError(f"invalid inventory entry from {worker_id}")
                userid = str(item.get("userid") or "")
                affinity = str(item.get("affinity") or "")
                account_id = str(item.get("account_id") or "")
                local_epoch = int(item.get("lease_epoch") or 0)
                if not valid_userid(userid) or not affinity:
                    raise RuntimeError(f"invalid local player on {worker_id}")
                inventoried.setdefault(userid, []).append(
                    (worker_id, affinity, local_epoch)
                )
                if valid_userid(account_id):
                    self.record_account(userid, account_id)
        recovered: dict[str, tuple[str, str, int]] = {}
        for userid, copies in inventoried.items():
            if len(copies) == 1:
                recovered[userid] = copies[0]
                continue
            # Never let two split-brain copies each perform the worker's final
            # save. Drop every in-memory copy without persistence, then let a
            # later fenced login reload the last atomic character file.
            for worker_id, _affinity, local_epoch in copies:
                discarded = self._worker_call(
                    worker_id,
                    "local_discard",
                    userid=userid,
                    epoch=local_epoch,
                )
                if not discarded.get("ok"):
                    raise RuntimeError(
                        f"cannot discard duplicate {userid} on {worker_id}: "
                        f"{discarded}"
                    )
            route = self.coordinator.call("route", userid=userid)
            if route.get("ok") and route.get("state") == "frozen" and \
                    route.get("handoff_request_id"):
                aborted = self.coordinator.call(
                    "handoff_abort",
                    request_id=str(route["handoff_request_id"]),
                    source_worker=str(route.get("worker_id") or ""),
                )
                if not aborted.get("ok"):
                    raise RuntimeError(
                        f"cannot thaw duplicate lease for {userid}: {aborted}"
                    )
            print(
                f"[map-gateway] discarded {len(copies)} duplicate live "
                f"copies for {userid}; disk snapshot remains authoritative",
                file=sys.stderr,
            )
        for userid, (worker_id, affinity, _local_epoch) in recovered.items():
            route = self.coordinator.call("route", userid=userid)
            if (
                route.get("ok")
                and route.get("state") == "frozen"
                and route.get("worker_id") == worker_id
                and route.get("handoff_request_id")
            ):
                aborted = self.coordinator.call(
                    "handoff_abort",
                    request_id=str(route["handoff_request_id"]),
                    source_worker=worker_id,
                )
                if not aborted.get("ok"):
                    raise RuntimeError(
                        f"cannot roll back frozen lease for {userid}: {aborted}"
                    )
                route = self.coordinator.call("route", userid=userid)
            result: dict[str, Any]
            if (
                route.get("ok")
                and route.get("state") == "active"
                and route.get("worker_id") == worker_id
                and (_local_epoch == 0 or _local_epoch == int(route["epoch"]))
            ):
                if str(route.get("affinity") or "") == affinity:
                    renewed = self.coordinator.call(
                        "lease_renew",
                        userid=userid,
                        worker_id=worker_id,
                        epoch=int(route["epoch"]),
                    )
                    result = dict(route) if renewed.get("ok") else {}
                else:
                    placement = self.coordinator.call(
                        "assign_affinity", affinity=affinity, weight=1, force=0
                    )
                    if not placement.get("ok"):
                        raise RuntimeError(
                            f"cannot restore affinity for {userid}: {placement}"
                        )
                    self._sync_assignment(affinity, placement)
                    if str(placement.get("worker_id") or "") != worker_id:
                        raise RuntimeError(
                            f"live {userid} is on the wrong affinity owner"
                        )
                    result = self.coordinator.call(
                        "lease_rebind",
                        userid=userid,
                        worker_id=worker_id,
                        epoch=int(route["epoch"]),
                        affinity=affinity,
                    )
            else:
                result = self.coordinator.call(
                    "lease_recover",
                    userid=userid,
                    worker_id=worker_id,
                    affinity=affinity,
                )
            if not result.get("ok"):
                raise RuntimeError(f"cannot recover lease for {userid}: {result}")
            installed = self._worker_call(
                worker_id,
                "local_epoch",
                userid=userid,
                epoch=int(result["epoch"]),
            )
            if not installed.get("ok"):
                raise RuntimeError(
                    f"cannot install recovered epoch for {userid}: {installed}"
                )
        prune = self._prune_reconciled_tombstones(sorted(recovered))
        if int(prune.get("pruned_assignments") or 0):
            self._sync_catalog()
        for worker_id in self.workers:
            resumed = self._worker_call(worker_id, "local_control_resume")
            if not resumed.get("ok"):
                raise RuntimeError(f"cannot resume reconciled {worker_id}: {resumed}")
            self._worker_reachable[worker_id] = True

    def _prune_reconciled_tombstones(self, live_users: list[str]) -> dict[str, Any]:
        """GC only after the caller completed a stopped, all-worker inventory."""
        reconciliation_id = secrets.token_hex(32)
        begun = self.coordinator.call(
            "lease_reconcile_begin", reconciliation_id=reconciliation_id
        )
        if not begun.get("ok"):
            raise RuntimeError(f"cannot begin lease reconciliation: {begun}")
        for offset in range(0, len(live_users), 500):
            added = self.coordinator.call(
                "lease_reconcile_add",
                reconciliation_id=reconciliation_id,
                users=live_users[offset:offset + 500],
            )
            if not added.get("ok"):
                raise RuntimeError(f"cannot upload lease inventory: {added}")
        committed = self.coordinator.call(
            "lease_reconcile_commit", reconciliation_id=reconciliation_id
        )
        if not committed.get("ok"):
            raise RuntimeError(f"cannot commit lease reconciliation: {committed}")
        return committed

    def _run_lease_gc_once(self) -> None:
        """Quiesce traffic before pruning expired ownership tombstones."""
        with self._cluster_recovery_lock:
            self._pause_routing()
            self._recover_local_players()
            self._resume_routing()

    def _run_lease_gc_scheduler(self) -> None:
        """Bound first-login session placements during long-running trials."""
        while not self._stop.wait(self._lease_gc_interval):
            if not self._routing_ready.is_set():
                continue
            try:
                self._run_lease_gc_once()
            except (
                OSError,
                urllib.error.URLError,
                RuntimeError,
                json.JSONDecodeError,
            ) as exc:
                # _run_lease_gc_once intentionally leaves routing paused on
                # failure. The monitor will retry a full fenced recovery.
                print(
                    f"[map-gateway] lease GC recovery failed: {exc}",
                    file=sys.stderr,
                )

    def _reconcile_recovered_worker(self, worker_id: str) -> None:
        """Discard stale split-brain copies before a recovered worker serves."""
        inflight = self._worker_call(worker_id, "local_inflight")
        if not inflight.get("ok") or int(inflight.get("count") or 0):
            raise RuntimeError(
                f"recovered {worker_id} has unresolved requests: {inflight}"
            )
        inventory = self._worker_call(worker_id, "local_inventory")
        players = inventory.get("players")
        if not inventory.get("ok") or not isinstance(players, list):
            raise RuntimeError(f"cannot inventory recovered {worker_id}: {inventory}")
        for item in players:
            if not isinstance(item, dict):
                raise RuntimeError(f"invalid inventory entry from {worker_id}")
            userid = str(item.get("userid") or "")
            affinity = str(item.get("affinity") or "")
            local_epoch = int(item.get("lease_epoch") or 0)
            if not valid_userid(userid) or not affinity:
                raise RuntimeError(f"invalid local player on recovered {worker_id}")
            route = self.coordinator.call("route", userid=userid)
            if (
                route.get("ok")
                and route.get("state") == "frozen"
                and route.get("worker_id") == worker_id
                and route.get("handoff_request_id")
            ):
                aborted = self.coordinator.call(
                    "handoff_abort",
                    request_id=str(route["handoff_request_id"]),
                    source_worker=worker_id,
                )
                if aborted.get("ok"):
                    route = self.coordinator.call("route", userid=userid)
            coordinator_epoch = int(route.get("epoch") or 0)
            exact_owner = (
                route.get("ok")
                and route.get("state") == "active"
                and route.get("worker_id") == worker_id
                and route.get("affinity") == affinity
                and (local_epoch == 0 or local_epoch == coordinator_epoch)
            )
            if exact_owner:
                renewed = self.coordinator.call(
                    "lease_renew",
                    userid=userid,
                    worker_id=worker_id,
                    epoch=coordinator_epoch,
                )
                installed = self._worker_call(
                    worker_id,
                    "local_epoch",
                    userid=userid,
                    epoch=coordinator_epoch,
                )
                if renewed.get("ok") and installed.get("ok"):
                    continue
            discarded = self._worker_call(
                worker_id,
                "local_discard",
                userid=userid,
                epoch=local_epoch,
            )
            if not discarded.get("ok"):
                raise RuntimeError(
                    f"cannot discard stale {userid} on {worker_id}: {discarded}"
                )
        resumed = self._worker_call(worker_id, "local_control_resume")
        if not resumed.get("ok"):
            raise RuntimeError(f"cannot resume recovered {worker_id}: {resumed}")

    def _monitor_workers(self) -> None:
        while not self._stop.wait(5):
            for worker_id in self.workers:
                self._monitor_worker(worker_id)

    def _monitor_worker(self, worker_id: str) -> None:
        """Renew or recover one worker only after coordinator generation ACK."""
        metrics = self._collect_worker_metrics(worker_id)
        if metrics is None:
            # Do not refresh a dead node's coordinator heartbeat. Its TTL must
            # expire so new affinities stop targeting it.
            self._worker_reachable[worker_id] = False
            return
        generation = self.generations.get(worker_id, 0)
        if not generation:
            self._worker_reachable[worker_id] = False
            return
        try:
            result = self.coordinator.call(
                "heartbeat",
                worker_id=worker_id,
                generation=generation,
                metrics=metrics,
            )
            if result.get("code") == "stale_generation":
                with self._cluster_recovery_lock:
                    self._pause_routing()
                    self._register_all()
                    self._sync_catalog()
                    self._recover_local_players()
                    # Never reopen in a finally block: partial recovery is not
                    # routing authority. A failure leaves the gate closed for
                    # the next monitor cycle to reconcile again.
                    self._resume_routing()
                return
            if not result.get("ok"):
                self._worker_reachable[worker_id] = False
                return

            # An empty local inventory is not proof of coordinator authority.
            # The exact generation ACK above must happen before any recovery
            # path is allowed to call local_control_resume.
            if not self._worker_reachable.get(worker_id, False):
                with self._cluster_recovery_lock:
                    self._pause_routing()
                    self._reconcile_recovered_worker(worker_id)
                    self._worker_reachable[worker_id] = True
                    self._resume_routing()
                return
            self._renew_live_player_leases(worker_id, generation)
            control = self._worker_call(
                worker_id, "local_control_heartbeat"
            )
            if not control.get("ok"):
                self._worker_reachable[worker_id] = False
        except (OSError, urllib.error.URLError, RuntimeError,
                json.JSONDecodeError):
            # A reachable worker is not writable authority when the coordinator
            # cannot prove this exact generation. Stop control heartbeats so it
            # self-fences within its TTL. In particular, never run empty-worker
            # recovery first because it would otherwise thaw the control lease.
            self._worker_reachable[worker_id] = False

    def _renew_live_player_leases(self, worker_id: str, generation: int) -> None:
        """Verify and renew every live local owner in bounded RPC pages."""
        offset = 0
        # At most 20,000 local lease owners exist in Pike.  The extra page
        # permits a final empty/done response while still fencing bad cursors.
        for _page in range(158):
            local = self._worker_call(
                worker_id, "local_live_leases", offset=offset, limit=128
            )
            leases = local.get("leases")
            if not local.get("ok") or not isinstance(leases, list):
                raise RuntimeError(f"invalid live-lease page: {local}")
            if len(leases) > 128:
                raise RuntimeError("worker exceeded live-lease page limit")
            lock_groups: dict[int, tuple[threading.Lock, list[dict[str, Any]]]] = {}
            for entry in leases:
                if not isinstance(entry, dict):
                    raise RuntimeError("worker returned invalid live lease")
                userid = str(entry.get("userid") or "")
                account_id = str(entry.get("account_id") or "")
                if not valid_userid(userid) or not valid_userid(account_id):
                    raise RuntimeError("worker returned invalid live identity")
                lock = self.user_lock(userid, account_id)
                group = lock_groups.setdefault(id(lock), (lock, []))
                group[1].append(entry)
            acquired: list[threading.Lock] = []
            candidates: list[dict[str, Any]] = []
            try:
                # Never block the only control-heartbeat thread behind a long
                # player command. That command already renewed its lease under
                # this same gateway lock before entering the worker.
                for lock, entries_for_lock in lock_groups.values():
                    if lock.acquire(blocking=False):
                        acquired.append(lock)
                        candidates.extend(entries_for_lock)
                refreshed = self._worker_call(
                    worker_id, "local_live_leases", offset=offset, limit=128
                )
                refreshed_leases = refreshed.get("leases")
                if (
                    not refreshed.get("ok")
                    or not isinstance(refreshed_leases, list)
                    or len(refreshed_leases) > 128
                ):
                    raise RuntimeError(f"invalid refreshed lease page: {refreshed}")
                refreshed_capabilities = {
                    (
                        str(item.get("userid") or ""),
                        str(item.get("account_id") or ""),
                        int(item.get("epoch") or 0),
                        str(item.get("affinity") or ""),
                    )
                    for item in refreshed_leases
                    if isinstance(item, dict)
                }
                verified = [
                    {
                        "userid": str(item.get("userid") or ""),
                        "epoch": int(item.get("epoch") or 0),
                        "affinity": str(item.get("affinity") or ""),
                    }
                    for item in candidates
                    if (
                        str(item.get("userid") or ""),
                        str(item.get("account_id") or ""),
                        int(item.get("epoch") or 0),
                        str(item.get("affinity") or ""),
                    ) in refreshed_capabilities
                ]
                if verified:
                    renewed = self.coordinator.call(
                        "lease_renew_batch",
                        worker_id=worker_id,
                        generation=generation,
                        leases=verified,
                    )
                    if (
                        not renewed.get("ok")
                        or int(renewed.get("count") or 0) != len(verified)
                    ):
                        raise RuntimeError(
                            f"live lease renewal rejected: {renewed}"
                        )
            finally:
                for lock in reversed(acquired):
                    lock.release()
            next_offset = int(refreshed.get("next_offset") or 0)
            if refreshed.get("done"):
                return
            if (
                next_offset <= offset
                or next_offset != offset + len(refreshed_leases)
            ):
                raise RuntimeError("worker returned a non-progressing lease page")
            offset = next_offset
        raise RuntimeError("worker live-lease inventory exceeded hard limit")

    def _run_auction_scheduler(self) -> None:
        """Keep potentially slow SQL settlement away from heartbeat polling."""
        if self._shadow:
            return
        while not self._stop.wait(5):
            if (
                not self._worker_reachable.get(self._primary, False)
                or time.monotonic() - self._last_auction_tick < 1200
                or not self._auction_lock.acquire(blocking=False)
            ):
                continue
            self._last_auction_tick = time.monotonic()
            try:
                self._worker_call(self._primary, "local_auction_tick")
            except (OSError, urllib.error.URLError, RuntimeError,
                    json.JSONDecodeError):
                pass
            finally:
                self._auction_lock.release()

    def _deliver_background_arrival(
        self, userid: str, worker_id: str, epoch: int, room_path: str,
        account_id: str,
    ) -> None:
        """Restore the sole saved copy after a timer-triggered handoff."""
        if (
            not valid_userid(userid)
            or worker_id not in self.workers
            or epoch < 1
            or not room_path.startswith("/gamelib/d/")
            or "#" in room_path
            or not valid_userid(account_id)
        ):
            raise RuntimeError("invalid background arrival capability")
        result = self._worker_call(
            worker_id,
            "local_arrival",
            userid=userid,
            epoch=epoch,
            room_path=room_path,
            account_owner=account_id,
            account_cache_token=self.account_cache_token(account_id, worker_id),
        )
        if not result.get("ok"):
            raise RuntimeError(f"background arrival failed: {result}")
        affinity, pending_room = self.confirmed_route(userid, worker_id, epoch)
        if pending_room != room_path or str(result.get("affinity") or "") != affinity:
            raise RuntimeError("background arrival route mismatch")
        self.acknowledge_arrival(userid, worker_id, epoch, affinity, room_path)
        _affinity, pending_room = self.confirmed_route(userid, worker_id, epoch)
        if pending_room:
            raise RuntimeError("background arrival acknowledgement remains pending")

    def _settle_background_move(
        self, source_worker: str, item: dict[str, Any],
    ) -> None:
        userid = str(item.get("userid") or "").strip().lower()
        account_id = str(item.get("account_id") or "").strip().lower()
        source_epoch = int(item.get("lease_epoch") or 0)
        if (
            source_worker not in self.workers
            or not valid_userid(userid)
            or not valid_userid(account_id)
            or source_epoch < 1
        ):
            raise RuntimeError("worker returned invalid pending movement")
        self.record_account(userid, account_id)
        with self.user_lock(userid, account_id):
            self.ensure_routing_ready()
            route = self.coordinator.call("route", userid=userid)
            if (
                not route.get("ok")
                or route.get("state") != "active"
                or route.get("worker_id") != source_worker
                or int(route.get("epoch") or 0) != source_epoch
            ):
                return
            migration = self.reconcile(
                userid,
                source_worker,
                source_epoch,
                str(route.get("affinity") or ""),
                require_settled=True,
            )
            if not migration:
                return
            target_worker, target_epoch, _redirect, room_path = migration
            if target_worker == source_worker:
                return
            self._background_arrivals[userid] = (
                target_worker, target_epoch, room_path, account_id
            )
            self._deliver_background_arrival(
                userid, target_worker, target_epoch, room_path, account_id
            )
            self._background_arrivals.pop(userid, None)

    def _retry_background_arrival(
        self, userid: str, pending: tuple[str, int, str, str],
    ) -> None:
        worker_id, epoch, room_path, account_id = pending
        with self.user_lock(userid, account_id):
            self.ensure_routing_ready()
            route = self.coordinator.call("route", userid=userid)
            if (
                not route.get("ok")
                or route.get("state") != "active"
                or route.get("worker_id") != worker_id
                or int(route.get("epoch") or 0) != epoch
            ):
                return
            authoritative_room = str(route.get("arrival_room_path") or "")
            if not authoritative_room:
                self._background_arrivals.pop(userid, None)
                return
            if authoritative_room != room_path:
                raise RuntimeError("background arrival capability changed")
            self._deliver_background_arrival(
                userid, worker_id, epoch, room_path, account_id
            )
            self._background_arrivals.pop(userid, None)

    def _run_async_handoff_scheduler(self) -> None:
        """Converge moves raised by heartbeat/autofight without browser I/O."""
        while not self._stop.wait(1):
            if not self._routing_ready.is_set():
                continue
            for userid, pending in list(self._background_arrivals.items()):
                request_entered = False
                try:
                    self.begin_request()
                    request_entered = True
                    self._retry_background_arrival(userid, pending)
                except (OSError, urllib.error.URLError, RuntimeError,
                        json.JSONDecodeError) as exc:
                    print(
                        f"[map-gateway] background arrival retry failed for "
                        f"{userid}: {exc}", file=sys.stderr,
                    )
                finally:
                    if request_entered:
                        self.end_request()
            for worker_id in self.workers:
                if not self._worker_reachable.get(worker_id, False):
                    continue
                try:
                    result = self._worker_call(worker_id, "local_pending_routes")
                    pending_routes = result.get("pending")
                    if not result.get("ok") or not isinstance(pending_routes, list):
                        raise RuntimeError("invalid pending-route response")
                except (OSError, urllib.error.URLError, RuntimeError,
                        json.JSONDecodeError):
                    continue
                for item in pending_routes:
                    if not isinstance(item, dict):
                        continue
                    request_entered = False
                    try:
                        self.begin_request()
                        request_entered = True
                        self._settle_background_move(worker_id, item)
                    except (OSError, urllib.error.URLError, RuntimeError,
                            json.JSONDecodeError) as exc:
                        print(
                            f"[map-gateway] background handoff failed on "
                            f"{worker_id}: {exc}", file=sys.stderr,
                        )
                    finally:
                        if request_entered:
                            self.end_request()

    def _collect_worker_metrics(self, worker_id: str) -> dict[str, int] | None:
        try:
            local = self._worker_call(worker_id, "local_status")
        except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError):
            return None
        if not local.get("ok"):
            return None
        return {
            "active_players": int(local.get("active_players", 0)),
            "active_rooms": int(local.get("active_rooms", 0)),
            "pending_commands": int(local.get("pending_commands", 0)),
            "heartbeat_ms": int(local.get("heartbeat_ms", 0)),
        }

    def _lease_for_new_user(self, userid: str) -> tuple[str, int, str, str]:
        affinity = "session:" + hashlib.sha256(userid.encode("utf-8")).hexdigest()[:24]
        placement = self.coordinator.call(
            "assign_affinity", affinity=affinity, weight=1, force=0
        )
        if not placement.get("ok"):
            raise RuntimeError(f"no worker placement: {placement}")
        self._sync_assignment(affinity, placement)
        worker_id = str(placement["worker_id"])
        lease = self.coordinator.call(
            "lease_acquire", userid=userid, worker_id=worker_id, affinity=affinity
        )
        if not lease.get("ok"):
            raise RuntimeError(f"cannot acquire player lease: {lease}")
        return worker_id, int(lease["epoch"]), affinity, ""

    def begin_request(self) -> None:
        with self._request_condition:
            if not self._routing_ready.is_set():
                raise RuntimeError("worker recovery is in progress")
            self._active_requests += 1

    def ensure_routing_ready(self) -> None:
        """Reject requests queued behind a lock after routing was paused."""
        with self._request_condition:
            if not self._routing_ready.is_set():
                raise RuntimeError("worker recovery is in progress")

    def mark_reconciliation_pending(self, userid: str) -> None:
        """Fence only users whose preceding command may need route repair."""
        if not valid_userid(userid):
            return
        with self._pending_reconcile_lock:
            if (
                userid not in self._pending_reconcile_users
                and len(self._pending_reconcile_users) >= 20000
            ):
                # Never evict a safety fence to save memory. A gateway recovery
                # is required before accepting more potentially stale routes.
                self._routing_ready.clear()
                return
            self._pending_reconcile_users.add(userid)

    def reconciliation_pending(self, userid: str) -> bool:
        with self._pending_reconcile_lock:
            return userid in self._pending_reconcile_users

    def clear_reconciliation_pending(self, userid: str) -> None:
        with self._pending_reconcile_lock:
            self._pending_reconcile_users.discard(userid)

    def end_request(self) -> None:
        with self._request_condition:
            self._active_requests = max(0, self._active_requests - 1)
            if self._active_requests == 0:
                self._request_condition.notify_all()

    def _pause_routing(self) -> None:
        with self._request_condition:
            self._routing_ready.clear()
            while self._active_requests and not self._stop.is_set():
                self._request_condition.wait(timeout=1)

    def _resume_routing(self) -> None:
        with self._request_condition:
            if not self._uncertain_requests:
                self._routing_ready.set()
            self._request_condition.notify_all()

    def quarantine_uncertain_request(self, worker_id: str, request_id: str) -> None:
        request = (worker_id, request_id)
        with self._request_condition:
            if request in self._uncertain_requests:
                return
            self._uncertain_requests.add(request)
            self._routing_ready.clear()
        threading.Thread(
            target=self._resolve_uncertain_request,
            args=request,
            name=f"map-worker-uncertain-{request_id[:8]}",
            daemon=True,
        ).start()

    def _resolve_uncertain_request(self, worker_id: str, request_id: str) -> None:
        request = (worker_id, request_id)
        while not self._stop.wait(1):
            try:
                status = self._worker_call(
                    worker_id, "local_request_status", request_id=request_id
                )
            except (OSError, urllib.error.URLError, RuntimeError,
                    json.JSONDecodeError):
                continue
            if not status.get("ok") and status.get("code") != "unknown_request":
                continue
            if status.get("ok") and status.get("state") != "done":
                continue
            with self._request_condition:
                self._uncertain_done.add(request)
                all_done = self._uncertain_done == self._uncertain_requests
            if not all_done:
                return
            with self._cluster_recovery_lock:
                self._pause_routing()
                try:
                    self._recover_local_players()
                except (OSError, urllib.error.URLError, RuntimeError,
                        json.JSONDecodeError):
                    continue
                with self._request_condition:
                    self._uncertain_requests.clear()
                    self._uncertain_done.clear()
                self._resume_routing()
                return

    def _wait_for_request_done(self, worker_id: str, request_id: str) -> None:
        """Keep transaction locks until the worker has run request finalizers."""
        deadline = time.monotonic() + self.timeout
        while True:
            status = self._worker_call(
                worker_id, "local_request_status", request_id=request_id
            )
            if status.get("ok") and status.get("state") == "done":
                return
            if not status.get("ok") or status.get("state") != "running":
                raise RuntimeError(
                    f"worker cannot prove request completion: {status}"
                )
            if time.monotonic() >= deadline:
                raise RuntimeError("worker request finalization timed out")
            time.sleep(0.005)

    def route_user(self, userid: str) -> tuple[str, int, str, str]:
        route = self.coordinator.call("route", userid=userid)
        if route.get("ok") and route.get("worker_id") in self.workers:
            if route.get("state") == "frozen":
                raise RuntimeError("player handoff is in progress")
            worker_id = str(route["worker_id"])
            epoch = int(route["epoch"])
            renewed = self.coordinator.call(
                "lease_renew", userid=userid, worker_id=worker_id, epoch=epoch
            )
            if renewed.get("ok"):
                return (
                    worker_id,
                    epoch,
                    str(route.get("affinity") or ""),
                    str(route.get("arrival_room_path") or ""),
                )
        if route.get("code") == "lease_missing":
            return self._lease_for_new_user(userid)
        if route.get("code") == "lease_expired":
            if route.get("state") == "frozen":
                raise RuntimeError("player handoff is in progress")
            old_worker = str(route.get("worker_id") or "")
            old_affinity = str(route.get("affinity") or "")
            old_epoch = int(route.get("epoch") or 0)
            if old_worker not in self.workers or not old_affinity or old_epoch < 1:
                raise RuntimeError("expired player lease requires inventory recovery")
            reopened = self.coordinator.call(
                "lease_acquire",
                userid=userid,
                worker_id=old_worker,
                affinity=old_affinity,
                expected_epoch=old_epoch,
            )
            if not reopened.get("ok"):
                raise RuntimeError(
                    f"expired player lease cannot safely reopen: {reopened}"
                )
            return (
                old_worker,
                int(reopened["epoch"]),
                old_affinity,
                str(reopened.get("arrival_room_path") or ""),
            )
        return self._lease_for_new_user(userid)

    def proxy(
        self,
        worker_id: str,
        method: str,
        path: str,
        headers: Any,
        body: bytes,
        userid: str,
        epoch: int,
        arrival_room: str = "",
        account_id: str = "",
        command_kind: str = "general",
    ) -> ProxyResponse:
        endpoint = urllib.parse.urlsplit(self.workers[worker_id])
        connection = http.client.HTTPConnection(
            endpoint.hostname, endpoint.port, timeout=self.timeout
        )
        request_id = secrets.token_hex(32)
        request_may_be_running = False
        forwarded_headers: dict[str, str] = {}
        for key, value in headers.items():
            if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() not in {
                "host",
                "content-length",
            } and not key.lower().startswith("x-xiand-"):
                forwarded_headers[key] = value
        forwarded_headers["Host"] = endpoint.netloc
        forwarded_headers["Content-Length"] = str(len(body))
        forwarded_headers["X-Xiand-Worker-Token"] = self.token
        forwarded_headers["X-Xiand-Lease-Worker"] = worker_id
        forwarded_headers["X-Xiand-Lease-Userid"] = userid
        forwarded_headers["X-Xiand-Lease-Epoch"] = str(epoch)
        forwarded_headers["X-Xiand-Request-Id"] = request_id
        forwarded_headers["X-Xiand-Command-Kind"] = command_kind
        if arrival_room:
            forwarded_headers["X-Xiand-Arrival-Room"] = arrival_room
        if valid_userid(account_id):
            forwarded_headers["X-Xiand-Account-Owner"] = account_id
            forwarded_headers["X-Xiand-Account-Cache-Token"] = (
                self.account_cache_token(account_id, worker_id)
            )
        try:
            request_may_be_running = True
            connection.request(method, path, body=body, headers=forwarded_headers)
            response = connection.getresponse()
            response_body = response.read(MAX_BODY_BYTES + 1)
            if len(response_body) > MAX_BODY_BYTES:
                raise RuntimeError("worker response exceeded size limit")
            raw_response_headers = list(response.getheaders())
            accepted_request = next(
                (
                    value.strip().lower()
                    for key, value in raw_response_headers
                    if key.lower() == "x-xiand-request-accepted"
                ),
                "",
            )
            # The Pike response can reach the socket before its request-tail
            # wallet/save finalizers have finished.  Do not release the
            # account/user lock until the worker publishes the done fence.
            if accepted_request == request_id:
                self._wait_for_request_done(worker_id, request_id)
            elif response.status not in {403, 409, 413}:
                raise RuntimeError("worker response lacks request-fence proof")
            response_headers = [
                (key, value)
                for key, value in raw_response_headers
                if response_header_allowed(key)
            ]
            return ProxyResponse(
                response.status,
                response.reason,
                response_headers,
                response_body,
            )
        except (OSError, http.client.HTTPException, RuntimeError) as exc:
            if request_may_be_running:
                self.quarantine_uncertain_request(worker_id, request_id)
                raise UncertainProxyError(
                    f"uncertain worker request {request_id} on {worker_id}"
                ) from exc
            raise
        finally:
            connection.close()

    def reconcile(
        self,
        userid: str,
        source_worker: str,
        source_epoch: int,
        leased_affinity: str,
        require_settled: bool = False,
    ) -> tuple[str, int, bool, str] | None:
        local = self._worker_call(source_worker, "local_route", userid=userid)
        if not local.get("ok"):
            if local.get("code") == "player_not_local":
                return None
            if require_settled:
                raise RuntimeError(f"cannot inspect pending player route: {local}")
            return None
        if not local.get("handoff_safe"):
            if require_settled:
                raise RuntimeError("pending player route is not handoff-safe")
            return None
        account_id = str(local.get("account_id") or "")
        if valid_userid(account_id):
            self.record_account(userid, account_id)
        redirect = local.get("move_redirect")
        replay_request = isinstance(redirect, dict) and redirect.get("ok")
        affinity = str(
            redirect.get("target_affinity") if replay_request else local.get("affinity")
        )
        target_room_path = str(
            redirect.get("target_room_path") if replay_request else ""
        )
        local_room_path = str(local.get("room_path") or "")
        source_affinity = str(local.get("affinity") or "")
        if not affinity or not source_affinity:
            return None
        if replay_request and not target_room_path:
            # Dynamic clone rooms require an explicit instance reconstruction
            # protocol; never guess or clone them on another process.
            return None
        if not replay_request and source_affinity == leased_affinity:
            return None
        placement = self.coordinator.call(
            "assign_affinity", affinity=affinity, weight=1, force=0
        )
        if not placement.get("ok"):
            raise RuntimeError(f"cannot place reconciled affinity: {placement}")
        self._sync_assignment(affinity, placement)
        target_worker = str(placement["worker_id"])
        if target_worker == source_worker:
            if replay_request:
                completed = self._worker_call(
                    source_worker,
                    "local_redirect_complete",
                    userid=userid,
                    epoch=source_epoch,
                    room_path=target_room_path,
                )
                if not completed.get("ok"):
                    raise RuntimeError(
                        f"same-worker redirect failed: {completed}"
                    )
            rebound = self.coordinator.call(
                "lease_rebind",
                userid=userid,
                worker_id=source_worker,
                epoch=source_epoch,
                affinity=affinity,
            )
            if not rebound.get("ok"):
                raise RuntimeError(
                    f"same-worker lease rebind failed: {rebound}"
                )
            return (
                source_worker,
                source_epoch,
                bool(replay_request),
                target_room_path if replay_request else "",
            )
        if not replay_request:
            if (
                not local_room_path.startswith("/gamelib/d/")
                or "#" in local_room_path
            ):
                raise RuntimeError(
                    "dynamic instance crossed worker ownership without "
                    "a reconstruction protocol"
                )
            # A stale local assignment can let a static move finish just as a
            # new placement snapshot arrives. Persist and retire that sole
            # source object, then install it on the authoritative owner.
            target_room_path = local_room_path
        request_id = hashlib.sha256(
            f"{userid}|{source_worker}|{source_epoch}|{affinity}|"
            f"{target_room_path}".encode("utf-8")
        ).hexdigest()[:48]
        prepared = self.coordinator.call(
            "handoff_begin",
            userid=userid,
            source_worker=source_worker,
            source_epoch=source_epoch,
            target_affinity=affinity,
            target_room_path=target_room_path,
            request_id=request_id,
        )
        prepared_target = str(prepared.get("target_worker") or "")
        if (
            not prepared.get("ok")
            or prepared.get("local")
            or prepared.get("state") != "prepared"
            or prepared_target != target_worker
            or prepared_target not in self.workers
        ):
            raise RuntimeError(f"cannot prepare cross-worker handoff: {prepared}")
        if target_worker == source_worker:
            self.coordinator.call("handoff_abort", request_id=request_id,
                                  source_worker=source_worker)
            raise RuntimeError("handoff unexpectedly resolved to source worker")
        released = self._worker_call(
            source_worker,
            "local_release",
            userid=userid,
            affinity=source_affinity,
            epoch=source_epoch,
        )
        if not released.get("ok"):
            self.coordinator.call(
                "handoff_abort", request_id=request_id, source_worker=source_worker
            )
            raise RuntimeError(f"cannot release handoff source: {released}")
        committed = self.coordinator.call(
            "handoff_commit", request_id=request_id, target_worker=target_worker
        )
        if not committed.get("ok"):
            # Source is already safely persisted and offline. Restoring the
            # source lease lets a later request log it in there again without
            # duplicate live objects; migration can be retried afterwards.
            self.coordinator.call(
                "handoff_abort", request_id=request_id, source_worker=source_worker
            )
            raise RuntimeError(f"cannot commit cross-worker handoff: {committed}")
        return (
            target_worker,
            int(committed["target_epoch"]),
            bool(replay_request),
            str(committed.get("target_room_path") or target_room_path),
        )

    def confirmed_route(
        self, userid: str, worker_id: str, epoch: int,
    ) -> tuple[str, str]:
        route = self.coordinator.call("route", userid=userid)
        affinity = str(route.get("affinity") or "")
        if (
            not route.get("ok")
            or route.get("state") != "active"
            or route.get("worker_id") != worker_id
            or int(route.get("epoch") or 0) != epoch
            or not affinity
        ):
            raise RuntimeError(f"coordinator route confirmation failed: {route}")
        return affinity, str(route.get("arrival_room_path") or "")

    def acknowledge_arrival(
        self, userid: str, worker_id: str, epoch: int, affinity: str,
        arrival_room: str,
    ) -> None:
        if not arrival_room:
            return
        local = self._worker_call(worker_id, "local_route", userid=userid)
        if (
            not local.get("ok")
            or int(local.get("lease_epoch") or 0) != epoch
            or str(local.get("affinity") or "") != affinity
            or str(local.get("room_path") or "") != arrival_room
        ):
            raise RuntimeError(f"worker arrival confirmation failed: {local}")
        acknowledged = self.coordinator.call(
            "arrival_ack",
            userid=userid,
            worker_id=worker_id,
            epoch=epoch,
            affinity=affinity,
        )
        if not acknowledged.get("ok"):
            raise RuntimeError(
                f"coordinator arrival acknowledgement failed: {acknowledged}"
            )

    def record_account(self, userid: str, account_id: str) -> None:
        if not valid_userid(userid) or not valid_userid(account_id):
            return
        with self._identity_lock:
            self._account_by_user[userid] = account_id

    def record_account_token(self, token: str, account_id: str) -> None:
        if len(token) != 64 or not valid_userid(account_id):
            return
        with self._identity_lock:
            if len(self._account_by_token) >= 4096:
                oldest = min(
                    self._account_by_token,
                    key=lambda one: self._account_by_token[one][1],
                )
                self._account_by_token.pop(oldest, None)
            self._account_by_token[token] = (account_id, time.monotonic() + 43200)

    def account_for_token(self, token: str) -> str:
        if len(token) != 64:
            return ""
        with self._identity_lock:
            cached = self._account_by_token.get(token)
            if not cached or cached[1] < time.monotonic():
                self._account_by_token.pop(token, None)
                return ""
            return cached[0]

    def observe_account_response(
        self, path: str, request_token: str, response: ProxyResponse
    ) -> None:
        endpoint = urllib.parse.urlsplit(path).path
        if response.status >= 400:
            return
        if endpoint == "/api/account/logout":
            with self._identity_lock:
                self._account_by_token.pop(request_token, None)
            return
        try:
            payload = json.loads(response.body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return
        if not isinstance(payload, dict):
            return
        token = str(payload.get("token") or request_token).strip().lower()
        account_id = str(payload.get("account_id") or "").strip().lower()
        self.record_account_token(token, account_id)

    def account_cache_token(self, account_id: str, worker_id: str) -> str:
        """Change the cache capability whenever one account changes workers."""
        with self._identity_lock:
            if self._account_last_worker.get(account_id) != worker_id:
                self._account_last_worker[account_id] = worker_id
                self._account_cache_epoch[account_id] = (
                    self._account_cache_epoch.get(account_id, 0) + 1
                )
            epoch = self._account_cache_epoch.get(account_id, 1)
        return hashlib.sha256(
            f"{self._controller_nonce}|{account_id}|{epoch}".encode("utf-8")
        ).hexdigest()

    def resolve_account(self, userid: str) -> str:
        """Resolve the authoritative shared-account lock identity server-side."""
        with self._identity_lock:
            cached = self._account_by_user.get(userid, "")
        if valid_userid(cached):
            return cached
        result = self.coordinator.call("resolve_account", userid=userid)
        account_id = str(result.get("account_id") or "").strip().lower()
        if not result.get("ok") or not valid_userid(account_id):
            raise RuntimeError(f"cannot resolve account owner for {userid}")
        self.record_account(userid, account_id)
        return account_id

    def user_lock(self, userid: str, account_hint: str = "") -> threading.Lock:
        if valid_userid(account_hint):
            self.record_account(userid, account_hint)
        with self._identity_lock:
            lock_identity = self._account_by_user.get(userid, userid)
        digest = hashlib.sha256(lock_identity.encode("utf-8")).digest()
        index = int.from_bytes(digest[:2], "big") % len(self._user_locks)
        return self._user_locks[index]

    @contextmanager
    def account_management_lock(self):
        """Quiesce character writes for token-only account index mutations."""
        with self._account_management_lock:
            with ExitStack() as stack:
                for lock in self._user_locks:
                    stack.enter_context(lock)
                yield

    @contextmanager
    def gameplay_command_lock(self, command: str):
        """Serialize database-global auction state across all map workers."""
        if auction_command(command):
            with self._auction_lock:
                yield
        else:
            yield

    @property
    def primary(self) -> str:
        return self._primary


class GatewayHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "XiandMapGateway/1.0"

    def _handle(self) -> None:
        if not public_path_allowed(self.path):
            self.send_error(404, "not found")
            return
        try:
            content_length = request_content_length(self.headers)
        except ValueError:
            self.close_connection = True
            self.send_error(400, "invalid request framing")
            return
        body = self.rfile.read(content_length) if content_length else b""
        try:
            userid = extract_userid(self.path, self.headers, body)
            account_id = extract_account_id(self.path, self.headers, body)
            account_token = extract_account_token(self.path, self.headers, body)
            game_command = extract_game_command(self.path, self.headers, body)
        except ValueError:
            self.send_error(400, "invalid or conflicting request parameters")
            return
        pool: WorkerPool = self.server.worker_pool  # type: ignore[attr-defined]
        request_entered = False
        command_may_have_run = False
        try:
            pool.begin_request()
            request_entered = True
            if account_api_path(self.path):
                token_account = pool.account_for_token(account_token)
                if userid:
                    account_id = pool.resolve_account(userid)
                    if not account_identity_matches(account_id, token_account):
                        raise RuntimeError("account token owner mismatch")
                    account_context = pool.user_lock(userid, account_id)
                elif token_account:
                    account_id = token_account
                    account_context = pool.user_lock(account_id, account_id)
                else:
                    # A client account_id is never an authority for cache
                    # invalidation or locking. Unknown opaque sessions use the
                    # conservative all-account fence on the primary worker.
                    account_id = ""
                    account_context = pool.account_management_lock()
                with account_context:
                    pool.ensure_routing_ready()
                    proxied = pool.proxy(
                        pool.primary,
                        self.command,
                        self.path,
                        self.headers,
                        body,
                        "",
                        0,
                        account_id=account_id,
                        command_kind="account",
                    )
                    pool.observe_account_response(
                        self.path, account_token, proxied
                    )
            elif userid:
                # Never trust a client-provided account id for transaction
                # locking; legacy and multi-character ownership comes from
                # the coordinator's persisted account index/player profile.
                account_id = pool.resolve_account(userid)
                token_account = pool.account_for_token(account_token)
                if not account_identity_matches(account_id, token_account):
                    raise RuntimeError("gameplay token owner mismatch")
                with pool.user_lock(userid, account_id), \
                     pool.gameplay_command_lock(game_command):
                    pool.ensure_routing_ready()
                    command_kind = (
                        "auction" if auction_command(game_command) else "gameplay"
                    )
                    worker_id, epoch, leased_affinity, arrival_room = (
                        pool.route_user(userid)
                    )
                    # Settle a drift left by a previous response/reconcile
                    # failure before allowing this new command to mutate the
                    # old owner.  Cross-worker arrival consumes one proxy; this
                    # request is then executed exactly once on the new owner.
                    if not arrival_room and pool.reconciliation_pending(userid):
                        source_worker = worker_id
                        migration = pool.reconcile(
                            userid, worker_id, epoch, leased_affinity,
                            require_settled=True,
                        )
                        deliver_arrival, _replace = migration_delivery_plan(
                            source_worker, migration, before_command=True
                        )
                        if migration:
                            worker_id, epoch, _redirect, arrival_room = migration
                            leased_affinity, route_arrival = pool.confirmed_route(
                                userid, worker_id, epoch
                            )
                            if deliver_arrival:
                                if not arrival_room or route_arrival != arrival_room:
                                    raise RuntimeError(
                                        "pre-command arrival capability mismatch"
                                    )
                                arrival_response = pool.proxy(
                                    worker_id,
                                    self.command,
                                    self.path,
                                    self.headers,
                                    body,
                                    userid,
                                    epoch,
                                    arrival_room,
                                    account_id,
                                    command_kind,
                                )
                                if arrival_response.status >= 500:
                                    raise RuntimeError(
                                        "pre-command arrival delivery failed"
                                    )
                                pool.acknowledge_arrival(
                                    userid, worker_id, epoch, leased_affinity,
                                    arrival_room,
                                )
                                leased_affinity, route_arrival = (
                                    pool.confirmed_route(userid, worker_id, epoch)
                                )
                                if route_arrival:
                                    raise RuntimeError(
                                        "pre-command arrival remains pending"
                                    )
                                arrival_room = ""
                            else:
                                # The same-worker redirect was completed by the
                                # internal RPC; do not turn the new command into
                                # another arrival-only response.
                                arrival_room = ""
                    command_may_have_run = True
                    proxied = pool.proxy(
                        worker_id,
                        self.command,
                        self.path,
                        self.headers,
                        body,
                        userid,
                        epoch,
                        arrival_room,
                        account_id,
                        command_kind,
                    )
                    if proxied.status < 500:
                        pool.acknowledge_arrival(
                            userid, worker_id, epoch, leased_affinity,
                            arrival_room,
                        )
                        migration = pool.reconcile(
                            userid,
                            worker_id,
                            epoch,
                            leased_affinity,
                        )
                        deliver_arrival, replace_response = migration_delivery_plan(
                            worker_id, migration, before_command=False
                        )
                        if migration:
                            source_worker = worker_id
                            worker_id, epoch, _redirect, arrival_room = migration
                            leased_affinity, route_arrival = pool.confirmed_route(
                                userid, worker_id, epoch
                            )
                        if migration and deliver_arrival:
                            if worker_id != source_worker and (
                                not arrival_room or route_arrival != arrival_room
                            ):
                                raise RuntimeError(
                                    "post-command arrival capability mismatch"
                                )
                            arrival_response = pool.proxy(
                                worker_id,
                                self.command,
                                self.path,
                                self.headers,
                                body,
                                userid,
                                epoch,
                                arrival_room,
                                account_id,
                                command_kind,
                            )
                            if arrival_response.status >= 500:
                                raise RuntimeError(
                                    "post-command arrival delivery failed"
                                )
                            if worker_id != source_worker:
                                pool.acknowledge_arrival(
                                    userid, worker_id, epoch, leased_affinity,
                                    arrival_room,
                                )
                                _affinity, route_arrival = pool.confirmed_route(
                                    userid, worker_id, epoch
                                )
                                if route_arrival:
                                    raise RuntimeError(
                                        "post-command arrival remains pending"
                                    )
                            if replace_response:
                                proxied = arrival_response
                        pool.clear_reconciliation_pending(userid)
                    else:
                        pool.mark_reconciliation_pending(userid)
            else:
                worker_id, epoch = pool.primary, 0
                proxied = pool.proxy(
                    worker_id,
                    self.command,
                    self.path,
                    self.headers,
                    body,
                    "",
                    0,
                )
        except (RuntimeError, OSError, urllib.error.URLError) as exc:
            if userid and command_may_have_run:
                pool.mark_reconciliation_pending(userid)
            if request_entered:
                pool.end_request()
                request_entered = False
            message = json.dumps(
                {"error": "地图服务暂时繁忙，请稍后重试"},
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
            self.send_response(503)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(message)))
            self.send_header("Retry-After", "1")
            self.end_headers()
            self.wfile.write(message)
            print(f"[map-gateway] request failed: {exc}", file=sys.stderr)
            return

        if request_entered:
            pool.end_request()

        self.send_response(proxied.status, proxied.reason)
        has_content_length = False
        for key, value in proxied.headers:
            if key.lower() == "content-length":
                has_content_length = True
            self.send_header(key, value)
        if not has_content_length:
            self.send_header("Content-Length", str(len(proxied.body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(proxied.body)

    def do_GET(self) -> None:  # noqa: N802
        self._handle()

    def do_HEAD(self) -> None:  # noqa: N802
        self._handle()

    def do_POST(self) -> None:  # noqa: N802
        self._handle()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._handle()

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[map-gateway] {self.address_string()} {fmt % args}")


def main() -> int:
    token = os.environ.get("XIAND_WORKER_TOKEN", "")
    if len(token) < 32:
        print("[map-gateway] XIAND_WORKER_TOKEN must be at least 32 characters", file=sys.stderr)
        return 2
    if not active_trial_authorized():
        print(
            "[map-gateway] active mode requires "
            "XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only",
            file=sys.stderr,
        )
        return 2
    workers = parse_worker_endpoints(os.environ.get("XIAND_WORKERS", ""))
    listen_host = os.environ.get("XIAND_GATEWAY_HOST", "127.0.0.1")
    listen_port = env_int("XIAND_GATEWAY_PORT", 8888, 1024, 65535)
    timeout = float(env_int("XIAND_WORKER_TIMEOUT", 30, 1, 120))
    coordinator_endpoint = os.environ.get(
        "XIAND_COORDINATOR_URL", "http://127.0.0.1:18880"
    )
    parsed_coordinator = urllib.parse.urlsplit(coordinator_endpoint)
    if (
        parsed_coordinator.scheme != "http"
        or parsed_coordinator.hostname not in {"127.0.0.1", "localhost", "::1"}
        or not parsed_coordinator.port
    ):
        print("[map-gateway] XIAND_COORDINATOR_URL must be loopback HTTP", file=sys.stderr)
        return 2

    coordinator = CoordinatorClient(coordinator_endpoint, token, timeout)
    pool = WorkerPool(workers, coordinator, token, timeout)
    try:
        process_claim = GatewayProcessClaim(
            os.environ.get("XIAND_GATEWAY_LOCK_FILE", ""),
            os.environ.get("XIAND_GATEWAY_PID_FILE", ""),
        )
    except (OSError, RuntimeError) as exc:
        print(f"[map-gateway] startup failed: {exc}", file=sys.stderr)
        return 1
    try:
        pool.start()
    except (OSError, urllib.error.URLError, RuntimeError,
            json.JSONDecodeError) as exc:
        print(f"[map-gateway] startup failed: {exc}", file=sys.stderr)
        process_claim.close()
        return 1

    if os.environ.get("XIAND_MAP_WORKER_SHADOW", "") == "1":
        shadow_stop = threading.Event()

        def stop_shadow(_signum: int, _frame: Any) -> None:
            shadow_stop.set()

        signal.signal(signal.SIGTERM, stop_shadow)
        signal.signal(signal.SIGINT, stop_shadow)
        print(
            f"[map-gateway] shadow controller ready; "
            f"workers={','.join(sorted(workers))}; no public listener"
        )
        try:
            while not shadow_stop.wait(0.5):
                pass
        finally:
            pool.stop()
            process_claim.close()
        return 0

    max_requests = env_int("XIAND_GATEWAY_MAX_REQUESTS", 128, 8, 1024)
    client_timeout = float(
        env_int("XIAND_GATEWAY_CLIENT_TIMEOUT", 30, 5, 120)
    )
    try:
        server = BoundedThreadingHTTPServer(
            (listen_host, listen_port), GatewayHandler, max_requests,
            client_timeout,
        )
    except OSError as exc:
        print(f"[map-gateway] listener failed: {exc}", file=sys.stderr)
        pool.stop()
        process_claim.close()
        return 1
    server.worker_pool = pool  # type: ignore[attr-defined]

    def stop_server(_signum: int, _frame: Any) -> None:
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop_server)
    signal.signal(signal.SIGINT, stop_server)
    print(
        f"[map-gateway] listening on {listen_host}:{listen_port}; "
        f"workers={','.join(sorted(workers))}"
    )
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        pool.stop()
        process_claim.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
