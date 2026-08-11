#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"

# Deployment validation runs inside the final container and therefore inherits
# its active worker settings.  These tests own their fixtures and must not let
# the real deployment mode change the expected shadow/override cases.
unset XIAND_MAP_WORKER_ENABLED
unset XIAND_MAP_WORKER_TRAFFIC_MODE
unset XIAND_MAP_WORKER_COUNT
unset XIAND_MAP_WORKER_COUNT_OVERRIDE
unset XIAND_MAP_WORKER_CAPACITY
unset XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK
unset XIAND_MAP_WORKER_DEPLOY_CONFIG

cleanup()
{
	rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

file_mode()
{
	if stat -f '%Lp' "$1" >/dev/null 2>&1; then
		stat -f '%Lp' "$1"
	else
		stat -c '%a' "$1"
	fi
}

file_owner_group()
{
	if stat -f '%u:%g' "$1" >/dev/null 2>&1; then
		stat -f '%u:%g' "$1"
	else
		stat -c '%u:%g' "$1"
	fi
}

config_checksum()
{
	cksum "$1" | awk '{print $1 ":" $2}'
}

# A fresh pull can create a secure deployment environment non-interactively
# when MYSQL_PASSWORD is supplied by deployment automation. A repeated run
# rebuilds the file from the latest template, preserves only MYSQL_PASSWORD,
# and rotates generated internal tokens.
DEPLOY_ENV_FILE="$TEST_ROOT/deploy/.env"
MYSQL_PASSWORD='fixture-password-with-$-and-space' \
	"$ROOT_DIR/scripts/setup_deploy_env.sh" "$DEPLOY_ENV_FILE" >/dev/null
[[ -f "$DEPLOY_ENV_FILE" ]]
[[ ! -L "$DEPLOY_ENV_FILE" ]]
[[ "$(file_mode "$DEPLOY_ENV_FILE")" == "600" ]]
DEPLOY_ENV_CHECKSUM="$(config_checksum "$DEPLOY_ENV_FILE")"
DEPLOY_ENV_OWNER_GROUP="$(file_owner_group "$DEPLOY_ENV_FILE")"
(
	set -a
	# shellcheck disable=SC1090
	. "$DEPLOY_ENV_FILE"
	set +a
	[[ "$MYSQL_PASSWORD" == 'fixture-password-with-$-and-space' ]]
	[[ ${#XIAND_WORKER_TOKEN} -ge 32 ]]
	[[ ${#XIAND_HEALTH_TOKEN} -ge 24 ]]
)
printf '%s\n' 'LEGACY_REMOVED_SETTING=stale' >> "$DEPLOY_ENV_FILE"
FIRST_WORKER_TOKEN="$(
	set -a
	# shellcheck disable=SC1090
	. "$DEPLOY_ENV_FILE"
	set +a
	printf '%s' "$XIAND_WORKER_TOKEN"
))"
MYSQL_PASSWORD='replacement-must-not-overwrite-existing' \
	"$ROOT_DIR/scripts/setup_deploy_env.sh" "$DEPLOY_ENV_FILE" >/dev/null
[[ "$(config_checksum "$DEPLOY_ENV_FILE")" != "$DEPLOY_ENV_CHECKSUM" ]]
[[ "$(file_owner_group "$DEPLOY_ENV_FILE")" == "$DEPLOY_ENV_OWNER_GROUP" ]]
(
	set -a
	# shellcheck disable=SC1090
	. "$DEPLOY_ENV_FILE"
	set +a
	[[ "$MYSQL_PASSWORD" == 'fixture-password-with-$-and-space' ]]
	[[ ${#XIAND_WORKER_TOKEN} -ge 32 ]]
	[[ ${#XIAND_HEALTH_TOKEN} -ge 24 ]]
	[[ "$XIAND_WORKER_TOKEN" != "$FIRST_WORKER_TOKEN" ]]
	[[ -z "${LEGACY_REMOVED_SETTING:-}" ]]
	[[ "$XIAND_MAP_WORKER_COUNT" == "3" ]]
)
ln -s "$DEPLOY_ENV_FILE" "$TEST_ROOT/deploy-env-link"
if MYSQL_PASSWORD=fixture \
	"$ROOT_DIR/scripts/setup_deploy_env.sh" \
	"$TEST_ROOT/deploy-env-link" >/dev/null 2>&1; then
	echo "symlink deployment .env was accepted" >&2
	exit 1
fi

ENV_FILE="$TEST_ROOT/.env"
CONFIG_FILE="$TEST_ROOT/map_workers/config.json"
XIAND_ENV_FILE="$ENV_FILE" \
XIAND_MAP_WORKER_CONFIG="$CONFIG_FILE" \
XIAND_MAP_WORKER_COUNT=3 \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null
FIRST_CHECKSUM="$(config_checksum "$CONFIG_FILE")"

# Existing admin configuration is authoritative over stale deploy defaults.
XIAND_ENV_FILE="$ENV_FILE" \
XIAND_MAP_WORKER_CONFIG="$CONFIG_FILE" \
XIAND_MAP_WORKER_COUNT=4 \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null
SECOND_CHECKSUM="$(config_checksum "$CONFIG_FILE")"
[[ "$FIRST_CHECKSUM" == "$SECOND_CHECKSUM" ]]
[[ "$(awk -F= '$1=="XIAND_MAP_WORKER_COUNT" {print $2}' "$ENV_FILE")" == "3" ]]
[[ "$(file_mode "$ENV_FILE")" == "600" ]]
[[ "$(file_mode "$CONFIG_FILE")" == "600" ]]

# A deliberate one-shot CLI override changes only worker_count. Other admin
# settings remain authoritative.
XIAND_ENV_FILE="$ENV_FILE" \
XIAND_MAP_WORKER_CONFIG="$CONFIG_FILE" \
XIAND_MAP_WORKER_COUNT_OVERRIDE=4 \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worker_count"])' "$CONFIG_FILE")" == "4" ]]
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["traffic_mode"])' "$CONFIG_FILE")" == "shadow" ]]
[[ "$(awk -F= '$1=="XIAND_MAP_WORKER_COUNT" {print $2}' "$ENV_FILE")" == "4" ]]
if XIAND_ENV_FILE="$ENV_FILE" \
   XIAND_MAP_WORKER_CONFIG="$CONFIG_FILE" \
   XIAND_MAP_WORKER_COUNT_OVERRIDE=17 \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null 2>&1; then
	echo "out-of-range worker override was accepted" >&2
	exit 1
fi
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worker_count"])' "$CONFIG_FILE")" == "4" ]]

if sed --version >/dev/null 2>&1; then
	sed -i 's/"enabled": 1/"enabled": true/' "$CONFIG_FILE"
else
	sed -i '' 's/"enabled": 1/"enabled": true/' "$CONFIG_FILE"
fi
if XIAND_ENV_FILE="$ENV_FILE" \
   XIAND_MAP_WORKER_CONFIG="$CONFIG_FILE" \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null 2>&1; then
	echo "malformed boolean config was accepted" >&2
	exit 1
fi

SYMLINK_ROOT="$TEST_ROOT/symlink-case"
mkdir -p "$SYMLINK_ROOT/real"
ln -s "$SYMLINK_ROOT/real" "$SYMLINK_ROOT/map_workers"
if XIAND_ENV_FILE="$SYMLINK_ROOT/.env" \
   XIAND_MAP_WORKER_CONFIG="$SYMLINK_ROOT/map_workers/config.json" \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null 2>&1; then
	echo "symlink config directory was accepted" >&2
	exit 1
fi

ACTIVE_ROOT="$TEST_ROOT/active-case"
if XIAND_ENV_FILE="$ACTIVE_ROOT/.env" \
   XIAND_MAP_WORKER_CONFIG="$ACTIVE_ROOT/map_workers/config.json" \
   XIAND_MAP_WORKER_TRAFFIC_MODE=active \
   XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK= \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null 2>&1; then
	echo "unacknowledged active config was accepted" >&2
	exit 1
fi
[[ ! -e "$ACTIVE_ROOT/map_workers/config.json" ]]
XIAND_ENV_FILE="$ACTIVE_ROOT/.env" \
XIAND_MAP_WORKER_CONFIG="$ACTIVE_ROOT/map_workers/config.json" \
XIAND_MAP_WORKER_TRAFFIC_MODE=active \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null

# The production wrapper's reviewed Git config replaces the host config
# atomically, while preserving independent circuit-breaker state.
SYNC_ROOT="$TEST_ROOT/deploy-sync"
SYNC_TARGET="$SYNC_ROOT/map_workers/config.json"
mkdir -p "$SYNC_ROOT/map_workers"
printf '%s\n' 'fallback-fixture' > "$SYNC_ROOT/map_workers/fallback-latched"
XIAND_MAP_WORKER_DEPLOY_CONFIG="$ROOT_DIR/deploy/map_workers/config.json" \
XIAND_MAP_WORKER_CONFIG="$SYNC_TARGET" \
	"$ROOT_DIR/scripts/sync_map_worker_deploy_config.sh" >/dev/null
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["traffic_mode"])' "$SYNC_TARGET")" == "active" ]]
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worker_count"])' "$SYNC_TARGET")" == "5" ]]
[[ "$(file_mode "$SYNC_TARGET")" == "600" ]]
[[ -f "$SYNC_ROOT/map_workers/fallback-latched" ]]

# A one-shot worker count override remains available after Git config sync.
XIAND_ENV_FILE="$SYNC_ROOT/.env" \
XIAND_MAP_WORKER_CONFIG="$SYNC_TARGET" \
XIAND_MAP_WORKER_COUNT_OVERRIDE=7 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
	"$ROOT_DIR/scripts/bootstrap_map_worker_runtime.sh" >/dev/null
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["traffic_mode"])' "$SYNC_TARGET")" == "active" ]]
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worker_count"])' "$SYNC_TARGET")" == "7" ]]

