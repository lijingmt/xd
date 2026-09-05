#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="/app/xiand"
MAP_WORKER_SCRIPT="$ROOT_DIR/scripts/map_worker_cluster.sh"
MAP_WORKER_DIR="$ROOT_DIR/data_xiand/map_workers"
MAP_WORKER_CONFIG="${XIAND_MAP_WORKER_CONFIG:-$MAP_WORKER_DIR/config.json}"
FALLBACK_LATCH="$MAP_WORKER_DIR/fallback-latched"
RUNTIME_MODE_FILE="$MAP_WORKER_DIR/runtime-mode"
LEGACY_MUD_PORT=13800
LEGACY_HTTP_PORT=8888
LEGACY_PID=""
TOMCAT_PID=""
SOCAT_SOCKET_PID=""
SOCAT_TCP_PID=""
CLUSTER_STARTED=0
SHUTTING_DOWN=0
SUPERVISOR_HEALTH_FAILURES=0
SUPERVISOR_ENABLED=0
SUPERVISOR_CLUSTER_RESTARTS=0
SUPERVISOR_LAST_RESTART_SECONDS=0
STARTUP_EMERGENCY_LEGACY=0
EMERGENCY_LAST_ATTEMPT=0
# 无预编译冷启时10个Worker的HTTP就绪在600秒上下浮动（与下方1200秒
# 健康窗口同量级）。宽限若小于冷编译时间，监督者会在冷启动中途判
# 定不健康并重启集群，又被下一轮冷启动拖垮，形成"每两分钟重启一次"
# 的死循环（2026-09-05生产事故：协调器进程被重启150次）。
MAP_WORKER_STARTUP_STABILIZATION_SECONDS="${XIAND_MAP_WORKER_STARTUP_STABILIZATION_SECONDS:-900}"

export PATH="/usr/local/pike9/bin:${PATH}"
if [[ "${XIAND_STARTUP_LIBRARY_ONLY:-0}" != "1" ]]; then
	ulimit -s unlimited
fi

log()
{
	echo "[xiand-startup] $*"
}

fail()
{
	echo "[xiand-startup] ERROR: $*" >&2
	exit 1
}

write_runtime_mode()
{
	local mode="$1"
	local temp_file
	temp_file="$(mktemp "$MAP_WORKER_DIR/.runtime-mode.XXXXXX")"
	printf '%s\n' "$mode" > "$temp_file"
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$RUNTIME_MODE_FILE"
}

config_value()
{
	python3 - "$MAP_WORKER_CONFIG" "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)[sys.argv[2]])
PY
}

ensure_worker_config()
{
	local enabled="${XIAND_MAP_WORKER_ENABLED:-1}"
	local traffic_mode="${XIAND_MAP_WORKER_TRAFFIC_MODE:-shadow}"
	local worker_count="${XIAND_MAP_WORKER_COUNT:-3}"
	local worker_capacity="${XIAND_MAP_WORKER_CAPACITY:-100}"
	[[ ! -L "$MAP_WORKER_DIR" ]] ||
		fail "persistent map_workers directory must not be a symlink"
	mkdir -p "$MAP_WORKER_DIR"
	chmod 700 "$MAP_WORKER_DIR"
	[[ ! -L "$MAP_WORKER_CONFIG" ]] ||
		fail "worker config must not be a symlink"
	if [[ ! -f "$MAP_WORKER_CONFIG" ]]; then
		python3 - "$MAP_WORKER_CONFIG" "$enabled" "$traffic_mode" \
			"$worker_count" "$worker_capacity" <<'PY'
import json
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "schema_version": 2,
    "enabled": int(sys.argv[2]),
    "traffic_mode": sys.argv[3],
    "worker_count": int(sys.argv[4]),
    "worker_capacity": int(sys.argv[5]),
    "placement": "load_aware_rendezvous",
    "coordinator_http_port": 18880,
    "worker_http_base_port": 18881,
    "worker_mud_base_port": 14801,
    "gateway_port": 8888,
}
temporary = path.with_name(f".config.{os.getpid()}.tmp")
temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
os.chmod(temporary, 0o600)
os.replace(temporary, path)
PY
	fi
	chmod 600 "$MAP_WORKER_CONFIG"
	if [[ "$(config_value enabled)" == "1" ]]; then
		XIAND_MAP_WORKER_CONFIG="$MAP_WORKER_CONFIG" \
		XIAND_MAP_WORKER_LAUNCHER=background \
		XIAND_MAP_WORKER_AREA_NAME="$GAME_PREFIX" \
			"$MAP_WORKER_SCRIPT" validate >/dev/null
	fi
}

