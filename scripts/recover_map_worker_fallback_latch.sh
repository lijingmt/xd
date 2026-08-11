#!/usr/bin/env bash
set -Eeuo pipefail

# Recover a historical active-mode circuit breaker only after the deployment
# wrapper has proved that the previous container is no longer authoritative.
# The latch is archived, never discarded, and unsafe/in-flight state keeps the
# legacy fallback authoritative.

RUNTIME_DIR="${1:-}"
SAFE_STOP_CONFIRMED="${XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED:-0}"
ACTIVE_ACK="${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}"
FORCE_ACTIVE="${XIAND_MAP_WORKER_FORCE_ACTIVE:-0}"

log()
{
	printf '[map-worker-recovery] %s\n' "$*"
}

fail()
{
	printf '[map-worker-recovery] ERROR: %s\n' "$*" >&2
	exit 1
}

[[ -n "$RUNTIME_DIR" && "$RUNTIME_DIR" == /* ]] ||
	fail "runtime directory must be an absolute path"
[[ "$FORCE_ACTIVE" == "0" || "$FORCE_ACTIVE" == "1" ]] ||
	fail "force-active flag is invalid"
[[ -d "$RUNTIME_DIR" && ! -L "$RUNTIME_DIR" ]] ||
	fail "runtime directory is missing or unsafe"

CONFIG_FILE="$RUNTIME_DIR/config.json"
FALLBACK_LATCH="$RUNTIME_DIR/fallback-latched"
CONTROL_PLANE="$RUNTIME_DIR/control_plane.json"
CONTROL_PLANE_BACKUP="$RUNTIME_DIR/control_plane.json.bak"
SOCIAL_OUTBOX="$RUNTIME_DIR/social_outbox"

[[ -f "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]] ||
	fail "worker config is missing or unsafe"
[[ -e "$FALLBACK_LATCH" || -L "$FALLBACK_LATCH" ]] || {
	log "no historical fallback latch is present"
	exit 0
}
[[ -f "$FALLBACK_LATCH" && ! -L "$FALLBACK_LATCH" ]] ||
	fail "fallback latch is not a regular file"
(( $(wc -c < "$FALLBACK_LATCH") <= 4096 )) ||
	fail "fallback latch is unexpectedly large"

read -r ENABLED TRAFFIC_MODE < <(
	python3 - "$CONFIG_FILE" <<'PY'
import json
import os
import sys

path = sys.argv[1]
if os.path.getsize(path) > 65536:
    raise SystemExit("worker config is too large")
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
if config.get("schema_version") != 2:
    raise SystemExit("worker config schema is invalid")
enabled = config.get("enabled")
traffic_mode = config.get("traffic_mode")
if type(enabled) is not int or enabled not in (0, 1):
    raise SystemExit("worker config enabled is invalid")
if traffic_mode not in ("shadow", "active"):
    raise SystemExit("worker config traffic_mode is invalid")
print(enabled, traffic_mode)
PY
)

if [[ "$ENABLED" != "1" || "$TRAFFIC_MODE" != "active" ]]; then
	log "fallback latch retained because desired mode is not active"
	exit 0
fi
if [[ "$ACTIVE_ACK" != "isolated-test-server-only" ]]; then
	log "fallback latch retained because active acknowledgement is absent"
	exit 0
fi
if [[ "$SAFE_STOP_CONFIRMED" != "1" ]]; then
	log "fallback latch retained because safe stop was not confirmed"
	exit 0
fi
if [[ "$FORCE_ACTIVE" == "1" ]]; then
	log "force-active requested; mandatory ownership audit remains enabled"
fi

# Exit 0 only when every persisted ownership/mutation record is terminal and
# expired.  Identifiers and payloads are deliberately never printed.
if ! python3 - "$CONTROL_PLANE" "$CONTROL_PLANE_BACKUP" "$SOCIAL_OUTBOX" <<'PY'
import glob
import json
import os
import sys
import time

control_paths = sys.argv[1:3]
outbox_dir = sys.argv[3]
now = int(time.time())
sys.excepthook = lambda *_: None


def load_mapping(path, maximum_size):
    if os.path.islink(path) or not os.path.isfile(path):
        raise ValueError("unsafe persisted state path")
    if os.path.getsize(path) > maximum_size:
        raise ValueError("persisted state is too large")
    with open(path, encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("persisted state is not a mapping")
    return value


def mapping_rows(value, name):
    if name not in value:
        raise ValueError(name + " is missing")
    rows = value[name]
    if not isinstance(rows, dict):
        raise ValueError(name + " is not a mapping")
    if not all(isinstance(row, dict) for row in rows.values()):
        raise ValueError(name + " contains a malformed entry")
    return list(rows.values())


for path in control_paths:
    if not os.path.lexists(path):
        continue
    control = load_mapping(path, 16 * 1024 * 1024)
    if control.get("version") != 3:
        raise ValueError("control plane schema is unsupported")
    leases = mapping_rows(control, "player_leases")
    handoffs = mapping_rows(control, "handoffs")
    envelopes = mapping_rows(control, "envelopes")
    escrows = mapping_rows(control, "escrow_transactions")
    pk_sessions = mapping_rows(control, "pk_sessions")

    if any(row.get("state") != "active" or
           type(row.get("expires_at")) is not int or
           row["expires_at"] > now for row in leases):
        raise ValueError("a player lease is still live")
    if any(row.get("state") not in ("committed", "aborted") or
           type(row.get("expires_at")) is not int or
           row["expires_at"] > now for row in handoffs):
        raise ValueError("a handoff is not terminal and expired")
    if envelopes or escrows or pk_sessions:
        raise ValueError("a durable mutation remains unsettled")

if os.path.lexists(outbox_dir):
    if os.path.islink(outbox_dir) or not os.path.isdir(outbox_dir):
        raise ValueError("social outbox directory is unsafe")
    paths = sorted(glob.glob(os.path.join(outbox_dir, "w[0-9][0-9].json")))
    paths += sorted(glob.glob(os.path.join(outbox_dir,
                                           "w[0-9][0-9].json.bak")))
    for path in paths:
        outbox = load_mapping(path, 16 * 1024 * 1024)
        if outbox.get("version") != 1:
            raise ValueError("social outbox schema is unsupported")
        events = mapping_rows(outbox, "events")
        if any(type(event.get("expires_at")) is not int or
               event["expires_at"] > now for event in events):
            raise ValueError("a durable social event is still live")
PY
then
	log "fallback latch retained because persisted ownership audit is not clean"
	exit 0
fi

ARCHIVE_DIR="$RUNTIME_DIR/fallback-history"
[[ ! -L "$ARCHIVE_DIR" ]] || fail "fallback history directory is unsafe"
mkdir -p "$ARCHIVE_DIR"
chmod 700 "$ARCHIVE_DIR"
ARCHIVE_FILE="$ARCHIVE_DIR/fallback-latched.$(date -u +%Y%m%dT%H%M%SZ).$$"
[[ ! -e "$ARCHIVE_FILE" ]] || fail "fallback archive collision"
mv -- "$FALLBACK_LATCH" "$ARCHIVE_FILE"
chmod 600 "$ARCHIVE_FILE"
log "historical fallback latch archived after safe state audit; active cold start is permitted"
