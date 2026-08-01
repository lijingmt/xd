#!/bin/bash

# 逻辑区配置的安全运维入口。所有写入先备份，再以 rename 原子替换；daemon
# 仍是最终校验者，任一配置非法时会保留上一代完整快照。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZONE_DIR="${XIAND_LOGICAL_ZONE_DIR:-$PROJECT_ROOT/gamelib/etc/logical_zones}"
LOCK_DIR="$ZONE_DIR/.admin.lock"

usage() {
    echo "用法:"
    echo "  $0 list"
    echo "  $0 create <区号> <区名> <排序>"
    echo "  $0 set <区号> <enabled|registration_open|login_open|open_at|notes> <值>"
    echo "  $0 isolate <区号>"
    echo "  $0 merge <cluster> <区号> [区号...]"
    echo "  $0 open <区号>"
    echo "  $0 close <区号>"
    echo "配置目录可通过 XIAND_LOGICAL_ZONE_DIR 指定。"
}

valid_zone_id() {
    [[ "$1" =~ ^[a-z]{2}[0-9]{2}$ ]]
}

require_zone_file() {
    valid_zone_id "$1" || { echo "非法区号: $1" >&2; exit 1; }
    [ -f "$ZONE_DIR/$1.conf" ] || { echo "配置不存在: $1.conf" >&2; exit 1; }
}

lock_config() {
    mkdir -p "$ZONE_DIR"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "已有逻辑区运维操作执行中: $LOCK_DIR" >&2
        exit 1
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

set_field() {
    local zone_id="$1"
    local field="$2"
    local value="$3"
    local config="$ZONE_DIR/$zone_id.conf"
    local backup
    local temporary
    local revision

    require_zone_file "$zone_id"
    case "$field" in
        enabled|registration_open|login_open)
            [[ "$value" == "0" || "$value" == "1" ]] || {
                echo "$field 只能为 0 或 1" >&2; exit 1;
            }
            ;;
        isolation)
            [[ "$value" == "0" || "$value" == "1" ]] || {
                echo "isolation 只能为 0 或 1" >&2; exit 1;
            }
            ;;
        cluster)
            [[ "$value" =~ ^[a-z0-9_-]{1,32}$ ]] || {
                echo "cluster 格式非法" >&2; exit 1;
            }
            ;;
        open_at)
            [[ "$value" =~ ^[0-9]+$ ]] || {
                echo "open_at 必须是非负整数" >&2; exit 1;
            }
            ;;
        notes)
            [ "${#value}" -le 256 ] || { echo "notes 过长" >&2; exit 1; }
            [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || {
                echo "notes 不能包含换行" >&2; exit 1;
            }
            ;;
        *)
            echo "不允许修改字段: $field" >&2
            exit 1
            ;;
    esac

    revision="$(awk -F= '$1=="revision" {print $2; exit}' "$config")"
    [[ "$revision" =~ ^[0-9]+$ ]] || { echo "revision 非法" >&2; exit 1; }
    backup="$config.bak.$(date +%Y%m%d%H%M%S).$revision"
    temporary="$(mktemp "$ZONE_DIR/.$zone_id.conf.XXXXXX")"
    cp -p "$config" "$backup"
    awk -F= -v key="$field" -v val="$value" -v rev="$((revision+1))" '
        $1==key {print key "=" val; seen=1; next}
        $1=="revision" {print "revision=" rev; next}
        {print}
        END {if(!seen) exit 2}
    ' "$config" > "$temporary" || {
        rm -f "$temporary"
        echo "字段不存在，未修改: $field" >&2
        exit 1
    }
    chmod 644 "$temporary"
    mv "$temporary" "$config"
    echo "$zone_id: $field=$value, revision=$((revision+1)), 备份=$(basename "$backup")"
}

mkdir -p "$ZONE_DIR"
action="${1:-}"

case "$action" in
    list)
        for config in "$ZONE_DIR"/*.conf; do
            [ -f "$config" ] || continue
            awk -F= '
                $1=="zone_id" {zone=$2}
                $1=="name" {name=$2}
                $1=="revision" {revision=$2}
                $1=="enabled" {enabled=$2}
                $1=="registration_open" {registration=$2}
                $1=="login_open" {login=$2}
                $1=="isolation" {isolation=$2}
                $1=="cluster" {cluster=$2}
                END {printf "%s\t%s\trev=%s enabled=%s reg=%s login=%s isolation=%s cluster=%s\n", zone,name,revision,enabled,registration,login,isolation,cluster}
            ' "$config"
        done
        ;;
    create)
        zone_id="${2:-}"
        zone_name="${3:-}"
        sort_order="${4:-}"
        valid_zone_id "$zone_id" || { echo "非法区号: $zone_id" >&2; exit 1; }
        [ -n "$zone_name" ] && [ "${#zone_name}" -le 64 ] || { echo "区名为空或过长" >&2; exit 1; }
        [[ "$sort_order" =~ ^[0-9]+$ ]] || { echo "排序必须是非负整数" >&2; exit 1; }
        lock_config
        config="$ZONE_DIR/$zone_id.conf"
        [ ! -e "$config" ] || { echo "配置已存在: $config" >&2; exit 1; }
        temporary="$(mktemp "$ZONE_DIR/.$zone_id.conf.XXXXXX")"
        printf '%s\n' \
            'schema_version=1' 'revision=1' "zone_id=$zone_id" "name=$zone_name" \
            'enabled=1' 'registration_open=0' 'login_open=0' 'isolation=1' \
            'cluster=main' "sort=$sort_order" 'open_at=0' 'notes=安全创建，待验证后开放' \
            > "$temporary"
        chmod 644 "$temporary"
        mv "$temporary" "$config"
        echo "已安全创建 ${config}；默认关闭登录和注册。"
        ;;
    set)
        lock_config
        set_field "${2:-}" "${3:-}" "${4:-}"
        ;;
    isolate)
        lock_config
        set_field "${2:-}" isolation 1
        ;;
    merge)
        cluster="${2:-}"
        shift 2 || true
        [ "$#" -ge 2 ] || { echo "合区至少需要两个区号" >&2; exit 1; }
        [[ "$cluster" =~ ^[a-z0-9_-]{1,32}$ ]] || { echo "cluster 格式非法" >&2; exit 1; }
        lock_config
        for zone_id in "$@"; do require_zone_file "$zone_id"; done
        for zone_id in "$@"; do set_field "$zone_id" isolation 1; done
        for zone_id in "$@"; do set_field "$zone_id" cluster "$cluster"; done
        for zone_id in "$@"; do set_field "$zone_id" isolation 0; done
        ;;
    open)
        lock_config
        set_field "${2:-}" enabled 1
        set_field "${2:-}" login_open 1
        set_field "${2:-}" registration_open 1
        ;;
    close)
        lock_config
        set_field "${2:-}" registration_open 0
        set_field "${2:-}" login_open 0
        ;;
    *)
        usage
        exit 1
        ;;
esac