# A historical active fallback latch is recovered only after a proven safe
# stop and a clean persisted ownership inventory.  The latch remains when the
# acknowledgement is absent or any lease/social event is still live.
RECOVERY_ROOT="$TEST_ROOT/fallback-recovery"
RECOVERY_DIR="$RECOVERY_ROOT/map_workers"
RECOVERY_SCRIPT="$ROOT_DIR/scripts/recover_map_worker_fallback_latch.sh"
mkdir -p "$RECOVERY_DIR/social_outbox"
cp "$ROOT_DIR/deploy/map_workers/config.json" "$RECOVERY_DIR/config.json"
printf '%s\n' 'fixture-worker-health-failure' > \
	"$RECOVERY_DIR/fallback-latched"
python3 - "$RECOVERY_DIR" <<'PY'
import json
import pathlib
import sys
import time

root = pathlib.Path(sys.argv[1])
now = int(time.time())
control = {
    "version": 3,
    "player_leases": {
        "fixture": {
            "state": "active",
            "expires_at": now - 60,
        },
    },
    "handoffs": {
        "fixture": {
            "state": "committed",
            "expires_at": now - 60,
        },
    },
    "envelopes": {},
    "escrow_transactions": {},
    "pk_sessions": {},
}
outbox = {
    "version": 1,
    "events": {
        "fixture": {
            "kind": "team_snapshot",
            "expires_at": now - 60,
        },
    },
}
(root / "control_plane.json").write_text(
    json.dumps(control), encoding="utf-8")
