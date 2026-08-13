#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xiand-quiesce-retry.XXXXXX")"
SERVER_PID=""
cleanup()
{
	if [[ -n "$SERVER_PID" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" 2>/dev/null || true
	fi
	rm -rf -- "$FIXTURE_DIR"
}
trap cleanup EXIT

port_file="$FIXTURE_DIR/port"
count_file="$FIXTURE_DIR/count"
python3 - "$port_file" "$count_file" <<'PY' &
import http.server
import json
import sys

port_file, count_file = sys.argv[1:]

class Handler(http.server.BaseHTTPRequestHandler):
    calls = 0

    def log_message(self, *_args):
        pass

    def do_POST(self):
        Handler.calls += 1
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        if Handler.calls == 1:
            status = 409
            result = {
                "ok": 0,
                "code": "gateway_not_quiescent",
                "active_requests": 0,
                "pending_requests": 3,
                "uncertain_requests": 0,
                "pending_reconcile_users": 0,
                "background_arrivals": 0,
            }
        elif Handler.calls == 2:
            status = 200
            result = {
                "ok": 1,
                "routing_ready": 0,
                "shutdown_state": "prepared",
                "active_requests": 0,
                "pending_requests": 0,
                "maintenance_operations": 0,
                "uncertain_requests": 0,
                "pending_reconcile_users": 0,
                "background_arrivals": 0,
            }
        else:
            status = 409
            result = {
                "ok": 0,
                "code": "gateway_not_quiescent",
                "active_requests": 0,
                "pending_requests": 0,
                "uncertain_requests": 1,
                "pending_reconcile_users": 0,
                "background_arrivals": 0,
                "routing_resumed": 0,
            }
        body = json.dumps(result).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        if Handler.calls >= 3:
            with open(count_file, "w", encoding="ascii") as output:
                output.write(str(Handler.calls))

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="ascii") as output:
    output.write(str(server.server_port))
for _ in range(3):
    server.handle_request()
PY
SERVER_PID=$!

for _ in {1..100}; do
	[[ -s "$port_file" ]] && break
	sleep 0.02
done
[[ -s "$port_file" ]] || {
	echo "mock coordinator did not start" >&2
	exit 1
}

export XIAND_WORKER_TOKEN="fixture-worker-token"
source "$ROOT_DIR/scripts/map_worker_cluster.sh"
coordinator_port="$(<"$port_file")"

success_output="$(quiesce_gateway_for_shutdown "$coordinator_port" 2>&1)"
[[ "$success_output" == *"shutdown drain is still settling"* ]] || {
	echo "transient shutdown did not report a bounded retry" >&2
	exit 1
}
[[ "$success_output" == *"all accepted requests are settled"* ]] || {
	echo "transient shutdown did not complete on the second proof" >&2
	exit 1
}

set +e
failure_output="$(set -e; quiesce_gateway_for_shutdown "$coordinator_port" 2>&1)"
failure_status=$?
set -e
[[ "$failure_status" -ne 0 ]] || {
	echo "uncertain shutdown must remain fail-closed" >&2
	exit 1
}
[[ "$failure_output" != *"Traceback"* ]] || {
	echo "expected HTTP conflict leaked a Python traceback" >&2
	printf '%s\n' "$failure_output" >&2
	exit 1
}
[[ "$failure_output" == *'"uncertain_requests": 1'* ]] || {
	echo "unsafe shutdown did not preserve the diagnostic counters" >&2
	exit 1
}

wait "$SERVER_PID"
SERVER_PID=""
[[ "$(<"$count_file")" == "3" ]] || {
	echo "unexpected mock request count" >&2
	exit 1
}

echo "map worker quiesce retry tests passed"
