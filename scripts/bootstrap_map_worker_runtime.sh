#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${XIAND_ENV_FILE:-$ROOT_DIR/.env}"
CONFIG_FILE="${XIAND_MAP_WORKER_CONFIG:-$ROOT_DIR/data_xiand/map_workers/config.json}"
ENABLED="${XIAND_MAP_WORKER_ENABLED:-1}"
TRAFFIC_MODE="${XIAND_MAP_WORKER_TRAFFIC_MODE:-shadow}"
WORKER_COUNT="${XIAND_MAP_WORKER_COUNT:-3}"
WORKER_COUNT_OVERRIDE="${XIAND_MAP_WORKER_COUNT_OVERRIDE:-}"
WORKER_CAPACITY="${XIAND_MAP_WORKER_CAPACITY:-100}"

fail()
{
	echo "[map-worker-bootstrap] ERROR: $*" >&2
	exit 1
}

env_value()
{
	local key="$1"
	[[ -f "$ENV_FILE" ]] || return 0
	awk -F= -v wanted="$key" '
		$1 == wanted {
			value = substr($0, index($0, "=") + 1)
			print value
			exit
		}
	' "$ENV_FILE"
}

upsert_env()
{
	local key="$1"
	local value="$2"
	local temp_file
	temp_file="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
	awk -v wanted="$key" -v replacement="$value" '
		BEGIN { replaced = 0 }
		$0 ~ "^[[:space:]]*" wanted "=" {
			if (!replaced) {
				print wanted "=" replacement
				replaced = 1
			}
			next
		}
		{ print }
		END {
			if (!replaced)
				print wanted "=" replacement
		}
	' "$ENV_FILE" > "$temp_file"
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$ENV_FILE"
}

write_config()
{
	local config_dir
	local temp_file
	config_dir="$(dirname "$CONFIG_FILE")"
	[[ ! -L "$config_dir" ]] || fail "config directory must not be a symlink"
	mkdir -p "$config_dir"
	chmod 700 "$config_dir"
	temp_file="$(mktemp "$config_dir/.config.XXXXXX")"
	printf '%s\n' \
		'{' \
		'  "schema_version": 2,' \
		"  \"enabled\": $ENABLED," \
		"  \"traffic_mode\": \"$TRAFFIC_MODE\"," \
		"  \"worker_count\": $WORKER_COUNT," \
		"  \"worker_capacity\": $WORKER_CAPACITY," \
		'  "placement": "load_aware_rendezvous",' \
		'  "coordinator_http_port": 18880,' \
		'  "worker_http_base_port": 18881,' \
		'  "worker_mud_base_port": 14801,' \
		'  "gateway_port": 8888' \
		'}' > "$temp_file"
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$CONFIG_FILE"
}

update_worker_count()
{
	local temp_file
	temp_file="$(mktemp "$(dirname "$CONFIG_FILE")/.config.XXXXXX")"
	python3 - "$CONFIG_FILE" "$temp_file" "$WORKER_COUNT_OVERRIDE" <<'PY'
import json
import os
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
worker_count = int(sys.argv[3])
config = json.loads(source.read_text(encoding="utf-8"))
config["worker_count"] = worker_count
target.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
os.chmod(target, 0o600)
PY
	mv -f "$temp_file" "$CONFIG_FILE"
}

validate_config()
{
	python3 - "$CONFIG_FILE" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
config = json.loads(path.read_text(encoding="utf-8"))
required = {
    "schema_version", "enabled", "traffic_mode", "worker_count",
    "worker_capacity", "placement", "coordinator_http_port",
    "worker_http_base_port", "worker_mud_base_port", "gateway_port",
}
if set(config) != required:
    raise SystemExit("worker config keys do not match schema v2")
if type(config["schema_version"]) is not int or config["schema_version"] != 2:
    raise SystemExit("unsupported worker config schema_version")
if type(config["enabled"]) is not int or config["enabled"] not in (0, 1):
    raise SystemExit("worker config enabled must be 0 or 1")
if config["traffic_mode"] not in ("shadow", "active"):
    raise SystemExit("worker config traffic_mode must be shadow or active")
if type(config["worker_count"]) is not int or not 1 <= config["worker_count"] <= 16:
    raise SystemExit("worker config worker_count must be 1..16")
if type(config["worker_capacity"]) is not int or not 10 <= config["worker_capacity"] <= 10000:
    raise SystemExit("worker config worker_capacity must be 10..10000")
if config["placement"] != "load_aware_rendezvous":
    raise SystemExit("unsupported worker placement")
port_keys = (
    "coordinator_http_port", "worker_http_base_port",
    "worker_mud_base_port", "gateway_port",
)
if any(type(config[key]) is not int or not 1024 <= config[key] <= 65535
       for key in port_keys):
    raise SystemExit("worker config ports must be integers in 1024..65535")
count = config["worker_count"]
if config["worker_http_base_port"] + count - 1 > 65535:
    raise SystemExit("worker HTTP port range overflows")
if config["worker_mud_base_port"] + count - 1 > 65535:
    raise SystemExit("worker MUD port range overflows")
ports = [
    config["coordinator_http_port"], config["worker_mud_base_port"] - 1,
    config["gateway_port"],
]
ports += list(range(config["worker_http_base_port"],
                    config["worker_http_base_port"] + count))
ports += list(range(config["worker_mud_base_port"],
                    config["worker_mud_base_port"] + count))
if any(not 1024 <= port <= 65535 for port in ports):
    raise SystemExit("worker config derived ports must be in 1024..65535")
if len(set(ports)) != len(ports):
    raise SystemExit("worker config ports overlap")
print("\t".join(str(config[key]) for key in
                ("enabled", "traffic_mode", "worker_count", "worker_capacity")))
PY
}

