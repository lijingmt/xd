#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-${XIAND_ENV_FILE:-$ROOT_DIR/.env}}"
ENV_TEMPLATE="$ROOT_DIR/.env.example"

fail()
{
	echo "[env-setup] ERROR: $*" >&2
	exit 1
}

env_value()
{
	local key="$1"
	[[ -f "$ENV_FILE" ]] || return 0
	bash -c '
		set -a
		. "$1"
		printf "%s" "${!2-}"
	' _ "$ENV_FILE" "$key"
}

shell_quote()
{
	printf '%q' "$1"
}

upsert_env()
{
	local key="$1"
	local value="$2"
	local quoted_value
	local temp_file
	local line
	local replaced=0
	quoted_value="$(shell_quote "$value")"
	temp_file="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ "$line" =~ ^[[:space:]]*$key= ]]; then
			if [[ "$replaced" == "0" ]]; then
				printf '%s=%s\n' "$key" "$quoted_value" >> "$temp_file"
				replaced=1
			fi
			continue
		fi
		printf '%s\n' "$line" >> "$temp_file"
	done < "$ENV_FILE"
	if [[ "$replaced" == "0" ]]; then
		printf '%s=%s\n' "$key" "$quoted_value" >> "$temp_file"
	fi
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$ENV_FILE"
}

generate_token()
{
	command -v openssl >/dev/null 2>&1 ||
		fail "openssl is required to generate deployment tokens"
	openssl rand -hex 32
}

reject_control_characters()
{
	local value="$1"
	[[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] ||
		fail "MYSQL_PASSWORD must not contain newline characters"
}

main()
{
	local env_dir
	local mysql_password
	local worker_token
	local health_token

	[[ -f "$ENV_TEMPLATE" ]] || fail "missing template: $ENV_TEMPLATE"
	[[ ! -L "$ENV_FILE" ]] || fail ".env must not be a symlink"
	env_dir="$(dirname "$ENV_FILE")"
	[[ ! -L "$env_dir" ]] || fail ".env parent directory must not be a symlink"
	mkdir -p "$env_dir"
	if [[ ! -f "$ENV_FILE" ]]; then
		(umask 077 && cp "$ENV_TEMPLATE" "$ENV_FILE")
		echo "[env-setup] created $ENV_FILE from .env.example"
	fi
	chmod 600 "$ENV_FILE"

	mysql_password="$(env_value MYSQL_PASSWORD)"
	if [[ -z "$mysql_password" && -n "${MYSQL_PASSWORD:-}" ]]; then
		mysql_password="$MYSQL_PASSWORD"
	fi
	if [[ -z "$mysql_password" ]]; then
		if [[ ! -t 0 || ! -t 1 ]]; then
			fail "MYSQL_PASSWORD is missing; run this script in a terminal or export it first"
		fi
		IFS= read -r -s -p "MySQL password: " mysql_password
		echo
	fi
	[[ -n "$mysql_password" ]] || fail "MYSQL_PASSWORD must not be empty"
	reject_control_characters "$mysql_password"
	upsert_env MYSQL_PASSWORD "$mysql_password"

	worker_token="$(env_value XIAND_WORKER_TOKEN)"
	if (( ${#worker_token} < 32 )); then
		worker_token="$(generate_token)"
		upsert_env XIAND_WORKER_TOKEN "$worker_token"
	fi

	health_token="$(env_value XIAND_HEALTH_TOKEN)"
	if (( ${#health_token} < 24 )); then
		health_token="$(generate_token)"
		upsert_env XIAND_HEALTH_TOKEN "$health_token"
	fi

	chmod 600 "$ENV_FILE"
	echo "[env-setup] ready: $ENV_FILE (mode 600; secrets not printed)"
}

main "$@"
