#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[restart] building Vue frontend"
(
	cd "$ROOT_DIR/vue_source"
	npm run build
)

exec "$ROOT_DIR/scripts/restart_with_testunit.sh" "$@"