main()
{
	local env_dir
	local worker_token="${XIAND_WORKER_TOKEN:-}"
	local config_values
	local actual_enabled
	local actual_traffic_mode
	local actual_worker_count
	local actual_worker_capacity
	local config_dir
	local write_requested=0
	[[ "$ENABLED" == "0" || "$ENABLED" == "1" ]] ||
		fail "XIAND_MAP_WORKER_ENABLED must be 0 or 1"
	[[ "$TRAFFIC_MODE" == "shadow" || "$TRAFFIC_MODE" == "active" ]] ||
		fail "XIAND_MAP_WORKER_TRAFFIC_MODE must be shadow or active"
	[[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] &&
		(( WORKER_COUNT >= 1 && WORKER_COUNT <= 16 )) ||
		fail "XIAND_MAP_WORKER_COUNT must be 1..16"
	if [[ -n "$WORKER_COUNT_OVERRIDE" ]]; then
		[[ "$WORKER_COUNT_OVERRIDE" =~ ^[0-9]+$ ]] &&
			(( WORKER_COUNT_OVERRIDE >= 1 && WORKER_COUNT_OVERRIDE <= 16 )) ||
			fail "XIAND_MAP_WORKER_COUNT_OVERRIDE must be 1..16"
		WORKER_COUNT="$WORKER_COUNT_OVERRIDE"
	fi
	[[ "$WORKER_CAPACITY" =~ ^[0-9]+$ ]] &&
		(( WORKER_CAPACITY >= 10 && WORKER_CAPACITY <= 10000 )) ||
		fail "XIAND_MAP_WORKER_CAPACITY must be 10..10000"
	config_dir="$(dirname "$CONFIG_FILE")"
	[[ ! -L "$config_dir" ]] || fail "config directory must not be a symlink"
	if [[ ! -f "$CONFIG_FILE" ||
	      "${XIAND_MAP_WORKER_REGENERATE_CONFIG:-0}" == "1" ]]; then
		write_requested=1
	fi
	if [[ "$write_requested" == "1" && "$ENABLED" == "1" &&
	      "$TRAFFIC_MODE" == "active" &&
	      "${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}" != "isolated-test-server-only" ]]; then
		fail "active mode requires the isolated test acknowledgement"
	fi
	env_dir="$(dirname "$ENV_FILE")"
	[[ ! -L "$ENV_FILE" ]] || fail ".env must not be a symlink"
	mkdir -p "$env_dir"
	if [[ ! -f "$ENV_FILE" ]]; then
		(umask 077 && : > "$ENV_FILE")
	fi
	chmod 600 "$ENV_FILE"
	if [[ -z "$worker_token" ]]; then
		worker_token="$(env_value XIAND_WORKER_TOKEN)"
	fi
	if (( ${#worker_token} < 32 )); then
		command -v openssl >/dev/null 2>&1 ||
			fail "openssl is required to generate XIAND_WORKER_TOKEN"
		worker_token="$(openssl rand -hex 32)"
	fi
	[[ "$worker_token" =~ ^[A-Za-z0-9._~-]+$ ]] ||
		fail "XIAND_WORKER_TOKEN contains unsupported characters"

	[[ ! -L "$CONFIG_FILE" ]] || fail "worker config must not be a symlink"
	if [[ "$write_requested" == "1" ]]; then
		write_config
	elif [[ -n "$WORKER_COUNT_OVERRIDE" ]]; then
		update_worker_count
	fi
	chmod 600 "$CONFIG_FILE"
	config_values="$(validate_config)"
	IFS=$'\t' read -r actual_enabled actual_traffic_mode \
		actual_worker_count actual_worker_capacity <<< "$config_values"
	if [[ "$actual_enabled" == "1" && "$actual_traffic_mode" == "active" &&
	      ! -f "$(dirname "$CONFIG_FILE")/fallback-latched" &&
	      "${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}" != "isolated-test-server-only" ]]; then
		fail "active mode requires the isolated test acknowledgement"
	fi
	upsert_env XIAND_WORKER_TOKEN "$worker_token"
	upsert_env XIAND_MAP_WORKER_ENABLED "$actual_enabled"
	upsert_env XIAND_MAP_WORKER_TRAFFIC_MODE "$actual_traffic_mode"
	upsert_env XIAND_MAP_WORKER_COUNT "$actual_worker_count"
	upsert_env XIAND_MAP_WORKER_CAPACITY "$actual_worker_capacity"
	echo "[map-worker-bootstrap] ready: mode=$actual_traffic_mode workers=$actual_worker_count config=$CONFIG_FILE"
}

main "$@"
