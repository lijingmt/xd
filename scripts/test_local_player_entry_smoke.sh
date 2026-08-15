#!/usr/bin/env bash

set -euo pipefail

API_BASE="${XIAND_SMOKE_API_BASE:-http://localhost:8888}"
USER_ID="${XIAND_SMOKE_USER:-}"
PASSWORD="${XIAND_SMOKE_PASSWORD:-}"
CHARACTER_ID="${XIAND_SMOKE_CHARACTER:-}"
REQUIRE_BATTLE="${XIAND_SMOKE_REQUIRE_BATTLE:-0}"
WAIT_SECONDS="${XIAND_SMOKE_WAIT_SECONDS:-10}"
TXD=""
STARTED_AUTOFIGHT=0
INITIAL_AUTOFIGHT=0

fail()
{
	echo "[player-entry-smoke] ERROR: $*" >&2
	exit 1
}

json_post()
{
	local path="$1"
	local body="$2"
	curl -fsS --max-time 15 -X POST \
		-H 'Content-Type: application/json' \
		--data "$body" "$API_BASE$path"
}

game_command()
{
	local command_name="$1"
	curl -fsS --max-time 15 --get \
		--data-urlencode "txd=$TXD" \
		--data-urlencode "cmd=$command_name" \
		"$API_BASE/api/json"
}

stop_started_autofight()
{
	if [ "$STARTED_AUTOFIGHT" -eq 1 ] && [ -n "$TXD" ]; then
		curl -fsS --max-time 15 -X POST \
			--data-urlencode "txd=$TXD" \
			--data-urlencode 'action=off' \
			"$API_BASE/api/autofight" >/dev/null || true
		STARTED_AUTOFIGHT=0
	fi
}

trap stop_started_autofight EXIT

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -n "$USER_ID" ] || fail "set XIAND_SMOKE_USER"
[ -n "$PASSWORD" ] || fail "set XIAND_SMOKE_PASSWORD"
[[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || fail "XIAND_SMOKE_WAIT_SECONDS must be numeric"
[[ "$REQUIRE_BATTLE" == "0" || "$REQUIRE_BATTLE" == "1" ]] ||
	fail "XIAND_SMOKE_REQUIRE_BATTLE must be 0 or 1"

login_body=$(jq -cn --arg userid "$USER_ID" --arg password "$PASSWORD" \
	'{userid:$userid,password:$password}')
login_json=$(json_post '/api/account/login' "$login_body")
token=$(jq -r '.token // empty' <<<"$login_json")
[ -n "$token" ] || fail "account login did not return a token"

if [ -z "$CHARACTER_ID" ]; then
	CHARACTER_ID=$(jq -r --arg userid "$USER_ID" \
		'[.characters[] | select(.id==$userid and .available==1)][0].id //
		 [.characters[] | select(.available==1)][0].id // empty' \
		<<<"$login_json")
fi
[ -n "$CHARACTER_ID" ] || fail "no available character"

select_body=$(jq -cn --arg token "$token" --arg character_id "$CHARACTER_ID" \
	'{token:$token,character_id:$character_id}')
selected_json=$(json_post '/api/account/characters/select' "$select_body")
TXD=$(jq -r '.txd // empty' <<<"$selected_json")
[ -n "$TXD" ] || fail "character selection did not return txd"

entrance_json=$(game_command 'init')
TXD=$(jq -r '.txd // empty' <<<"$entrance_json")
enter_command=$(jq -r \
	'[.lines[].segments[]? |
	 select(.type=="button" and .label=="进入游戏") | .cmd][0] // empty' \
	<<<"$entrance_json")
[ -n "$enter_command" ] || fail "the real 进入游戏 button is missing"

entered_json=$(game_command "$enter_command")
TXD=$(jq -r '.txd // empty' <<<"$entered_json")
jq -e '.error == null and (.lines | length) > 0' \
	<<<"$entered_json" >/dev/null || fail "clicking 进入游戏 did not render a room"

look_json=$(game_command 'look')
TXD=$(jq -r '.txd // empty' <<<"$look_json")
myhp_json=$(game_command 'myhp')
TXD=$(jq -r '.txd // empty' <<<"$myhp_json")
inventory_json=$(game_command 'inventory')
TXD=$(jq -r '.txd // empty' <<<"$inventory_json")
skills_json=$(game_command 'skills')
TXD=$(jq -r '.txd // empty' <<<"$skills_json")

for response_name in look_json myhp_json inventory_json skills_json; do
	response_value="${!response_name}"
	jq -e '.error == null and (.lines | length) > 0' \
		<<<"$response_value" >/dev/null ||
		fail "$response_name did not return playable content"
done

status_json=$(curl -fsS --max-time 15 --get \
	--data-urlencode "txd=$TXD" "$API_BASE/api/status")
equipment_json=$(curl -fsS --max-time 15 --get \
	--data-urlencode "txd=$TXD" "$API_BASE/api/equipment_panel")
battle_json=$(curl -fsS --max-time 15 --get \
	--data-urlencode "txd=$TXD" "$API_BASE/api/battle_status")
jq -e '.name != null or .name_cn != null' <<<"$status_json" >/dev/null ||
	fail "status API is not playable"
jq -e '.error == null' <<<"$equipment_json" >/dev/null ||
	fail "equipment API is not playable"
jq -e 'has("in_battle")' <<<"$battle_json" >/dev/null ||
	fail "battle status API is not playable"

INITIAL_AUTOFIGHT=$(jq -r 'if .autofight then 1 else 0 end' <<<"$status_json")
if [ "$INITIAL_AUTOFIGHT" -eq 0 ]; then
	autofight_json=$(curl -fsS --max-time 15 -X POST \
		--data-urlencode "txd=$TXD" \
		--data-urlencode 'action=on' "$API_BASE/api/autofight")
	jq -e '.autofight == 1' <<<"$autofight_json" >/dev/null ||
		fail "basic autofight could not start"
	STARTED_AUTOFIGHT=1
fi

view_seen=0
battle_seen=$(jq -r 'if .in_battle then 1 else 0 end' <<<"$battle_json")
for ((attempt=0;attempt<WAIT_SECONDS;attempt++)); do
	autofight_view=$(curl -fsS --max-time 15 --get \
		--data-urlencode "txd=$TXD" "$API_BASE/api/autofight_view")
	if [ "$(jq -r '.sequence // 0' <<<"$autofight_view")" -gt 0 ]; then
		view_seen=1
	fi
	battle_json=$(curl -fsS --max-time 15 --get \
		--data-urlencode "txd=$TXD" "$API_BASE/api/battle_status")
	if [ "$(jq -r 'if .in_battle then 1 else 0 end' <<<"$battle_json")" -eq 1 ]; then
		battle_seen=1
	fi
	if [ "$view_seen" -eq 1 ] &&
	   { [ "$REQUIRE_BATTLE" -eq 0 ] || [ "$battle_seen" -eq 1 ]; }; then
		break
	fi
	sleep 1
done

if [ "$REQUIRE_BATTLE" -eq 1 ] && [ "$battle_seen" -ne 1 ]; then
	fail "no real battle was observed; place the smoke character in a monster map"
fi

stop_started_autofight
echo "[player-entry-smoke] PASS character=$CHARACTER_ID button=clicked room=ok status=ok inventory=ok equipment=ok skills=ok autofight=ok view_seen=$view_seen battle_seen=$battle_seen"
