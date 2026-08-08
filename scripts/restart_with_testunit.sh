#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${XIAND_HOST:-127.0.0.1}"
PORT="${XIAND_PORT:-13800}"
HTTP_PORT="${XIAND_HTTP_PORT:-8888}"
SCREEN_NAME="${XIAND_SCREEN_NAME:-xiand-$PORT}"
TIMEOUT_SECONDS="${XIAND_RESTART_TIMEOUT:-180}"
GAME_LOG="$ROOT_DIR/log/stderr.$PORT"
ERROR_LOG="$ROOT_DIR/log/error.$PORT"
RUNTIME_LOG="$ROOT_DIR/log/restart.$PORT.log"
PIKE_BIN="${PIKE_BIN:-}"
PIKE_STACK_DEPTH="${XIAND_PIKE_STACK_DEPTH:-1000000}"
PIKE_THREAD_STACK="${XIAND_PIKE_THREAD_STACK:-67108864}"

log()
{
	echo "[restart] $*"
}

fail()
{
	echo "[restart] ERROR: $*" >&2
	if [[ -f "$RUNTIME_LOG" ]]; then
		echo "----- runtime log tail -----" >&2
		tail -80 "$RUNTIME_LOG" >&2 || true
	fi
	if [[ -f "$GAME_LOG" ]]; then
		echo "----- game log tail -----" >&2
		tail -160 "$GAME_LOG" >&2 || true
	fi
	exit 1
}

screen_session_exists()
{
	local output
	output="$(screen -ls 2>/dev/null || true)"
	echo "$output" | grep -Fq ".$SCREEN_NAME"
}

stop_screen()
{
	if screen_session_exists; then
		log "stopping screen session $SCREEN_NAME"
		screen -S "$SCREEN_NAME" -X quit >/dev/null 2>&1 || true
		sleep 1
	fi
}

graceful_shutdown()
{
	if ! lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
		return 0
	fi
	if ! command -v nc >/dev/null 2>&1; then
		log "nc is unavailable; refusing an unsafe forced restart"
		return 1
	fi

	log "requesting in-game shutdown so online players are saved"
	(
		sleep 1
		printf 'shutdown_safe\r\n'
		sleep 2
	) | nc -w 3 "$HOST" "$PORT" >/dev/null 2>&1 || true

	local deadline=$((SECONDS + 30))
	while (( SECONDS < deadline )); do
		if ! lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
			log "in-game shutdown completed"
			return 0
		fi
		sleep 1
	done

	log "in-game shutdown timed out; refusing an unsafe forced restart"
	return 1
}

stop_port_processes()
{
	local pids
	pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
	if [[ -z "$pids" ]]; then
		return
	fi

	log "stopping processes listening on $PORT: $pids"
	kill $pids >/dev/null 2>&1 || true

	local deadline=$((SECONDS + 10))
	while (( SECONDS < deadline )); do
		pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
		if [[ -z "$pids" ]]; then
			return
		fi
		sleep 1
	done

	log "forcing processes listening on $PORT: $pids"
	kill -9 $pids >/dev/null 2>&1 || true
	sleep 1
}

check_http_port()
{
	local pids
	pids="$(lsof -tiTCP:"$HTTP_PORT" -sTCP:LISTEN 2>/dev/null || true)"
	if [[ -n "$pids" ]]; then
		fail "HTTP port $HTTP_PORT is occupied by PID(s): $pids"
	fi
}

prepare_environment()
{
	umask 027
	if [[ -f "$ROOT_DIR/.env" ]]; then
		set -a
		source "$ROOT_DIR/.env"
		set +a
	fi
	if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
		fail "MYSQL_PASSWORD must be provided through the environment or .env"
	fi
	export MYSQL_PASSWORD

	if [[ -z "$PIKE_BIN" ]]; then
		PIKE_BIN="$(command -v pike || true)"
	fi
	if [[ -z "$PIKE_BIN" || ! -x "$PIKE_BIN" ]]; then
		fail "Pike binary is not executable: ${PIKE_BIN:-not found}"
	fi
	if [[ ! "$PIKE_STACK_DEPTH" =~ ^[0-9]+$ ||
	      ! "$PIKE_THREAD_STACK" =~ ^[0-9]+$ ]]; then
		fail "Pike stack settings must be positive integers"
	fi
	if (( PIKE_STACK_DEPTH <= 0 || PIKE_THREAD_STACK <= 0 )); then
		fail "Pike stack settings must be positive integers"
	fi
	if ! command -v screen >/dev/null 2>&1; then
		fail "screen command is required"
	fi
}

