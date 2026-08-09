#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${XIAND_MAP_WORKER_CONFIG:-$ROOT_DIR/data_xiand/map_workers/config.json}"
ACTION="${1:-status}"
PIKE_BIN="${PIKE_BIN:-}"
PIKE_STACK_DEPTH="${XIAND_PIKE_STACK_DEPTH:-1000000}"
PIKE_THREAD_STACK="${XIAND_PIKE_THREAD_STACK:-67108864}"
AREA_NAME="${GAME_AREA:-xd01}"
LAUNCHER="${XIAND_MAP_WORKER_LAUNCHER:-screen}"
TRAFFIC_MODE="shadow"
STARTING_CLUSTER=0
STARTED_SESSIONS=()
STARTED_NODE_IDS=()
STARTED_MUD_PORTS=()
ORCHESTRATOR_LOCK_DIR=""
CONFIG_SNAPSHOT=""

log()
{
	echo "[map-workers] $*"
}

fail()
{
	echo "[map-workers] ERROR: $*" >&2
	exit 1
}

release_orchestrator_lock()
{
	if [[ -n "$CONFIG_SNAPSHOT" && -f "$CONFIG_SNAPSHOT" ]]; then
		rm -f -- "$CONFIG_SNAPSHOT" || true
	fi
	if [[ -n "$ORCHESTRATOR_LOCK_DIR" && -d "$ORCHESTRATOR_LOCK_DIR" &&
	      -f "$ORCHESTRATOR_LOCK_DIR/pid" &&
	      "$(<"$ORCHESTRATOR_LOCK_DIR/pid")" == "$$" ]]; then
		rm -f -- "$ORCHESTRATOR_LOCK_DIR/pid" || true
		rmdir -- "$ORCHESTRATOR_LOCK_DIR" || true
	fi
}

acquire_orchestrator_lock()
{
	local run_dir owner_pid
	run_dir="$(runtime_dir)"
	mkdir -p "$run_dir"
	ORCHESTRATOR_LOCK_DIR="$run_dir/orchestrator.lock"
	if ! mkdir "$ORCHESTRATOR_LOCK_DIR" 2>/dev/null; then
		owner_pid=""
		if [[ -f "$ORCHESTRATOR_LOCK_DIR/pid" ]]; then
			IFS= read -r owner_pid < "$ORCHESTRATOR_LOCK_DIR/pid" || true
		fi
		if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
			fail "another map-worker apply/stop/recovery is running (pid $owner_pid)"
		fi
		rm -f -- "$ORCHESTRATOR_LOCK_DIR/pid" || true
		rmdir -- "$ORCHESTRATOR_LOCK_DIR" 2>/dev/null ||
			fail "cannot recover stale orchestrator lock $ORCHESTRATOR_LOCK_DIR"
		mkdir "$ORCHESTRATOR_LOCK_DIR" 2>/dev/null ||
			fail "another map-worker apply/stop/recovery started concurrently"
	fi
	printf '%s\n' "$$" > "$ORCHESTRATOR_LOCK_DIR/pid"
	chmod 750 "$ORCHESTRATOR_LOCK_DIR"
	chmod 640 "$ORCHESTRATOR_LOCK_DIR/pid"
	trap release_orchestrator_lock EXIT
}

snapshot_config()
{
	local source_config="$CONFIG_FILE"
	# One mutation uses one immutable config generation from validation to finish.
	CONFIG_SNAPSHOT="$(runtime_dir)/config.$$.snapshot.json"
	cp -- "$source_config" "$CONFIG_SNAPSHOT"
	chmod 640 "$CONFIG_SNAPSHOT"
	CONFIG_FILE="$CONFIG_SNAPSHOT"
	ensure_config
}