wait_for_http_health()
{
	# 无预编译冷启时，协调器网关要等全部 Worker 编译完成才监听；
	# 健康窗口固定 20 分钟（1200 秒）：205 十 Worker 冷启的 HTTP 就绪
	# 时间在 600 秒上下浮动，窗口不足会逼出整轮重试并最终误熔断。
	local timeout="${XIAND_ACTIVE_START_HEALTH_TIMEOUT:-1200}"
	log "waiting up to ${timeout}s for the HTTP health endpoint"
	local deadline=$((SECONDS + timeout))
	while (( SECONDS < deadline )); do
		if curl -fsS --max-time 3 \
			"http://127.0.0.1:${LEGACY_HTTP_PORT}/health" >/dev/null 2>&1; then
			return 0
		fi
		if [[ -n "$LEGACY_PID" ]] && ! kill -0 "$LEGACY_PID" 2>/dev/null; then
			return 1
		fi
		sleep 1
	done
	return 1
}

start_legacy_main()
{
	if lsof -tiTCP:"$LEGACY_MUD_PORT" -sTCP:LISTEN >/dev/null 2>&1 ||
	   lsof -tiTCP:"$LEGACY_HTTP_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
		fail "legacy main ports are still occupied after worker shutdown"
	fi
	log "starting legacy single-process main on 13800/8888"
	cd "$ROOT_DIR"
	XIAND_NODE_ROLE=standalone XIAND_RUN_TESTUNIT=0 \
		pike -s1000000 -ss67108864 --no-precompile \
		"$ROOT_DIR/lowlib/driver.pike" \
		-i 0.0.0.0 -p "$LEGACY_MUD_PORT" "$ROOT_DIR/" \
		>> "$ROOT_DIR/log/pike.log" 2>&1 &
	LEGACY_PID=$!
	if ! wait_for_http_health; then
		fail "legacy main did not become healthy within 120 seconds"
	fi
	log "legacy single-process main is healthy (pid $LEGACY_PID)"
}

stop_legacy_main()
{
	[[ -n "$LEGACY_PID" ]] || return 0
	if ! kill -0 "$LEGACY_PID" 2>/dev/null; then
		LEGACY_PID=""
		return 0
	fi
	log "requesting in-game shutdown for legacy main"
	(
		sleep 1
		printf 'shutdown_safe\r\n'
		sleep 2
	) | nc -w 3 127.0.0.1 "$LEGACY_MUD_PORT" >/dev/null 2>&1 || true
	local deadline=$((SECONDS + 45))
	while (( SECONDS < deadline )); do
		kill -0 "$LEGACY_PID" 2>/dev/null || break
		sleep 1
	done
	if kill -0 "$LEGACY_PID" 2>/dev/null; then
		log "legacy main did not confirm safe shutdown; refusing forced kill"
		return 1
	fi
	LEGACY_PID=""
}

start_cluster()
{
	export XIAND_MAP_WORKER_CONFIG="$MAP_WORKER_CONFIG"
	export XIAND_MAP_WORKER_LAUNCHER=background
	export XIAND_MAP_WORKER_AREA_NAME="$GAME_PREFIX"
	"$MAP_WORKER_SCRIPT" apply
	CLUSTER_STARTED=1
}

stop_cluster_safely()
{
	local traffic_mode="${1:-}"
	if [[ "$CLUSTER_STARTED" != "1" &&
	      ! -f "$ROOT_DIR/log/map-workers/$GAME_PREFIX/topology.json" ]]; then
		return 0
	fi
	if XIAND_MAP_WORKER_CONFIG="$MAP_WORKER_CONFIG" \
	   XIAND_MAP_WORKER_LAUNCHER=background \
	   XIAND_MAP_WORKER_AREA_NAME="$GAME_PREFIX" \
	   XIAND_MAP_WORKER_FAILOVER_SHUTDOWN="$([[ "$traffic_mode" == "active" ]] && echo 1 || echo 0)" \
	   "$MAP_WORKER_SCRIPT" stop; then
		CLUSTER_STARTED=0
		return 0
	fi
	return 1
}

