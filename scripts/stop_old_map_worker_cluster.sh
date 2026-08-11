#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
	echo "usage: $0 CONTAINER_NAME AREA_NAME" >&2
	exit 2
fi

container_name="$1"
area_name="$2"
for attempt in 1 2; do
	stop_output=""
	stop_status=0
	if stop_output="$(docker exec \
		-e XIAND_MAP_WORKER_LAUNCHER=background \
		-e XIAND_MAP_WORKER_AREA_NAME="$area_name" \
		"$container_name" \
		/app/xiand/scripts/map_worker_cluster.sh stop 2>&1)"; then
		[[ -z "$stop_output" ]] || printf '%s\n' "$stop_output"
		exit 0
	else
		stop_status=$?
	fi
	compact_output="$(printf '%s' "$stop_output" | tr -d '[:space:]')"
	if (( attempt == 1 )) &&
	   [[ "$compact_output" == *'"code":"gateway_not_quiescent"'* ]] &&
	   [[ "$compact_output" == *'"uncertain_requests":0'* ]] &&
	   [[ "$compact_output" == *'"pending_reconcile_users":0'* ]] &&
	   [[ "$compact_output" == *'"background_arrivals":0'* ]] &&
	   [[ "$stop_output" == *"Traceback"* ]]; then
		echo "[INFO] 旧版停机脚本遇到瞬时409，自动重新执行一次安全存档证明..." >&2
		sleep 1
		continue
	fi
	[[ -z "$stop_output" ]] || printf '%s\n' "$stop_output" >&2
	exit "$stop_status"
done

exit 1