load_environment()
{
	# A deliberately exported value is an operator override.  The local .env is
	# only a deployment default and must not silently retarget an apply/stop to
	# another area or replace a one-shot credential.
	local inherited_game_area="${GAME_AREA:-}"
	local inherited_area_name="${XIAND_MAP_WORKER_AREA_NAME:-}"
	local inherited_mysql_password="${MYSQL_PASSWORD:-}"
	local inherited_worker_token="${XIAND_WORKER_TOKEN:-}"
	local inherited_active_ack="${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}"
	local inherited_launcher="${XIAND_MAP_WORKER_LAUNCHER:-}"
	umask 027
	if [[ -f "$ROOT_DIR/.env" ]]; then
		set -a
		source "$ROOT_DIR/.env"
		set +a
	fi
	[[ -z "$inherited_game_area" ]] || GAME_AREA="$inherited_game_area"
	[[ -z "$inherited_area_name" ]] ||
		XIAND_MAP_WORKER_AREA_NAME="$inherited_area_name"
	[[ -z "$inherited_mysql_password" ]] ||
		MYSQL_PASSWORD="$inherited_mysql_password"
	[[ -z "$inherited_worker_token" ]] ||
		XIAND_WORKER_TOKEN="$inherited_worker_token"
	[[ -z "$inherited_active_ack" ]] ||
		XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="$inherited_active_ack"
	[[ -z "$inherited_launcher" ]] ||
		XIAND_MAP_WORKER_LAUNCHER="$inherited_launcher"
	AREA_NAME="${XIAND_MAP_WORKER_AREA_NAME:-${GAME_AREA:-xd01}}"
	[[ "$AREA_NAME" =~ ^[A-Za-z0-9_-]{1,48}$ ]] ||
		fail "map-worker area name contains unsupported characters"
	LAUNCHER="${XIAND_MAP_WORKER_LAUNCHER:-screen}"
	[[ "$LAUNCHER" == "screen" || "$LAUNCHER" == "background" ]] ||
		fail "XIAND_MAP_WORKER_LAUNCHER must be screen or background"
	[[ -n "${MYSQL_PASSWORD:-}" ]] || fail "MYSQL_PASSWORD is required"
	local worker_token="${XIAND_WORKER_TOKEN:-}"
	[[ ${#worker_token} -ge 32 ]] ||
		fail "XIAND_WORKER_TOKEN must be at least 32 characters"
	if [[ -z "$PIKE_BIN" ]]; then
		PIKE_BIN="$(command -v pike || true)"
	fi
	[[ -x "$PIKE_BIN" ]] || fail "Pike binary is not executable"
	command -v python3 >/dev/null 2>&1 || fail "python3 is required"
	if [[ "$LAUNCHER" == "screen" ]]; then
		command -v screen >/dev/null 2>&1 || fail "screen is required"
	fi
	command -v lsof >/dev/null 2>&1 || fail "lsof is required"
	command -v nc >/dev/null 2>&1 || fail "nc is required for safe shutdown"
}

ensure_config()
{
	if [[ ! -f "$CONFIG_FILE" ]]; then
		fail "missing $CONFIG_FILE; copy deploy/map_workers/config.example.json first or save it from the admin panel"
	fi
	python3 - "$CONFIG_FILE" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
config = json.loads(path.read_text(encoding="utf-8"))
required = {
    "schema_version", "enabled", "traffic_mode", "worker_count", "worker_capacity",
    "placement", "coordinator_http_port", "worker_http_base_port",
    "worker_mud_base_port", "gateway_port",
}
if set(config) != required:
    raise SystemExit("config keys do not match schema v2")
if type(config["schema_version"]) is not int or config["schema_version"] != 2:
    raise SystemExit("unsupported schema_version")
if type(config["enabled"]) is not int or config["enabled"] not in (0, 1):
    raise SystemExit("enabled must be 0 or 1")
if config["traffic_mode"] not in ("shadow", "active"):
    raise SystemExit("traffic_mode must be shadow or active")
if type(config["worker_count"]) is not int or not 1 <= config["worker_count"] <= 16:
    raise SystemExit("worker_count must be 1..16")
if type(config["worker_capacity"]) is not int or not 10 <= config["worker_capacity"] <= 10000:
    raise SystemExit("worker_capacity must be 10..10000")
if config["placement"] != "load_aware_rendezvous":
    raise SystemExit("unsupported placement")
ports = [
    config["coordinator_http_port"], config["worker_mud_base_port"] - 1,
    config["worker_http_base_port"],
    config["worker_mud_base_port"], config["gateway_port"],
]
if any(type(port) is not int or not 1024 <= port <= 65535 for port in ports):
    raise SystemExit("ports must be 1024..65535")
if config["worker_http_base_port"] + config["worker_count"] - 1 > 65535:
    raise SystemExit("worker HTTP port range overflows")
if config["worker_mud_base_port"] + config["worker_count"] - 1 > 65535:
    raise SystemExit("worker MUD port range overflows")
if len(set(
    [config["coordinator_http_port"], config["worker_mud_base_port"] - 1,
     config["gateway_port"]]
    + list(range(config["worker_http_base_port"],
                 config["worker_http_base_port"] + config["worker_count"]))
    + list(range(config["worker_mud_base_port"],
                 config["worker_mud_base_port"] + config["worker_count"]))
)) != 3 + config["worker_count"] * 2:
    raise SystemExit("configured ports overlap")
PY
}

config_value()
{
	python3 - "$CONFIG_FILE" "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)[sys.argv[2]])
PY
}

validate_gateway_code()
{
	python3 -m py_compile \
		"$ROOT_DIR/tools/map_workers/gateway.py" \
		"$ROOT_DIR/tools/map_workers/test_gateway.py"
	python3 -m unittest discover -s "$ROOT_DIR/tools/map_workers" \
		-p 'test_*.py'
	bash "$ROOT_DIR/tools/map_workers/test_startup.sh"
	bash "$ROOT_DIR/tools/map_workers/test_bootstrap.sh"
}

session_exists()
{
	[[ "$LAUNCHER" == "screen" ]] || return 1
	screen -ls 2>/dev/null | grep -Fq ".$1"
}

launch_detached()
{
	local session_name="$1"
	local command_line="$2"
	if [[ "$LAUNCHER" == "screen" ]]; then
		screen -dmS "$session_name" bash -lc "$command_line"
	else
		nohup bash -lc "$command_line" </dev/null >/dev/null 2>&1 &
	fi
}

runtime_process_running()
{
	local node_id="$1"
	local process_pid_file="$(runtime_dir)/$node_id.pid"
	local pid=""
	local command_line=""
	[[ -f "$process_pid_file" ]] || return 1
	pid="$(<"$process_pid_file")"
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1
	kill -0 "$pid" >/dev/null 2>&1 || return 1
	command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
	[[ "$command_line" == *"$ROOT_DIR"* ]] || return 1
	[[ "$command_line" == *"lowlib/driver.pike"* ||
	   "$command_line" == *"tools/map_workers/gateway.py"* ]]
}

cluster_processes_running()
{
	runtime_process_running coordinator || runtime_process_running gateway
}

port_is_listening()
{
	lsof -tiTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_port()
{
	local port="$1"
	local label="$2"
	local deadline=$((SECONDS + 90))
	while (( SECONDS < deadline )); do
		if port_is_listening "$port"; then
			return 0
		fi
		sleep 1
	done
	fail "$label did not listen on port $port within 90 seconds"
}

runtime_dir()
{
	echo "$ROOT_DIR/log/map-workers/$AREA_NAME"
}

topology_file()
{
	echo "$(runtime_dir)/topology.json"
}

write_topology()
{
	local worker_count="$1"
	local worker_mud_base="$2"
	local coordinator_mud="$3"
	local worker_http_base="$4"
	local coordinator_http="$5"
	local gateway_port="$6"
	local capacity="$7"
	local temp_file="$(topology_file).tmp"
	python3 - "$temp_file" "$worker_count" "$worker_mud_base" \
		"$coordinator_mud" "$TRAFFIC_MODE" "$worker_http_base" \
		"$coordinator_http" "$gateway_port" "$capacity" <<'PY'
import json
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "worker_count": int(sys.argv[2]),
    "worker_mud_base_port": int(sys.argv[3]),
    "coordinator_mud_port": int(sys.argv[4]),
    "traffic_mode": sys.argv[5],
    "worker_http_base_port": int(sys.argv[6]),
    "coordinator_http_port": int(sys.argv[7]),
    "gateway_port": int(sys.argv[8]),
    "worker_capacity": int(sys.argv[9]),
}
path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
os.chmod(path, 0o640)
os.replace(path, path.with_name("topology.json"))
PY
}

topology_value()
{
	python3 - "$(topology_file)" "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)[sys.argv[2]])
PY
}

cluster_health()
{
	local worker_count coordinator_http worker_http_base worker_mud_base
	local gateway_port traffic_mode coordinator_mud
	local topology_values
	[[ -f "$(topology_file)" ]] || fail "running topology is missing"
	topology_values="$(python3 - "$(topology_file)" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    topology = json.load(handle)
keys = (
    "worker_count", "coordinator_http_port", "worker_http_base_port",
    "worker_mud_base_port", "coordinator_mud_port", "gateway_port",
    "traffic_mode",
)
print("\t".join(str(topology[key]) for key in keys))
PY
)"
	IFS=$'\t' read -r worker_count coordinator_http worker_http_base \
		worker_mud_base coordinator_mud gateway_port traffic_mode \
		<<< "$topology_values"

	runtime_process_running coordinator || fail "coordinator process is down"
	runtime_process_running gateway || fail "gateway controller is down"
	port_is_listening "$coordinator_http" || fail "coordinator HTTP port is down"
	port_is_listening "$coordinator_mud" || fail "coordinator MUD port is down"
	if [[ "$traffic_mode" == "active" ]]; then
		port_is_listening "$gateway_port" || fail "active gateway port is down"
	fi
	for (( index=1; index<=worker_count; index++ )); do
		local worker_id
		worker_id="$(printf 'w%02d' "$index")"
		runtime_process_running "$worker_id" || fail "$worker_id process is down"
		port_is_listening "$((worker_http_base + index - 1))" ||
			fail "$worker_id HTTP port is down"
		port_is_listening "$((worker_mud_base + index - 1))" ||
			fail "$worker_id MUD port is down"
	done

	python3 - "http://127.0.0.1:$coordinator_http" "$worker_count" <<'PY'
import json
import os
import sys
import urllib.request

request = urllib.request.Request(
    sys.argv[1] + "/internal/map-worker",
    data=b'{"action":"status"}',
    headers={
        "Content-Type": "application/json",
        "X-Xiand-Worker-Token": os.environ["XIAND_WORKER_TOKEN"],
    },
    method="POST",
)
with urllib.request.urlopen(request, timeout=3) as response:
    status = json.loads(response.read().decode("utf-8"))
nodes = status.get("nodes", [])
expected = int(sys.argv[2])
if not status.get("ok") or len(nodes) != expected:
    raise SystemExit("coordinator worker inventory is incomplete")
if not all(node.get("healthy") for node in nodes):
    raise SystemExit("coordinator reports an unhealthy worker")
PY
	log "cluster health is good: mode=$traffic_mode workers=$worker_count"
}

cleanup_partial_start()
{
	local status=$?
	trap - ERR
	if [[ "$STARTING_CLUSTER" == "1" ]]; then
		log "startup failed; safely stopping only processes created by this attempt"
		for (( index=${#STARTED_SESSIONS[@]}-1; index>=0; index-- )); do
			if (( STARTED_MUD_PORTS[index] > 0 )); then
				graceful_node_stop "${STARTED_SESSIONS[index]}" \
					"${STARTED_MUD_PORTS[index]}" \
					"${STARTED_NODE_IDS[index]}" || true
			else
				terminate_runtime_process "${STARTED_SESSIONS[index]}" \
					"${STARTED_NODE_IDS[index]}" || true
			fi
		done
	fi
	exit "$status"
}

start_pike_node()
{
	local role="$1"
	local worker_id="$2"
	local mud_port="$3"
	local http_port="$4"
	local screen_name="xiand-${AREA_NAME}-${worker_id}"
	local run_dir
	local process_pid_file
	local shadow_flag=0
	[[ "$TRAFFIC_MODE" == "shadow" ]] && shadow_flag=1
	run_dir="$(runtime_dir)"
	process_pid_file="$run_dir/$worker_id.pid"
	if runtime_process_running "$worker_id"; then
		fail "runtime process already exists: $worker_id"
	fi
	[[ ! -f "$process_pid_file" ]] || rm "$process_pid_file"
	if session_exists "$screen_name"; then
		fail "screen session already exists: $screen_name"
	fi
	launch_detached "$screen_name" \
		"cd '$ROOT_DIR' && umask 027 && echo \$\$ > '$process_pid_file' && export XIAND_NODE_ROLE='$role' XIAND_WORKER_ID='$worker_id' XIAND_HTTP_HOST='127.0.0.1' XIAND_HTTP_PORT='$http_port' XIAND_RUN_TESTUNIT=0 XIAND_MAP_WORKER_SHADOW='$shadow_flag' && exec '$PIKE_BIN' -s'$PIKE_STACK_DEPTH' -ss'$PIKE_THREAD_STACK' '$ROOT_DIR/lowlib/driver.pike' -i 127.0.0.1 -p '$mud_port' '$ROOT_DIR/' >> '$run_dir/runtime.$worker_id.log' 2>&1"
	STARTED_SESSIONS+=("$screen_name")
	STARTED_NODE_IDS+=("$worker_id")
	STARTED_MUD_PORTS+=("$mud_port")
}

wait_for_worker_registration()
{
	local coordinator_http="$1"
	local expected="$2"
	python3 - "http://127.0.0.1:$coordinator_http" "$expected" <<'PY'
import json
import os
import sys
import time
import urllib.request

endpoint = sys.argv[1] + "/internal/map-worker"
expected = int(sys.argv[2])
token = os.environ["XIAND_WORKER_TOKEN"]
deadline = time.monotonic() + 60
while time.monotonic() < deadline:
    request = urllib.request.Request(
        endpoint,
        data=b'{"action":"status"}',
        headers={"Content-Type": "application/json",
                 "X-Xiand-Worker-Token": token},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            status = json.loads(response.read().decode("utf-8"))
        if len(status.get("nodes", [])) == expected and all(
            node.get("healthy") for node in status["nodes"]
        ):
            raise SystemExit(0)
    except Exception:
        pass
    time.sleep(1)
raise SystemExit("workers did not register healthy within 60 seconds")
PY
}

wait_for_runtime_process()
{
	local node_id="$1"
	local deadline=$((SECONDS + 15))
	while (( SECONDS < deadline )); do
		if runtime_process_running "$node_id"; then
			return 0
		fi
		sleep 1
	done
	fail "$node_id did not publish a validated PID within 15 seconds"
}

start_gateway_controller()
{
	local worker_count="$1"
	local capacity="$2"
	local coordinator_http="$3"
	local worker_http_base="$4"
	local gateway_port="$5"
	local run_dir="$6"
	local endpoints=""
	local gateway_session="xiand-${AREA_NAME}-gateway"
	local gateway_pid_file="$run_dir/gateway.pid"
	local shadow_flag=0
	[[ "$TRAFFIC_MODE" == "shadow" ]] && shadow_flag=1
	for (( index=1; index<=worker_count; index++ )); do
		local worker_id http_port
		worker_id="$(printf 'w%02d' "$index")"
		http_port=$((worker_http_base + index - 1))
		runtime_process_running "$worker_id" ||
			fail "cannot start gateway: $worker_id process is not validated"
		port_is_listening "$http_port" ||
			fail "cannot start gateway: $worker_id HTTP port $http_port is down"
		if [[ -n "$endpoints" ]]; then
			endpoints+=","
		fi
		endpoints+="$worker_id=http://127.0.0.1:$http_port"
	done
	runtime_process_running coordinator ||
		fail "cannot start gateway: coordinator process is not validated"
	port_is_listening "$coordinator_http" ||
		fail "cannot start gateway: coordinator HTTP port is down"
	if runtime_process_running gateway; then
		fail "runtime process already exists: gateway"
	fi
	if [[ "$TRAFFIC_MODE" == "active" ]]; then
		port_is_listening "$gateway_port" &&
			fail "gateway port $gateway_port is already occupied"
	fi
	[[ ! -f "$gateway_pid_file" ]] || rm "$gateway_pid_file"
	launch_detached "$gateway_session" \
		"cd '$ROOT_DIR' && umask 027 && export XIAND_WORKERS='$endpoints' XIAND_COORDINATOR_URL='http://127.0.0.1:$coordinator_http' XIAND_GATEWAY_HOST='0.0.0.0' XIAND_GATEWAY_PORT='$gateway_port' XIAND_WORKER_CAPACITY='$capacity' XIAND_MAP_WORKER_SHADOW='$shadow_flag' XIAND_GATEWAY_PID_FILE='$gateway_pid_file' XIAND_GATEWAY_LOCK_FILE='$run_dir/gateway.controller.lock' && exec python3 '$ROOT_DIR/tools/map_workers/gateway.py' >> '$run_dir/gateway.log' 2>&1"
	STARTED_SESSIONS+=("$gateway_session")
	STARTED_NODE_IDS+=("gateway")
	STARTED_MUD_PORTS+=("0")
	wait_for_runtime_process gateway
	if [[ "$TRAFFIC_MODE" == "active" ]]; then
		wait_for_port "$gateway_port" gateway
		log "ACTIVE isolated gateway ready with $worker_count workers"
	else
		wait_for_worker_registration "$coordinator_http" "$worker_count"
		log "SHADOW gateway controller ready with $worker_count workers"
	fi
}

cluster_status()
{
	local worker_count coordinator_http worker_http_base worker_mud_base gateway_port
	worker_count="$(config_value worker_count)"
	coordinator_http="$(config_value coordinator_http_port)"
	worker_http_base="$(config_value worker_http_base_port)"
	worker_mud_base="$(config_value worker_mud_base_port)"
	gateway_port="$(config_value gateway_port)"
	log "desired enabled=$(config_value enabled) mode=$(config_value traffic_mode) workers=$worker_count"
	if runtime_process_running coordinator; then
		log "xiand-${AREA_NAME}-coordinator: running"
	else
		log "xiand-${AREA_NAME}-coordinator: stopped"
	fi
	if runtime_process_running gateway; then
		log "xiand-${AREA_NAME}-gateway: running"
	else
		log "xiand-${AREA_NAME}-gateway: stopped"
	fi
	log "ports coordinator=$coordinator_http gateway=$gateway_port"
	for (( index=1; index<=worker_count; index++ )); do
		local worker_id http_port mud_port session
		worker_id="$(printf 'w%02d' "$index")"
		http_port=$((worker_http_base + index - 1))
		mud_port=$((worker_mud_base + index - 1))
		session="xiand-${AREA_NAME}-${worker_id}"
		if runtime_process_running "$worker_id" &&
		   port_is_listening "$http_port" && port_is_listening "$mud_port"; then
			log "$worker_id: running mud=$mud_port http=$http_port"
		else
			log "$worker_id: stopped mud=$mud_port http=$http_port"
		fi
	done
}

start_cluster()
{
	local enabled worker_count capacity coordinator_http worker_http_base
	local worker_mud_base gateway_port coordinator_mud run_dir
	validate_gateway_code
	enabled="$(config_value enabled)"
	[[ "$enabled" == "1" ]] || fail "worker mode is disabled in $CONFIG_FILE"
	worker_count="$(config_value worker_count)"
	capacity="$(config_value worker_capacity)"
	coordinator_http="$(config_value coordinator_http_port)"
	worker_http_base="$(config_value worker_http_base_port)"
	worker_mud_base="$(config_value worker_mud_base_port)"
	gateway_port="$(config_value gateway_port)"
	TRAFFIC_MODE="$(config_value traffic_mode)"
	if [[ "$TRAFFIC_MODE" == "active" &&
	      "${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}" != "isolated-test-server-only" ]]; then
		fail "active mode requires XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only"
	fi
	coordinator_mud=$((worker_mud_base - 1))
	(( coordinator_mud >= 1024 )) || fail "coordinator MUD port underflows"

	for port in "$coordinator_mud" "$coordinator_http"; do
		port_is_listening "$port" && fail "port $port is already occupied; stop standalone/old cluster explicitly"
	done
	if [[ "$TRAFFIC_MODE" == "active" ]]; then
		port_is_listening "$gateway_port" &&
			fail "gateway port $gateway_port is occupied; stop standalone/old cluster explicitly"
	fi
	for (( index=1; index<=worker_count; index++ )); do
		port_is_listening "$((worker_http_base + index - 1))" &&
			fail "worker HTTP port is occupied"
		port_is_listening "$((worker_mud_base + index - 1))" &&
			fail "worker MUD port is occupied"
	done

	run_dir="$(runtime_dir)"
	mkdir -p "$run_dir"
	chmod 750 "$ROOT_DIR/log" "$ROOT_DIR/log/map-workers" "$run_dir" 2>/dev/null || true
	STARTING_CLUSTER=1
	STARTED_SESSIONS=()
	STARTED_NODE_IDS=()
	STARTED_MUD_PORTS=()
	trap cleanup_partial_start ERR
	start_pike_node gateway coordinator "$coordinator_mud" "$coordinator_http"
	wait_for_port "$coordinator_http" coordinator

	for (( index=1; index<=worker_count; index++ )); do
		local worker_id http_port mud_port
		worker_id="$(printf 'w%02d' "$index")"
		http_port=$((worker_http_base + index - 1))
		mud_port=$((worker_mud_base + index - 1))
		start_pike_node worker "$worker_id" "$mud_port" "$http_port"
		wait_for_port "$http_port" "$worker_id"
	done

	start_gateway_controller "$worker_count" "$capacity" "$coordinator_http" \
		"$worker_http_base" "$gateway_port" "$run_dir"
	if [[ "$TRAFFIC_MODE" == "shadow" ]]; then
		log "SHADOW trial leaves standalone traffic unchanged"
	fi
	write_topology "$worker_count" "$worker_mud_base" "$coordinator_mud" \
		"$worker_http_base" "$coordinator_http" "$gateway_port" "$capacity"
	STARTING_CLUSTER=0
	trap - ERR
}

runtime_pid_file()
{
	echo "$(runtime_dir)/$1.pid"
}

terminate_runtime_process()
{
	local session="$1"
	local node_id="$2"
	local process_pid_file
	local pid=""
	local command_line=""
	process_pid_file="$(runtime_pid_file "$node_id")"
	if [[ -f "$process_pid_file" ]]; then
		pid="$(<"$process_pid_file")"
	fi
	if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1; then
		command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
		if [[ "$command_line" == *"$ROOT_DIR"* &&
		      ( "$command_line" == *"lowlib/driver.pike"* ||
		        "$command_line" == *"tools/map_workers/gateway.py"* ) ]]; then
			kill -TERM "$pid" >/dev/null 2>&1 || true
			local deadline=$((SECONDS + 15))
			while (( SECONDS < deadline )); do
				kill -0 "$pid" >/dev/null 2>&1 || break
				sleep 1
			done
			if kill -0 "$pid" >/dev/null 2>&1; then
				log "refusing to force-kill $node_id pid=$pid"
				return 1
			fi
		else
			log "refusing PID-file kill for unexpected $node_id process"
			return 1
		fi
	fi
	if session_exists "$session"; then
		screen -S "$session" -X quit >/dev/null 2>&1 || true
	fi
	[[ ! -f "$process_pid_file" ]] || rm "$process_pid_file"
}

graceful_node_stop()
{
	local session="$1"
	local mud_port="$2"
	local node_id="$3"
	if port_is_listening "$mud_port" && command -v nc >/dev/null 2>&1; then
		(
			sleep 1
			printf 'shutdown_safe\r\n'
			sleep 2
		) | nc -w 3 127.0.0.1 "$mud_port" >/dev/null 2>&1 || true
		local deadline=$((SECONDS + 30))
		while (( SECONDS < deadline )); do
			port_is_listening "$mud_port" || break
			sleep 1
		done
		if port_is_listening "$mud_port"; then
			log "safe shutdown timed out for $node_id; refusing forced stop"
			return 1
		fi
	fi
	terminate_runtime_process "$session" "$node_id"
}

stop_cluster()
{
	local worker_count worker_mud_base gateway_session
	local coordinator_mud
	if [[ -f "$(topology_file)" ]]; then
		worker_count="$(topology_value worker_count)"
		worker_mud_base="$(topology_value worker_mud_base_port)"
		coordinator_mud="$(topology_value coordinator_mud_port)"
	else
		worker_count="$(config_value worker_count)"
		worker_mud_base="$(config_value worker_mud_base_port)"
		coordinator_mud=$((worker_mud_base - 1))
	fi
	gateway_session="xiand-${AREA_NAME}-gateway"
	if session_exists "$gateway_session"; then
		terminate_runtime_process "$gateway_session" gateway
	elif [[ -f "$(runtime_pid_file gateway)" ]]; then
		terminate_runtime_process "$gateway_session" gateway
	fi
	for (( index=1; index<=worker_count; index++ )); do
		local worker_id
		worker_id="$(printf 'w%02d' "$index")"
		graceful_node_stop "xiand-${AREA_NAME}-${worker_id}" \
			"$((worker_mud_base + index - 1))" "$worker_id"
	done
	graceful_node_stop "xiand-${AREA_NAME}-coordinator" "$coordinator_mud" \
		coordinator
	if [[ -f "$(topology_file)" ]]; then
		rm "$(topology_file)"
	fi
	log "cluster stopped; the normal restart script remains the rollback path"
}

recover_gateway()
{
	local worker_count capacity coordinator_http worker_http_base gateway_port
	local run_dir
	[[ -f "$(topology_file)" ]] ||
		fail "cannot recover gateway without a validated running topology"
	validate_gateway_code
	worker_count="$(topology_value worker_count)"
	capacity="$(topology_value worker_capacity)"
	coordinator_http="$(topology_value coordinator_http_port)"
	worker_http_base="$(topology_value worker_http_base_port)"
	gateway_port="$(topology_value gateway_port)"
	TRAFFIC_MODE="$(topology_value traffic_mode)"
	if [[ "$TRAFFIC_MODE" == "active" &&
	      "${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}" != "isolated-test-server-only" ]]; then
		fail "active gateway recovery requires the isolated trial acknowledgement"
	fi
	run_dir="$(runtime_dir)"
	STARTING_CLUSTER=1
	STARTED_SESSIONS=()
	STARTED_NODE_IDS=()
	STARTED_MUD_PORTS=()
	trap cleanup_partial_start ERR
	start_gateway_controller "$worker_count" "$capacity" "$coordinator_http" \
		"$worker_http_base" "$gateway_port" "$run_dir"
	STARTING_CLUSTER=0
	trap - ERR
	log "gateway recovery completed only after worker inventory reconciliation"
}

main()
{
	cd "$ROOT_DIR"
	load_environment
	ensure_config
	case "$ACTION" in
		start|stop|recover-gateway|apply)
			acquire_orchestrator_lock
			snapshot_config
			;;
	esac
	TRAFFIC_MODE="$(config_value traffic_mode)"
	case "$ACTION" in
		validate)
			validate_gateway_code
			log "configuration is valid"
			;;
		status)
			cluster_status
			;;
		health)
			cluster_health
			;;
		start)
			start_cluster
			;;
		stop)
			stop_cluster
			;;
		recover-gateway)
			recover_gateway
			;;
		apply)
			if [[ "$(config_value enabled)" == "1" ]]; then
				if cluster_processes_running; then
					fail "cluster is already running; stop it before applying topology changes"
				fi
				start_cluster
			else
				stop_cluster
			fi
			;;
		*)
			fail "usage: $0 {validate|status|health|start|stop|recover-gateway|apply}"
			;;
	esac
}

main
