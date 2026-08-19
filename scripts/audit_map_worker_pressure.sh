#!/usr/bin/env bash
# Read-only local pressure gate for the embedded Pike gateway.
# It never logs in, mutates player state, or changes the worker topology.

set -euo pipefail

request_count="${1:-100}"
parallelism="${2:-20}"
gateway_url="${XIAND_PRESSURE_GATEWAY_URL:-http://127.0.0.1:8888}"

case "$request_count" in
  ''|*[!0-9]*) echo "request_count must be an integer" >&2; exit 2 ;;
esac
case "$parallelism" in
  ''|*[!0-9]*) echo "parallelism must be an integer" >&2; exit 2 ;;
esac
if (( request_count < 50 || request_count > 1000 )); then
  echo "request_count must be between 50 and 1000" >&2
  exit 2
fi
if (( parallelism < 1 || parallelism > 100 )); then
  echo "parallelism must be between 1 and 100" >&2
  exit 2
fi

pressure_dir="$(mktemp -d "${TMPDIR:-/tmp}/xiand-pressure.XXXXXX")"
trap 'rm -rf "$pressure_dir"' EXIT
export gateway_url pressure_dir

run_probe()
{
  probe_id="$1"
  if (( probe_id % 2 == 0 )); then
    endpoint="/health"
  else
    endpoint="/api/partitions"
  fi
  code="$(curl --connect-timeout 2 --max-time 8 --silent --show-error \
    --output "$pressure_dir/body.$probe_id" --write-out '%{http_code}' \
    "$gateway_url$endpoint" || true)"
  printf '%s\n' "$code" >"$pressure_dir/code.$probe_id"
}
export -f run_probe

seq 1 "$request_count" | xargs -n1 -P"$parallelism" bash -c \
  'run_probe "$1"' _

success_count="$(awk '$1 == 200 { count++ } END { print count+0 }' \
  "$pressure_dir"/code.*)"
invalid_json=0
for body in "$pressure_dir"/body.*; do
  if ! jq -e 'type == "object"' "$body" >/dev/null 2>&1; then
    invalid_json=$((invalid_json+1))
  fi
done

cluster_status="$(./scripts/map_worker_cluster.sh status)"
desired_workers="$(awk '/desired enabled=1 mode=active workers=/ {
  sub(/^.*workers=/, ""); print; exit
}' <<<"$cluster_status")"
running_workers="$(grep -Ec 'w[0-9][0-9]: running mud=' <<<"$cluster_status" || true)"
if (( success_count != request_count || invalid_json != 0 )) ||
   ! grep -q 'gateway: embedded in' <<<"$cluster_status" ||
   [[ -z "$desired_workers" ]] ||
   (( running_workers != desired_workers )); then
  echo "pressure gate failed: ok=$success_count/$request_count invalid_json=$invalid_json" >&2
  printf '%s\n' "$cluster_status" >&2
  exit 1
fi

echo "pressure gate passed: ok=$success_count/$request_count invalid_json=0 parallelism=$parallelism"
printf '%s\n' "$cluster_status"