prepare_logs()
{
	mkdir -p "$ROOT_DIR/log"
	chmod 750 "$ROOT_DIR/log"
	if [[ -f "$GAME_LOG" ]]; then
		local rotated="$GAME_LOG.$(date +%Y%m%d-%H%M%S).restart"
		mv "$GAME_LOG" "$rotated"
		gzip -f "$rotated" || true
	fi
	# driver 的长期错误日志只在服务完全停止后轮转，避免历史编译栈
	# 无限追加；压缩归档仍完整保留，便于后续诊断。
	if [[ -f "$ERROR_LOG" ]] &&
	   [[ "$(wc -c < "$ERROR_LOG")" -gt 10485760 ]]; then
		local error_rotated="$ERROR_LOG.$(date +%Y%m%d-%H%M%S).restart"
		mv "$ERROR_LOG" "$error_rotated"
		gzip -f "$error_rotated" || true
	fi
	: > "$RUNTIME_LOG"
	touch "$GAME_LOG" "$ERROR_LOG"
	chmod 640 "$RUNTIME_LOG" "$GAME_LOG" "$ERROR_LOG"
}

start_server()
{
	log "starting Xiand on $HOST:$PORT (HTTP $HTTP_PORT) in screen $SCREEN_NAME"
	screen -dmS "$SCREEN_NAME" bash -lc \
		"cd '$ROOT_DIR' && '$PIKE_BIN' -s'$PIKE_STACK_DEPTH' -ss'$PIKE_THREAD_STACK' '$ROOT_DIR/lowlib/driver.pike' -i '$HOST' -p '$PORT' '$ROOT_DIR/' >> '$RUNTIME_LOG' 2>&1"
}

wait_for_testunit()
{
	local deadline=$((SECONDS + TIMEOUT_SECONDS))
	local port_ready=0
	local testunit_passed=0
	local summary=""

	while (( SECONDS < deadline )); do
		if lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
			port_ready=1
		fi

		if [[ "$testunit_passed" -eq 0 &&
		      -f "$GAME_LOG" ]] &&
		   grep -q '\[TESTUNITD\] COMPLETE' "$GAME_LOG"; then
			summary="$(grep '\[TESTUNITD\] COMPLETE' "$GAME_LOG" | tail -1)"
			if echo "$summary" | grep -q 'failed=0'; then
				log "TestUnit passed: $summary"
				testunit_passed=1
			else
				fail "TestUnit reported failures: $summary"
			fi
		fi

		if [[ "$testunit_passed" -eq 1 ]] &&
		   lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1 &&
		   lsof -tiTCP:"$HTTP_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
			return
		fi

		if ! screen_session_exists && [[ "$port_ready" -eq 0 ]]; then
			fail "screen session $SCREEN_NAME exited before port $PORT opened"
		fi
		sleep 1
	done

	fail "timed out after ${TIMEOUT_SECONDS}s waiting for TestUnit"
}

verify_ports()
{
	if ! lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
		fail "game port $PORT is not listening after tests"
	fi
	if ! lsof -tiTCP:"$HTTP_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
		fail "HTTP port $HTTP_PORT is not listening after tests"
	fi
	log "server is ready on game port $PORT and HTTP port $HTTP_PORT"
}

main()
{
	cd "$ROOT_DIR"
	prepare_environment
	if ! graceful_shutdown; then
		fail "in-game shutdown did not confirm all player saves; server was left running"
	fi
	stop_screen
	check_http_port
	prepare_logs
	start_server
	wait_for_testunit
	verify_ports
}

main "$@"
