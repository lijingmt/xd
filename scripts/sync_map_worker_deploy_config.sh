#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_CONFIG="${XIAND_MAP_WORKER_DEPLOY_CONFIG:-}"
TARGET_CONFIG="${XIAND_MAP_WORKER_CONFIG:-}"

fail()
{
	echo "[map-worker-config] ERROR: $*" >&2
	exit 1
}

[[ -n "$SOURCE_CONFIG" ]] || fail "XIAND_MAP_WORKER_DEPLOY_CONFIG is required"
[[ -n "$TARGET_CONFIG" ]] || fail "XIAND_MAP_WORKER_CONFIG is required"
[[ -f "$SOURCE_CONFIG" && ! -L "$SOURCE_CONFIG" ]] ||
	fail "deploy config must be a regular non-symlink file"
[[ ! -L "$TARGET_CONFIG" ]] || fail "target config must not be a symlink"

target_dir="$(dirname "$TARGET_CONFIG")"
[[ ! -L "$target_dir" ]] || fail "target config directory must not be a symlink"
mkdir -p "$target_dir"
chmod 700 "$target_dir"
temporary="$(mktemp "$target_dir/.deploy-config.XXXXXX")"
cleanup()
{
	if [[ -f "$temporary" ]]; then
		unlink "$temporary"
	fi
}
trap cleanup EXIT INT TERM

python3 - "$SOURCE_CONFIG" "$temporary" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
try:
    if source.stat().st_size > 65536:
        raise OSError("deploy config exceeds 64 KiB")
    config = json.loads(source.read_text(encoding="utf-8"))
except (OSError, UnicodeError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid deploy config: {error}")

required = {
    "schema_version", "enabled", "traffic_mode", "worker_count",
    "worker_capacity", "placement", "coordinator_http_port",
    "worker_http_base_port", "worker_mud_base_port", "gateway_port",
}
if set(config) != required:
    raise SystemExit("deploy config keys do not match schema v2")
if type(config["schema_version"]) is not int or config["schema_version"] != 2:
    raise SystemExit("unsupported deploy config schema_version")
if type(config["enabled"]) is not int or config["enabled"] not in (0, 1):
    raise SystemExit("deploy config enabled must be 0 or 1")
if config["traffic_mode"] not in ("shadow", "active"):
    raise SystemExit("deploy config traffic_mode must be shadow or active")
if type(config["worker_count"]) is not int or not 1 <= config["worker_count"] <= 16:
    raise SystemExit("deploy config worker_count must be 1..16")
if (type(config["worker_capacity"]) is not int or
        not 10 <= config["worker_capacity"] <= 10000):
    raise SystemExit("deploy config worker_capacity must be 10..10000")
if config["placement"] != "load_aware_rendezvous":
    raise SystemExit("unsupported deploy config placement")

port_keys = (
    "coordinator_http_port", "worker_http_base_port",
    "worker_mud_base_port", "gateway_port",
)
if any(type(config[key]) is not int or not 1024 <= config[key] <= 65535
       for key in port_keys):
    raise SystemExit("deploy config ports must be integers in 1024..65535")
count = config["worker_count"]
ports = [
    config["coordinator_http_port"],
    config["worker_mud_base_port"] - 1,
    config["gateway_port"],
]
ports += list(range(config["worker_http_base_port"],
                    config["worker_http_base_port"] + count))
ports += list(range(config["worker_mud_base_port"],
                    config["worker_mud_base_port"] + count))
if any(not 1024 <= port <= 65535 for port in ports):
    raise SystemExit("deploy config derived ports must be in 1024..65535")
if len(set(ports)) != len(ports):
    raise SystemExit("deploy config ports overlap")

target.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
PY

chmod 600 "$temporary"
mv -f "$temporary" "$TARGET_CONFIG"
trap - EXIT INT TERM
mode="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["traffic_mode"])' "$TARGET_CONFIG")"
workers="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worker_count"])' "$TARGET_CONFIG")"
echo "[map-worker-config] synced mode=$mode workers=$workers target=$TARGET_CONFIG"