cluster_is_healthy()
{
	local probe_output
	if probe_output="$(XIAND_MAP_WORKER_CONFIG="$MAP_WORKER_CONFIG" \
	   XIAND_MAP_WORKER_LAUNCHER=background \
	   XIAND_MAP_WORKER_AREA_NAME="$GAME_PREFIX" \
		"$MAP_WORKER_SCRIPT" health 2>&1)"; then
		return 0
	fi
	printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$probe_output" \
		>> "$ROOT_DIR/log/map-worker-monitor.log"
	return 1
}

latch_active_fallback()
{
	local reason="$1"
	local temp_file
	temp_file="$(mktemp "$MAP_WORKER_DIR/.fallback.XXXXXX")"
	printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" > "$temp_file"
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$FALLBACK_LATCH"
}

fallback_to_legacy()
{
	local traffic_mode="$1"
	log "worker health circuit opened in $traffic_mode mode"
	if [[ "$traffic_mode" == "active" ]]; then
		latch_active_fallback "worker-health-failure"
	fi
	if ! stop_cluster_safely "$traffic_mode"; then
		if [[ "$traffic_mode" == "active" ]]; then
			fail "worker cluster could not prove safe shutdown; fallback latch retained"
		fi
		log "shadow cluster safe-stop was incomplete; legacy main remains authoritative"
	fi
	if [[ "$traffic_mode" == "active" ]]; then
		start_legacy_main
		write_runtime_mode legacy-fallback
	else
		write_runtime_mode shadow-degraded
	fi
}

start_shadow_authority()
{
	if start_cluster; then
		write_runtime_mode shadow
		return 0
	fi
	log "shadow worker startup failed; keeping legacy main authoritative"
	fallback_to_legacy shadow
}

start_active_authority()
{
	# 拓扑首次拉起常因端口预热或健康探针抖动而未就绪；先安全停机
	# （仍走存档屏障）再整轮重试，避免一次抖动就把整个部署打回
	# legacy-fallback 并迫使运维反复重跑。
	local attempt
	local max_attempts="${XIAND_ACTIVE_START_ATTEMPTS:-3}"
	local drain_seconds="${XIAND_ACTIVE_START_RETRY_WAIT:-20}"
	for attempt in $(seq 1 "$max_attempts"); do
		if start_cluster && wait_for_http_health; then
			(( attempt > 1 )) && log "active topology healthy after retry $attempt"
			write_runtime_mode active
			return 0
		fi
		if (( attempt < max_attempts )); then
			log "active topology not healthy (attempt $attempt/$max_attempts); safely draining before retry"
			stop_cluster_safely active || true
			sleep "$drain_seconds"
		fi
	done
	log "active worker startup failed; serving on emergency legacy main"
	STARTUP_EMERGENCY_LEGACY=1
	fallback_to_legacy active
}

start_tomcat()
{
	/usr/local/tomcat/bin/catalina.sh run >> "$ROOT_DIR/log/tomcat.log" 2>&1 &
	TOMCAT_PID=$!
	log "Tomcat started (pid $TOMCAT_PID)"
}

shutdown_components()
{
	local status=$?
	[[ "$SHUTTING_DOWN" == "0" ]] || exit "$status"
	SHUTTING_DOWN=1
	trap - EXIT INT TERM
	stop_cluster_safely || true
	stop_legacy_main || true
	if [[ -n "$TOMCAT_PID" ]] && kill -0 "$TOMCAT_PID" 2>/dev/null; then
		/usr/local/tomcat/bin/catalina.sh stop >/dev/null 2>&1 || true
		wait "$TOMCAT_PID" 2>/dev/null || true
	fi
	for helper_pid in "$SOCAT_SOCKET_PID" "$SOCAT_TCP_PID"; do
		if [[ -n "$helper_pid" ]] && kill -0 "$helper_pid" 2>/dev/null; then
			kill -TERM "$helper_pid" 2>/dev/null || true
		fi
	done
	exit "$status"
}

