#!/usr/bin/env bash
set -Eeuo pipefail

# 旧容器安全停机证明：协调器处于瞬态（排水未静/恢复中/Worker 刚失联）
# 且 uncertain/pending_reconcile/background_arrivals 全为零，或节点已
# 进入停机收尾（存档栅栏/端口收尾）时，按退避重试最多约 15 分钟——
# 这些状态会自行收敛，重试把"整轮部署中止、人工反复重跑"变成"慢一点
# 但一次成功"。任何真实存档风险仍然立即失败关闭，绝不放松屏障。

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
	echo "usage: $0 CONTAINER_NAME AREA_NAME" >&2
	exit 2
fi

container_name="$1"
area_name="$2"

RETRY_DEADLINE_SECONDS="${XIAND_OLD_CLUSTER_STOP_TIMEOUT:-900}"

transient_barrier_code()
{
	printf '%s' "$1" | grep -Eq \
		'"code": ?"gateway_not_quiescent"' ||
	printf '%s' "$1" | grep -Eq \
		'"code": ?"gateway_recovery_busy"' ||
	printf '%s' "$1" | grep -Eq \
		'"code": ?"failed_worker_still_reachable"'
}

# 节点已在停机途中但尚未退出（保存栅栏/端口收尾/等待超时）都是会自行
# 收敛的瞬态；这些输出不携带网关计数器，直接按文本判定后由整体退避
# 重试。真实存档风险仍然立即失败关闭。
transient_node_message()
{
	printf '%s' "$1" | grep -Eq 'process is alive but MUD port is down' ||
	printf '%s' "$1" | grep -Eq 'safe shutdown timed out' ||
	printf '%s' "$1" | grep -Eq 'refusing forced stop'
}

counter_value()
{
	local key="$1"
	printf '%s' "$stop_output" | \
		grep -oE "\"$key\": ?[0-9]+" | tail -1 | grep -oE '[0-9]+$'
}

safe_to_wait_counters()
{
	local key value
	for key in uncertain_requests pending_reconcile_users \
		background_arrivals; do
		value="$(counter_value "$key")" || true
		[[ "$value" == "0" ]] || return 1
	done
	return 0
}

report_blocking_counters()
{
	local key value
	echo "[ERROR] 安全停机屏障未通过，阻塞计数器：" >&2
	for key in uncertain_requests pending_reconcile_users \
		background_arrivals maintenance_operations \
		active_requests pending_requests; do
		value="$(counter_value "$key")" || true
		echo "  $key=${value:-unknown}" >&2
	done
}

deadline=$((SECONDS + RETRY_DEADLINE_SECONDS))
attempt=0
settle_seconds=5
while (( SECONDS < deadline )); do
	attempt=$((attempt + 1))
	stop_output=""
	stop_status=0
	# 必须在 else 分支里取 $?：无 else 的 if 复合语句在条件失败时
	# 整体返回 0，而 && 复合又会触发 set -e。
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
	if { transient_barrier_code "$stop_output" && safe_to_wait_counters; } ||
	   transient_node_message "$stop_output"; then
		echo "[INFO] 停机证明处于可收敛瞬态（第${attempt}次），${settle_seconds}秒后重试安全停机证明..." >&2
		sleep "$settle_seconds"
		(( settle_seconds < 30 )) && settle_seconds=$((settle_seconds + 5))
		continue
	fi
	report_blocking_counters
	[[ -z "$stop_output" ]] || printf '%s\n' "$stop_output" >&2
	exit "$stop_status"
done

echo "[ERROR] 安全停机证明在 ${RETRY_DEADLINE_SECONDS} 秒内未完成；为保护未存档 Worker 拒绝继续，请稍后重跑部署。" >&2
exit 1
