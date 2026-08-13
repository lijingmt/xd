#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xiand-old-stop-retry.XXXXXX")"
trap 'rm -rf -- "$FIXTURE_DIR"' EXIT
mkdir -p "$FIXTURE_DIR/bin"

cat > "$FIXTURE_DIR/bin/docker" <<'SH'
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$XIAND_MOCK_COUNT" ]] || count="$(<"$XIAND_MOCK_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$XIAND_MOCK_COUNT"
if [[ "${XIAND_MOCK_MODE:-transient}" == "transient" && "$count" == "1" ]]; then
	echo '{"code":"gateway_not_quiescent","active_requests":0,"pending_requests":3,"pending_reconcile_users":0,"uncertain_requests":0,"background_arrivals":0,"ok":0}' >&2
	echo 'Traceback (most recent call last):' >&2
	exit 1
fi
if [[ "${XIAND_MOCK_MODE:-transient}" == "unsafe" ]]; then
	echo '{"code":"gateway_not_quiescent","pending_reconcile_users":0,"uncertain_requests":1,"background_arrivals":0,"ok":0}' >&2
	echo 'Traceback (most recent call last):' >&2
	exit 1
fi
echo '[map-workers] gateway routing is paused and all accepted requests are settled'
exit 0
SH
chmod +x "$FIXTURE_DIR/bin/docker"

export PATH="$FIXTURE_DIR/bin:$PATH"
export XIAND_MOCK_COUNT="$FIXTURE_DIR/count"
transient_output="$($ROOT_DIR/scripts/stop_old_map_worker_cluster.sh \
	xiand-fixture xd-fixture 2>&1)"
[[ "$(<"$XIAND_MOCK_COUNT")" == "2" ]] || {
	echo "old transient stop was not retried exactly once" >&2
	exit 1
}
[[ "$transient_output" == *"自动重新执行一次安全存档证明"* ]] || {
	echo "old transient stop retry was not explained" >&2
	exit 1
}
[[ "$transient_output" == *"all accepted requests are settled"* ]] || {
	echo "old transient stop did not require final safe proof" >&2
	exit 1
}
[[ "$transient_output" != *"Traceback"* ]] || {
	echo "handled old transient stop still leaked a Python traceback" >&2
	exit 1
}

export XIAND_MOCK_MODE="unsafe"
export XIAND_MOCK_COUNT="$FIXTURE_DIR/unsafe-count"
set +e
unsafe_output="$(set -e; $ROOT_DIR/scripts/stop_old_map_worker_cluster.sh \
	xiand-fixture xd-fixture 2>&1)"
unsafe_status=$?
set -e
[[ "$unsafe_status" -ne 0 ]] || {
	echo "unsafe old stop must remain fail-closed" >&2
	exit 1
}
[[ "$(<"$XIAND_MOCK_COUNT")" == "1" ]] || {
	echo "unsafe old stop should not be retried" >&2
	exit 1
}
[[ "$unsafe_output" == *'"uncertain_requests":1'* ]] || {
	echo "unsafe old stop lost its diagnostic output" >&2
	exit 1
}

echo "old container safe-stop retry tests passed"
