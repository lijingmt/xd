#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"

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