(root / "control_plane.json.bak").write_text(
    json.dumps(control), encoding="utf-8")
(root / "social_outbox" / "w01.json").write_text(
    json.dumps(outbox), encoding="utf-8")
(root / "social_outbox" / "w01.json.bak").write_text(
    json.dumps(outbox), encoding="utf-8")
PY
XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=1 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK= \
	"$RECOVERY_SCRIPT" "$RECOVERY_DIR" >/dev/null
[[ -f "$RECOVERY_DIR/fallback-latched" ]]
XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=0 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
	"$RECOVERY_SCRIPT" "$RECOVERY_DIR" >/dev/null
[[ -f "$RECOVERY_DIR/fallback-latched" ]]
python3 - "$RECOVERY_DIR/control_plane.json" <<'PY'
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
control = json.loads(path.read_text(encoding="utf-8"))
control["player_leases"]["fixture"]["expires_at"] = int(time.time()) + 600
path.write_text(json.dumps(control), encoding="utf-8")
PY
XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=1 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
XIAND_MAP_WORKER_FORCE_ACTIVE=1 \
	"$RECOVERY_SCRIPT" "$RECOVERY_DIR" >/dev/null
[[ -f "$RECOVERY_DIR/fallback-latched" ]]
python3 - "$RECOVERY_DIR/control_plane.json" <<'PY'
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
control = json.loads(path.read_text(encoding="utf-8"))
control["player_leases"]["fixture"]["expires_at"] = int(time.time()) - 60
path.write_text(json.dumps(control), encoding="utf-8")
PY
XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=1 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
XIAND_MAP_WORKER_FORCE_ACTIVE=1 \
	"$RECOVERY_SCRIPT" "$RECOVERY_DIR" >/dev/null
[[ ! -e "$RECOVERY_DIR/fallback-latched" ]]
RECOVERY_ARCHIVE="$(find "$RECOVERY_DIR/fallback-history" -maxdepth 1 \
	-type f -name 'fallback-latched.*' -print)"
[[ -n "$RECOVERY_ARCHIVE" ]]
[[ "$(file_mode "$RECOVERY_ARCHIVE")" == "600" ]]
[[ "$(<"$RECOVERY_ARCHIVE")" == "fixture-worker-health-failure" ]]
XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=1 \
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
XIAND_MAP_WORKER_FORCE_ACTIVE=1 \
	"$RECOVERY_SCRIPT" "$RECOVERY_DIR" >/dev/null

RECOVERY_SYMLINK_DIR="$TEST_ROOT/fallback-recovery-symlink"
mkdir -p "$RECOVERY_SYMLINK_DIR"
cp "$ROOT_DIR/deploy/map_workers/config.json" \
	"$RECOVERY_SYMLINK_DIR/config.json"
