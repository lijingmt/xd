#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_SCRIPT="$ROOT_DIR/scripts/map_worker_cluster.sh"
export XIAND_STARTUP_LIBRARY_ONLY=1
source "$ROOT_DIR/docker/start-unified.sh"

CALLS=""

record_call()
{
	if [[ -n "$CALLS" ]]; then
		CALLS+=" "
	fi
	CALLS+="$1"
}

latch_active_fallback()
{
	record_call latch
}

stop_cluster_safely()
{
	record_call stop
	return 0
}

start_legacy_main()
{
	record_call legacy
}

write_runtime_mode()
{
	record_call "mode:$1"
}

fallback_to_legacy active
[[ "$CALLS" == "latch stop legacy mode:legacy-fallback" ]] || {
	echo "active fallback order is unsafe: $CALLS" >&2
	exit 1
}

CALLS=""
fallback_to_legacy shadow
[[ "$CALLS" == "stop mode:shadow-degraded" ]] || {
	echo "shadow fallback must keep the existing legacy main: $CALLS" >&2
	exit 1
}

(
	CALLS=""
	start_cluster()
	{
		record_call cluster
		return 1
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	start_shadow_authority
	[[ "$CALLS" == "cluster fallback:shadow" ]] || {
		echo "shadow startup failure did not preserve legacy authority: $CALLS" >&2
		exit 1
	}
)

(
	CALLS=""
	start_cluster()
	{
		record_call cluster
		return 0
	}
	write_runtime_mode()
	{
		record_call "mode:$1"
	}
	start_shadow_authority
	[[ "$CALLS" == "cluster mode:shadow" ]] || {
		echo "healthy shadow startup did not publish shadow mode: $CALLS" >&2
		exit 1
	}
)

(
	CALLS=""
	XIAND_ACTIVE_START_RETRY_WAIT=0
	start_cluster()
	{
		record_call cluster
		return 1
	}
	wait_for_http_health()
	{
		record_call unexpected-health
		return 0
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	start_active_authority
	[[ "$CALLS" == "cluster stop cluster stop cluster fallback:active" ]] || {
		echo "active process startup failure did not open fallback circuit: $CALLS" >&2
		exit 1
	}
)

(
	CALLS=""
	XIAND_ACTIVE_START_RETRY_WAIT=0
	start_cluster()
	{
		record_call cluster
		return 0
	}
	wait_for_http_health()
	{
		record_call health
		return 1
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	start_active_authority
	[[ "$CALLS" == "cluster health stop cluster health stop cluster health fallback:active" ]] || {
		echo "active startup failure did not open fallback circuit: $CALLS" >&2
		exit 1
	}
)

# 拓扑首轮未就绪但第二轮转健康时：安全排水一次后应发布 active，
# 而不是把整个部署打回 legacy-fallback。
(
	CALLS=""
	XIAND_ACTIVE_START_RETRY_WAIT=0
	health_attempts=0
	start_cluster()
	{
		record_call cluster
		return 0
	}
	wait_for_http_health()
	{
		record_call health
		health_attempts=$((health_attempts + 1))
		(( health_attempts >= 2 ))
	}
	stop_cluster_safely()
	{
		record_call drain
		return 0
	}
	write_runtime_mode()
	{
		record_call "mode:$1"
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	start_active_authority
	[[ "$CALLS" == "cluster health drain cluster health mode:active" ]] || {
		echo "healthy-after-retry active startup did not publish active mode: $CALLS" >&2
		exit 1
	}
)

(
	CALLS=""
	start_cluster()
	{
		record_call cluster
		return 0
	}
	wait_for_http_health()
	{
		record_call health
		return 0
	}
	write_runtime_mode()
	{
		record_call "mode:$1"
	}
	start_active_authority
	[[ "$CALLS" == "cluster health mode:active" ]] || {
		echo "healthy active startup did not publish active mode: $CALLS" >&2
		exit 1
	}
)

# Cold-start cache, lease and team reconstruction may briefly make the
# embedded gateway report a worker as unreachable after it first becomes
# ready.  The supervisor must allow a bounded stabilization window, then keep
# the normal three-consecutive-failure circuit breaker unchanged.
(
	CALLS=""
	CLUSTER_STARTED=1
	SUPERVISOR_ENABLED=1
	SUPERVISOR_HEALTH_FAILURES=0
	cluster_is_healthy()
	{
		return 1
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	SECONDS=100
	supervise_worker_cluster_once active 160
	[[ "$CALLS" == "" && "$SUPERVISOR_HEALTH_FAILURES" == "0" &&
	   "$SUPERVISOR_ENABLED" == "1" ]] || {
		echo "startup stabilization unexpectedly opened fallback: $CALLS" >&2
		exit 1
	}
	SECONDS=160
	supervise_worker_cluster_once active 160
	supervise_worker_cluster_once active 160
	[[ "$CALLS" == "" && "$SUPERVISOR_HEALTH_FAILURES" == "2" ]] || {
		echo "post-stabilization failures were not counted: $CALLS" >&2
		exit 1
	}
	supervise_worker_cluster_once active 160
	[[ "$CALLS" == "fallback:active" && "$SUPERVISOR_ENABLED" == "0" &&
	   "$SUPERVISOR_HEALTH_FAILURES" == "0" ]] || {
		echo "post-stabilization circuit breaker did not fail closed: $CALLS" >&2
		exit 1
	}
)

CALLS=""
stop_cluster_safely()
{
	record_call stop
	return 1
}
if (fallback_to_legacy active) >/dev/null 2>&1; then
	echo "active fallback must fail closed when worker shutdown is unproven" >&2
	exit 1
fi
[[ "$CALLS" == "" ]] || {
	echo "subshell failure test leaked parent state" >&2
	exit 1
}

# A unified Docker container launches the topology with the background
# launcher from PID 1.  A later `docker exec ... map_worker_cluster.sh status`
# does not inherit that shell-only export and falls back to `screen`.  Status
# and health are read-only, so they must remain available even when screen is
# intentionally absent; mutating lifecycle actions must retain the dependency.
(
	source "$CLUSTER_SCRIPT"
	fixture_root="$(mktemp -d)"
	trap 'rm -rf -- "$fixture_root"' EXIT
	ROOT_DIR="$fixture_root"
	PIKE_BIN="$(command -v sh)"
	MYSQL_PASSWORD="test-only-not-a-secret"
	XIAND_WORKER_TOKEN="test-only-worker-token-not-a-secret"
	XIAND_MAP_WORKER_LAUNCHER="screen"
	command()
	{
		if [[ "${1:-}" == "-v" && "${2:-}" == "screen" ]]; then
			return 1
		fi
		if [[ "${1:-}" == "-v" ]]; then
			printf '%s\n' "$PIKE_BIN"
			return 0
		fi
		builtin command "$@"
	}
	ACTION="status"
	load_environment
	ACTION="health"
	load_environment
	if (ACTION="start"; load_environment) >/dev/null 2>&1; then
		echo "worker start unexpectedly ignored the missing screen dependency" >&2
		exit 1
	fi
)

echo "docker worker startup safety tests passed"
