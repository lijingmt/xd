#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
	[[ "$CALLS" == "cluster fallback:active" ]] || {
		echo "active process startup failure did not open fallback circuit: $CALLS" >&2
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
		return 1
	}
	fallback_to_legacy()
	{
		record_call "fallback:$1"
	}
	start_active_authority
	[[ "$CALLS" == "cluster health fallback:active" ]] || {
		echo "active startup failure did not open fallback circuit: $CALLS" >&2
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

echo "docker worker startup safety tests passed"