ln -s "$RECOVERY_SYMLINK_DIR/missing-latch-target" \
	"$RECOVERY_SYMLINK_DIR/fallback-latched"
if XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED=1 \
   XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only \
   XIAND_MAP_WORKER_FORCE_ACTIVE=1 \
	"$RECOVERY_SCRIPT" "$RECOVERY_SYMLINK_DIR" >/dev/null 2>&1; then
	echo "symlinked fallback latch was accepted" >&2
	exit 1
fi

# Invalid or symlinked Git inputs fail before replacing the last valid target.
VALID_SYNC_CHECKSUM="$(config_checksum "$SYNC_TARGET")"
INVALID_SYNC_SOURCE="$SYNC_ROOT/invalid.json"
printf '%s\n' '{"schema_version":2,"enabled":1}' > "$INVALID_SYNC_SOURCE"
if XIAND_MAP_WORKER_DEPLOY_CONFIG="$INVALID_SYNC_SOURCE" \
   XIAND_MAP_WORKER_CONFIG="$SYNC_TARGET" \
	"$ROOT_DIR/scripts/sync_map_worker_deploy_config.sh" >/dev/null 2>&1; then
	echo "invalid Git worker config was accepted" >&2
	exit 1
fi
[[ "$(config_checksum "$SYNC_TARGET")" == "$VALID_SYNC_CHECKSUM" ]]

OVERSIZED_SYNC_SOURCE="$SYNC_ROOT/oversized.json"
python3 - "$OVERSIZED_SYNC_SOURCE" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text(" " * 65537, encoding="utf-8")
PY
if XIAND_MAP_WORKER_DEPLOY_CONFIG="$OVERSIZED_SYNC_SOURCE" \
   XIAND_MAP_WORKER_CONFIG="$SYNC_TARGET" \
	"$ROOT_DIR/scripts/sync_map_worker_deploy_config.sh" >/dev/null 2>&1; then
	echo "oversized Git worker config was accepted" >&2
	exit 1
fi
[[ "$(config_checksum "$SYNC_TARGET")" == "$VALID_SYNC_CHECKSUM" ]]
ln -s "$ROOT_DIR/deploy/map_workers/config.json" "$SYNC_ROOT/config-link.json"
if XIAND_MAP_WORKER_DEPLOY_CONFIG="$SYNC_ROOT/config-link.json" \
   XIAND_MAP_WORKER_CONFIG="$SYNC_TARGET" \
	"$ROOT_DIR/scripts/sync_map_worker_deploy_config.sh" >/dev/null 2>&1; then
	echo "symlinked Git worker config was accepted" >&2
	exit 1
fi
[[ "$(config_checksum "$SYNC_TARGET")" == "$VALID_SYNC_CHECKSUM" ]]

# restart-docker performs the same validation against a temporary target
# before stopping the live container.
RESTART_SOURCE="$(sed -n '1,420p' "$ROOT_DIR/restart-docker.sh")"
[[ "$RESTART_SOURCE" == *"preflight_map_worker_deploy_config"* ]]
[[ "$RESTART_SOURCE" == *"Git worker配置预检失败，旧容器保持运行"* ]]
[[ "$RESTART_SOURCE" == *"宿主worker配置路径不安全，旧容器保持运行"* ]]
[[ -x "$RECOVERY_SCRIPT" ]]
grep -q '^recover_historical_map_worker_fallback()' \
	"$ROOT_DIR/restart-docker.sh"
grep -q '^\trecover_historical_map_worker_fallback$' \
	"$ROOT_DIR/restart-docker.sh"
grep -q -- '--force-active)' "$ROOT_DIR/restart-docker.sh"
grep -q 'XIAND_MAP_WORKER_FORCE_ACTIVE' "$ROOT_DIR/restart-docker.sh"
grep -q -- '--force-active 未能进入 active' "$ROOT_DIR/restart-docker.sh"
grep -q 'mandatory ownership audit remains enabled' "$RECOVERY_SCRIPT"
PREFLIGHT_CALL_LINE="$(grep -n '^    preflight_map_worker_deploy_config$' \
	"$ROOT_DIR/restart-docker.sh" | tail -1 | cut -d: -f1)"
STOP_CALL_LINE="$(grep -n '^    stop_existing_container_safely$' \
	"$ROOT_DIR/restart-docker.sh" | tail -1 | cut -d: -f1)"
[[ -n "$PREFLIGHT_CALL_LINE" && -n "$STOP_CALL_LINE" ]]
[[ "$PREFLIGHT_CALL_LINE" -lt "$STOP_CALL_LINE" ]]

echo "map worker bootstrap tests passed"
