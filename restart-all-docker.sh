#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XIAND_MAP_WORKER_DEPLOY_CONFIG="${XIAND_MAP_WORKER_DEPLOY_CONFIG:-$SCRIPT_DIR/deploy/map_workers/config.json}"
export XIAND_MAP_WORKER_DEPLOY_CONFIG
exec "$SCRIPT_DIR/restart-docker.sh" xd01-02 2002 2003 "$@"
