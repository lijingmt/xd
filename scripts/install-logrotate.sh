#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/deploy/logrotate/xiand"
TARGET="${XIAND_LOGROTATE_TARGET:-/etc/logrotate.d/xiand}"

if [[ ! -f "$SOURCE" ]]; then
	echo "missing logrotate policy: $SOURCE" >&2
	exit 1
fi

install -o root -g root -m 0644 "$SOURCE" "$TARGET"
logrotate -d "$TARGET" >/dev/null
echo "installed $TARGET"
