#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_SCRIPT="$ROOT_DIR/scripts/map_worker_cluster.sh"
RESTART_TESTUNIT="$ROOT_DIR/scripts/restart_with_testunit.sh"

log()
{
	echo "[local-workers] $*"
}

main()
{
	cd "$ROOT_DIR"
	# This wrapper is intentionally for an isolated local trial. The explicit
	# command is the active-mode acknowledgement required by the cluster script.
	export XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only

	log "stopping the previous local worker topology, if present"
	"$CLUSTER_SCRIPT" stop

	log "restarting standalone once to run the complete Pike TestUnit suite"
	XIAND_STOP_AFTER_TESTUNIT=1 "$RESTART_TESTUNIT"

	log "starting the requested local worker topology"
	XIAND_MAP_WORKER_RUN_SELFTESTS=1 "$CLUSTER_SCRIPT" start "$@"
	"$CLUSTER_SCRIPT" health
	log "local worker test environment is ready"
}

main "$@"
