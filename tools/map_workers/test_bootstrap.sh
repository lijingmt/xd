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

config_checksum()
{
	cksum "$1" | awk '{print $1 ":" $2}'
}

# A fresh pull can create a secure deployment environment non-interactively
# when MYSQL_PASSWORD is supplied by deployment automation. Existing secrets
# and generated tokens must remain stable on repeated runs.
DEPLOY_ENV_FILE="$TEST_ROOT/deploy/.env"
MYSQL_PASSWORD='fixture-password-with-$-and-space' \
	"$ROOT_DIR/scripts/setup_deploy_env.sh" "$DEPLOY_ENV_FILE" >/dev/null
[[ -f "$DEPLOY_ENV_FILE" ]]
[[ ! -L "$DEPLOY_ENV_FILE" ]]
[[ "$(file_mode "$DEPLOY_ENV_FILE")" == "600" ]]
DEPLOY_ENV_CHECKSUM="$(config_checksum "$DEPLOY_ENV_FILE")"
(
	set -a
	# shellcheck disable=SC1090
	. "$DEPLOY_ENV_FILE"
	set +a
	[[ "$MYSQL_PASSWORD" == 'fixture-password-with-$-and-space' ]]
	[[ ${#XIAND_WORKER_TOKEN} -ge 32 ]]
	[[ ${#XIAND_HEALTH_TOKEN} -ge 24 ]]
)
MYSQL_PASSWORD='replacement-must-not-overwrite-existing' \
	"$ROOT_DIR/scripts/setup_deploy_env.sh" "$DEPLOY_ENV_FILE" >/dev/null
[[ "$(config_checksum "$DEPLOY_ENV_FILE")" == "$DEPLOY_ENV_CHECKSUM" ]]
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

echo "map worker bootstrap tests passed"