initialize_runtime()
{
	GAME_AREA_INPUT="${GAME_AREA:-xd01}"
	if [[ "$GAME_AREA_INPUT" =~ ^xd[0-9]{2}(-[0-9]{2})?$ ]]; then
		GAME_PREFIX="$GAME_AREA_INPUT"
		GAME_AREA="${GAME_AREA_INPUT#xd}"
	elif [[ "$GAME_AREA_INPUT" =~ ^[0-9]{2}(-[0-9]{2})?$ ]]; then
		GAME_PREFIX="xd${GAME_AREA_INPUT}"
		GAME_AREA="$GAME_AREA_INPUT"
	else
		fail "GAME_AREA must be xdNN, NN, or an NN-NN merged range"
	fi
	export GAME_PREFIX GAME_AREA

	ETC_RUNTIME_DIR="$ROOT_DIR/gamelib/etc"
	ETC_BOOTSTRAP_DIR="/app/xiand-bootstrap/etc"
	LOGICAL_ZONE_RUNTIME_DIR="$ETC_RUNTIME_DIR/logical_zones"
	LOGICAL_ZONE_IMAGE_SEED_DIR="$ROOT_DIR/deploy/logical_zones"
	mkdir -p "$ETC_RUNTIME_DIR" "$LOGICAL_ZONE_RUNTIME_DIR"
	if [[ ! -e "$ETC_RUNTIME_DIR/regname" ]]; then
		cp -an "$ETC_BOOTSTRAP_DIR/." "$ETC_RUNTIME_DIR/"
	fi

	# IAP Server API credentials (not in git/image): inject into runtime
	# etc when present; never overwrite; silently skip when seed missing.
	local iap_seed_dir="/usr/local/games/allxd/secrets/iap"
	local iap_file
	for iap_file in iap_server_api.local.json iap_server_api_key.p8; do
		if [[ -f "$iap_seed_dir/$iap_file" && ! -f "$ETC_RUNTIME_DIR/$iap_file" ]]; then
			install -m 600 -o wapmud -g wapmud "$iap_seed_dir/$iap_file" "$ETC_RUNTIME_DIR/$iap_file"
		fi
	done
	local zone_config_found=0
	local zone_config
	for zone_config in "$LOGICAL_ZONE_RUNTIME_DIR"/xd[0-9][0-9].conf; do
		[[ -f "$zone_config" ]] || continue
		zone_config_found=1
		break
	done
	if [[ "$zone_config_found" == "0" ]]; then
		local zone_seed
		for zone_seed in "$LOGICAL_ZONE_IMAGE_SEED_DIR"/xd[0-9][0-9].conf; do
			[[ -f "$zone_seed" ]] || continue
			cp -pn "$zone_seed" "$LOGICAL_ZONE_RUNTIME_DIR/"
		done
	fi
	chmod 755 "$ETC_RUNTIME_DIR" "$LOGICAL_ZONE_RUNTIME_DIR" 2>/dev/null || true
	chmod 644 "$LOGICAL_ZONE_RUNTIME_DIR"/*.conf 2>/dev/null || true

	MYSQL_HOST="${MYSQL_HOST:-172.17.0.1}"
	MYSQL_PORT="${MYSQL_PORT:-3306}"
	MYSQL_USER="${MYSQL_USER:-root}"
	MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
	[[ -n "$MYSQL_PASSWORD" ]] || fail "MYSQL_PASSWORD is required"
	export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD

	umask 027
	mkdir -p "$ROOT_DIR/data_xiand/u" "$ROOT_DIR/data_xiand/bangpai" \
		"$ROOT_DIR/data_xiand/accounts" "$ROOT_DIR/data_xiand/new_users" \
		"$ROOT_DIR/data_xiand/feedback" \
		"$ROOT_DIR/log/pk" "$ROOT_DIR/log/stat/online" \
		"$ROOT_DIR/log/stat/consume" "$ROOT_DIR/log/stat/daily" \
		"$ROOT_DIR/log/stat/reg" "$ROOT_DIR/log/stat/money_consume" \
		"$ROOT_DIR/log/fee_log" "$ROOT_DIR/log/home/drop" \
		"$ROOT_DIR/log/auto_learn" "$ROOT_DIR/log/push" \
		"$ROOT_DIR/log/daily" "$ROOT_DIR/log/month" \
		"$ROOT_DIR/db_log/reg_new" "$ROOT_DIR/db_log/daily_user" \
		/var/lib/mysql /tmp "$MAP_WORKER_DIR"
	chmod 700 "$ROOT_DIR/data_xiand" "$ROOT_DIR/data_xiand/u" \
		"$ROOT_DIR/data_xiand/bangpai" "$ROOT_DIR/data_xiand/accounts" \
		"$ROOT_DIR/data_xiand/new_users" "$ROOT_DIR/data_xiand/feedback"
	chmod 750 "$ROOT_DIR/log" "$ROOT_DIR/log/pk" \
		"$ROOT_DIR/log/stat" "$ROOT_DIR/log/stat/online" \
		"$ROOT_DIR/log/stat/consume" "$ROOT_DIR/log/stat/daily" \
		"$ROOT_DIR/log/stat/reg" "$ROOT_DIR/log/stat/money_consume" \
		"$ROOT_DIR/log/fee_log" "$ROOT_DIR/log/home" \
		"$ROOT_DIR/log/home/drop" "$ROOT_DIR/log/auto_learn" \
		"$ROOT_DIR/log/push" "$ROOT_DIR/log/daily" "$ROOT_DIR/log/month"
	chmod 700 "$ROOT_DIR/db_log" "$ROOT_DIR/db_log/reg_new" \
		"$ROOT_DIR/db_log/daily_user" "$MAP_WORKER_DIR"
	find "$ROOT_DIR/data_xiand" -type d -exec chmod 700 {} + 2>/dev/null || true
	find "$ROOT_DIR/data_xiand" -type f -exec chmod 600 {} + 2>/dev/null || true

	rm -f /tmp/.mysql_sock /var/lib/mysql/mysql.sock \
		/run/mysqld/mysqld.sock 2>/dev/null || true
	mkdir -p /run/mysqld
	socat UNIX-LISTEN:/tmp/.mysql_sock,fork,reuseaddr,mode=666 \
		TCP:"$MYSQL_HOST":"$MYSQL_PORT" > /tmp/socat.log 2>&1 &
	SOCAT_SOCKET_PID=$!
	socat TCP-LISTEN:3306,fork,reuseaddr,bind=127.0.0.1 \
		TCP:"$MYSQL_HOST":"$MYSQL_PORT" > /tmp/socat_3306.log 2>&1 &
	SOCAT_TCP_PID=$!
	sleep 1
	ln -sf /tmp/.mysql_sock /var/lib/mysql/mysql.sock
	ln -sf /tmp/.mysql_sock /run/mysqld/mysqld.sock

	DB_NAME="$GAME_PREFIX"
	if ! MYSQL_PWD="$MYSQL_PASSWORD" mariadb -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
		-u "$MYSQL_USER" -e "SELECT 1" >/dev/null 2>&1; then
		fail "MySQL authentication failed"
	fi
	MYSQL_PWD="$MYSQL_PASSWORD" mariadb -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
		-u "$MYSQL_USER" -e \
		"CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" \
		>/dev/null
	local table_count
	table_count="$(MYSQL_PWD="$MYSQL_PASSWORD" mariadb -h "$MYSQL_HOST" \
		-P "$MYSQL_PORT" -u "$MYSQL_USER" -N -B -e \
		"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';")"
	if [[ "$table_count" == "0" ]]; then
		[[ -f "$ROOT_DIR/xd.sql" ]] || fail "xd.sql is missing"
		MYSQL_PWD="$MYSQL_PASSWORD" mariadb -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
			-u "$MYSQL_USER" "$DB_NAME" < "$ROOT_DIR/xd.sql"
		log "database $DB_NAME initialized"
	else
		log "database $DB_NAME already has $table_count tables"
	fi
}

# 安全停机失败（通常是卡死的协调器拒绝quiesce栅栏）时，重启决策仍然
# 必须成立：要重启就全部worker一起重启，绝不带着旧世代进程拉新拓扑
# （残留worker持有脏epoch/在线行，新协调器永远无法收敛到健康）。
force_stop_cluster_stragglers()
{
	local pids
	pids="$(pgrep -f "lowlib/driver.pike" || true)"
	if [[ -z "$pids" ]]; then
		return 0
	fi
	log "force-stopping ${pids//$'\n'/ } after incomplete safe stop"
	kill -TERM $pids 2>/dev/null || true
	local deadline=$((SECONDS + 20))
	while (( SECONDS < deadline )); do
		pgrep -f "lowlib/driver.pike" >/dev/null 2>&1 || return 0
		sleep 1
	done
	pkill -KILL -f "lowlib/driver.pike" 2>/dev/null || true
	sleep 2
	if pgrep -f "lowlib/driver.pike" >/dev/null 2>&1; then
		fail "worker processes survived SIGKILL during forced stop"
	fi
	return 0
}

restart_worker_cluster()
{
	local traffic_mode="$1"
	SUPERVISOR_CLUSTER_RESTARTS=$((SUPERVISOR_CLUSTER_RESTARTS + 1))
	log "worker cluster unhealthy; restarting multi-worker topology (attempt $SUPERVISOR_CLUSTER_RESTARTS) instead of falling back to legacy"
	if ! stop_cluster_safely "$traffic_mode"; then
		log "cluster safe-stop incomplete; forcing full worker shutdown before restart"
		force_stop_cluster_stragglers
	fi
	# 无论start_cluster脚本层是否报成功，新一轮Worker编译都已经启动
	# 或即将启动；宽限必须无条件重置，否则编译中途又会被判不健康，
	# 重启在退避窗口内被无谓消耗。
	SUPERVISOR_GRACE_DEADLINE=$(( SECONDS +
		MAP_WORKER_STARTUP_STABILIZATION_SECONDS ))
	if start_cluster; then
		write_runtime_mode "$traffic_mode"
		log "multi-worker topology restarted; supervisor keeps watching"
	else
		log "cluster restart failed; supervisor will retry after backoff"
	fi
}

# 启动期集群拉不起而应急跑单进程时，定期尝试恢复多worker拓扑：
# 先停应急单进程释放端口，再整轮拉集群；失败则回到应急单进程。
attempt_emergency_cluster_recovery()
{
	local traffic_mode="$1"
	log "emergency legacy serving active; attempting multi-worker topology recovery"
	stop_legacy_main || fail "legacy main could not stop during topology recovery"
	if start_cluster && wait_for_http_health; then
		STARTUP_EMERGENCY_LEGACY=0
		write_runtime_mode active
		if [[ -f "$FALLBACK_LATCH" ]]; then
			mv -f "$FALLBACK_LATCH" \
				"$MAP_WORKER_DIR/fallback-recovered.$(date -u +%Y%m%dT%H%M%SZ)" \
				2>/dev/null || true
		fi
		log "multi-worker topology recovered from emergency legacy serving"
		return 0
	fi
	log "topology recovery not healthy; returning to emergency legacy serving"
	stop_cluster_safely "$traffic_mode" || true
	start_legacy_main || fail "legacy main could not restart during topology recovery"
}

supervise_worker_cluster_once()
{
	local traffic_mode="$1"
	local startup_grace_deadline="$2"
	if cluster_is_healthy; then
		SUPERVISOR_HEALTH_FAILURES=0
		SUPERVISOR_CLUSTER_RESTARTS=0
		return 0
	fi
	if (( SECONDS < startup_grace_deadline )); then
		SUPERVISOR_HEALTH_FAILURES=0
		log "worker health probe is stabilizing; retrying before fallback"
		return 0
	fi
	SUPERVISOR_HEALTH_FAILURES=$((SUPERVISOR_HEALTH_FAILURES + 1))
	log "worker health probe failed ($SUPERVISOR_HEALTH_FAILURES/3)"
	if (( SUPERVISOR_HEALTH_FAILURES >= 3 )); then
		# 多worker是唯一正式拓扑：永不降级单进程（降级后持久化的
		# 房间亲和仍指向死worker，每个动作吃满控制超时，玩家体感
		# 每步卡约10秒）。收敛靠三件事：900秒冷启动宽限、每次重
		# 启后重新武装宽限、指数退避（60s起、封顶900s）。退避计
		# 数在集群恢复健康时清零，永不健康则每15分钟重试一轮。
		local backoff=$(( 60 << SUPERVISOR_CLUSTER_RESTARTS ))
		(( backoff > 900 )) && backoff=900
		if (( SUPERVISOR_LAST_RESTART_SECONDS > 0 &&
		      SECONDS - SUPERVISOR_LAST_RESTART_SECONDS < backoff )); then
			log "restart backoff active (${backoff}s); waiting before next cluster restart"
			return 0
		fi
		SUPERVISOR_LAST_RESTART_SECONDS=$SECONDS
		restart_worker_cluster "$traffic_mode"
		SUPERVISOR_HEALTH_FAILURES=0
	fi
}

run_supervisor()
{
	local enabled="$1"
	local traffic_mode="$2"
	SUPERVISOR_ENABLED="$enabled"
	SUPERVISOR_HEALTH_FAILURES=0
	SUPERVISOR_CLUSTER_RESTARTS=0
	SUPERVISOR_LAST_RESTART_SECONDS=0
	SUPERVISOR_GRACE_DEADLINE=$(( SECONDS +
		MAP_WORKER_STARTUP_STABILIZATION_SECONDS ))
	while true; do
		sleep 5
		if [[ -n "$TOMCAT_PID" ]] && ! kill -0 "$TOMCAT_PID" 2>/dev/null; then
			fail "Tomcat exited unexpectedly"
		fi
		if [[ -n "$LEGACY_PID" ]] && ! kill -0 "$LEGACY_PID" 2>/dev/null; then
			fail "legacy main exited unexpectedly"
		fi
		if [[ "$SUPERVISOR_ENABLED" == "1" &&
		   "$CLUSTER_STARTED" == "1" ]]; then
			supervise_worker_cluster_once "$traffic_mode" \
				"$SUPERVISOR_GRACE_DEADLINE"
		elif [[ "$SUPERVISOR_ENABLED" == "1" &&
		        "$STARTUP_EMERGENCY_LEGACY" == "1" &&
		        -n "$LEGACY_PID" ]] &&
		      (( SECONDS - EMERGENCY_LAST_ATTEMPT >= 120 )); then
			EMERGENCY_LAST_ATTEMPT=$SECONDS
			attempt_emergency_cluster_recovery "$traffic_mode"
		fi
	done
}

main()
{
	trap shutdown_components EXIT INT TERM
	initialize_runtime
	[[ "$MAP_WORKER_CONFIG" == "$MAP_WORKER_DIR/config.json" ]] ||
		fail "XIAND_MAP_WORKER_CONFIG must use the persistent config.json path"
	ensure_worker_config
	local enabled
	local traffic_mode
	local worker_token="${XIAND_WORKER_TOKEN:-}"
	enabled="$(config_value enabled)"
	traffic_mode="$(config_value traffic_mode)"
	if [[ "$enabled" == "1" && ${#worker_token} -lt 32 ]]; then
		fail "XIAND_WORKER_TOKEN must be at least 32 characters"
	fi
	if [[ "$enabled" == "1" && "$traffic_mode" == "active" &&
	      ! -f "$FALLBACK_LATCH" &&
	      "${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}" != "isolated-test-server-only" ]]; then
		fail "active worker mode requires isolated-test-server-only acknowledgement"
	fi

	start_tomcat
	if [[ "$enabled" != "1" ]]; then
		start_legacy_main
		write_runtime_mode legacy-main
	elif [[ "$traffic_mode" == "shadow" ]]; then
		start_legacy_main
		start_shadow_authority
	elif [[ -f "$FALLBACK_LATCH" ]]; then
		log "persistent worker fallback latch found; starting legacy main only"
		start_legacy_main
		write_runtime_mode legacy-fallback
		enabled=0
	else
		start_active_authority
	fi
	run_supervisor "$enabled" "$traffic_mode"
}

if [[ "${XIAND_STARTUP_LIBRARY_ONLY:-0}" != "1" ]]; then
	main "$@"
fi
