#!/bin/bash

# ============================================
# xiand Docker 启动脚本（不重建镜像）
# ============================================
# 此脚本将：
# 1. 停止现有的 Docker 容器
# 2. 启动 MUD 和 Tomcat 容器（使用已有镜像）
#
# 用法：
#   ./restart-docker.sh [GAME_AREA] [TOMCAT_PORT] [API_PORT]
#
# 参数说明：
#   GAME_AREA    - 游戏区号（默认：xd01）
#   TOMCAT_PORT  - Tomcat HTTP 端口（默认：9001）
#   API_PORT     - HTTP API 端口（默认：8888）
#
# 示例：
#   ./restart-docker.sh                    # 使用默认值 xd01 9001 8888
#   ./restart-docker.sh xd01 9001 8888     # 指定区号、端口、API端口
#   ./restart-docker.sh xd02 9002 8889     # xd02 区，端口 9002，API 8889
#   ./restart-docker.sh xd01 9001 8888 --workers 5
#   ./restart-all-docker.sh --force-active
#   XIAND_MAP_WORKER_DEPLOY_CONFIG=deploy/map_workers/config.json \
#       ./restart-docker.sh xd01-02 2002 2003
#
# 环境变量：
#   GAME_AREAS  - 游戏分区列表，逗号分隔（默认：xd01,xd02,xd03,xd04,xd05）
#   例：GAME_AREAS="xd01,xd02,xd03" ./restart-docker.sh xd01 9001 8888
#   XIAND_LOGICAL_ZONE_SEED_DIR - 首次部署的逻辑区种子目录（必须为绝对路径）
# ============================================

set -e

# ============================================
# 配置参数
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLI_WORKER_COUNT=""
FORCE_ACTIVE=0
POSITIONAL_ARGS=()
while (( $# )); do
    case "$1" in
        --workers)
            (( $# >= 2 )) || {
                echo "[ERROR] --workers 需要一个 1-16 的整数" >&2
                exit 1
            }
            [[ -z "$CLI_WORKER_COUNT" ]] || {
                echo "[ERROR] --workers 不能重复指定" >&2
                exit 1
            }
            CLI_WORKER_COUNT="$2"
            shift 2
            ;;
        --workers=*)
            [[ -z "$CLI_WORKER_COUNT" ]] || {
                echo "[ERROR] --workers 不能重复指定" >&2
                exit 1
            }
            CLI_WORKER_COUNT="${1#--workers=}"
            shift
            ;;
        --force-active)
            [[ "$FORCE_ACTIVE" == "0" ]] || {
                echo "[ERROR] --force-active 不能重复指定" >&2
                exit 1
            }
            FORCE_ACTIVE=1
            shift
            ;;
        --*)
            echo "[ERROR] 未知参数：$1" >&2
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done
(( ${#POSITIONAL_ARGS[@]} <= 3 )) || {
    echo "[ERROR] 用法：$0 [GAME_AREA] [TOMCAT_PORT] [API_PORT] [--workers N] [--force-active]" >&2
    exit 1
}
set -- "${POSITIONAL_ARGS[@]}"

# 自动定位项目根目录
PROJECT_ROOT="$SCRIPT_DIR"
if [ ! -f "$PROJECT_ROOT/docker/docker-compose.yml" ]; then
    if [ -f "$SCRIPT_DIR/../docker/docker-compose.yml" ]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi

XIAND_ENV_FILE="${XIAND_ENV_FILE:-$PROJECT_ROOT/.env}"
RESOLVED_XIAND_ENV_FILE="$XIAND_ENV_FILE"
INHERITED_MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
INHERITED_XIAND_WORKER_TOKEN="${XIAND_WORKER_TOKEN:-}"
INHERITED_XIAND_MAP_WORKER_ENABLED="${XIAND_MAP_WORKER_ENABLED:-}"
INHERITED_XIAND_MAP_WORKER_TRAFFIC_MODE="${XIAND_MAP_WORKER_TRAFFIC_MODE:-}"
INHERITED_XIAND_MAP_WORKER_COUNT="${XIAND_MAP_WORKER_COUNT:-}"
INHERITED_XIAND_MAP_WORKER_CAPACITY="${XIAND_MAP_WORKER_CAPACITY:-}"
INHERITED_XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}"
ENV_SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup_deploy_env.sh"
if [ ! -x "$ENV_SETUP_SCRIPT" ]; then
    echo "[ERROR] 缺少可执行的环境初始化脚本：$ENV_SETUP_SCRIPT" >&2
    exit 1
fi
"$ENV_SETUP_SCRIPT" "$XIAND_ENV_FILE"
if [ -f "$XIAND_ENV_FILE" ]; then
    set -a
    . "$XIAND_ENV_FILE"
    set +a
fi
XIAND_ENV_FILE="$RESOLVED_XIAND_ENV_FILE"
[[ -z "$INHERITED_MYSQL_PASSWORD" ]] ||
    MYSQL_PASSWORD="$INHERITED_MYSQL_PASSWORD"
[[ -z "$INHERITED_XIAND_WORKER_TOKEN" ]] ||
    XIAND_WORKER_TOKEN="$INHERITED_XIAND_WORKER_TOKEN"
[[ -z "$INHERITED_XIAND_MAP_WORKER_ENABLED" ]] ||
    XIAND_MAP_WORKER_ENABLED="$INHERITED_XIAND_MAP_WORKER_ENABLED"
[[ -z "$INHERITED_XIAND_MAP_WORKER_TRAFFIC_MODE" ]] ||
    XIAND_MAP_WORKER_TRAFFIC_MODE="$INHERITED_XIAND_MAP_WORKER_TRAFFIC_MODE"
[[ -z "$INHERITED_XIAND_MAP_WORKER_COUNT" ]] ||
    XIAND_MAP_WORKER_COUNT="$INHERITED_XIAND_MAP_WORKER_COUNT"
[[ -z "$INHERITED_XIAND_MAP_WORKER_CAPACITY" ]] ||
    XIAND_MAP_WORKER_CAPACITY="$INHERITED_XIAND_MAP_WORKER_CAPACITY"
[[ -z "$INHERITED_XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK" ]] ||
    XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="$INHERITED_XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK"

XIAND_MAP_WORKER_ENABLED="${XIAND_MAP_WORKER_ENABLED:-1}"
XIAND_MAP_WORKER_TRAFFIC_MODE="${XIAND_MAP_WORKER_TRAFFIC_MODE:-shadow}"
XIAND_MAP_WORKER_COUNT="${XIAND_MAP_WORKER_COUNT:-3}"
XIAND_MAP_WORKER_CAPACITY="${XIAND_MAP_WORKER_CAPACITY:-100}"
XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="${XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK:-}"
XIAND_MAP_WORKER_COUNT_OVERRIDE=""
if [[ -n "$CLI_WORKER_COUNT" ]]; then
    [[ "$CLI_WORKER_COUNT" =~ ^[0-9]+$ ]] &&
        (( CLI_WORKER_COUNT >= 1 && CLI_WORKER_COUNT <= 16 )) || {
        echo "[ERROR] --workers 必须是 1-16 的整数" >&2
        exit 1
    }
    XIAND_MAP_WORKER_COUNT="$CLI_WORKER_COUNT"
    XIAND_MAP_WORKER_COUNT_OVERRIDE="$CLI_WORKER_COUNT"
fi

DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
SHARED_ITEM_DIR="${XIAND_SHARED_ITEM_DIR:-/usr/local/games/allxd/item}"
LOGICAL_ZONE_SEED_DIR="${XIAND_LOGICAL_ZONE_SEED_DIR:-$PROJECT_ROOT/deploy/logical_zones}"
SELECTED_DOCKER_IMAGE=""
MAP_WORKER_SAFE_STOP_CONFIRMED=0

# 十一职业隐藏大神传承：部署时同时校验秘籍、技能主体和掉落池。
# 无相的 3 本隐藏书（归墟/混元/无极）在账号解锁该职业后才生效，仍走同一池子。
HIDDEN_MYTHIC_SKILL_IDS=(
    "wanjianguizong"
    "taiqingjianyu"
    "pozhenjianyi"
    "taixulingyun"
    "wanlingchaosheng"
    "sixiangfengjin"
    "jiutianleiyin"
    "taiyixuanguang"
    "bingpochanshen"
    "zhutianwujie"
    "tianshajianyi"
    "wuyingfenghou"
    "xuemoshijie"
    "shurakuangyi"
    "xuehailieshang"
    "huangquanwudu"
    "wanxiangshihun"
    "jiuyouduzhang"
    "wuyingjuemie"
    "jiuyouguibu"
    "liudaozhangmu"
    "wanshanchaogong"
    "buzhouzhenji"
	"tiandichengbi"
	"xinghezhuiluo"
	"zhoutianjingzhi"
	"wanxiangxingbi"
	"cixinpudu"
	"huimingtianlu"
	"wanmuxinchun"
	"liuhehuichun"
	"wuxiangguixu"
	"wuxianghunyuan"
	"wuxiangwuji"
	"taijiguixu"
	"taijihunyuan"
	"taijiwuji"
)

# 太古隐藏传承以服务端目录为唯一事实来源，部署脚本不维护第二份70项名单。
ANCIENT_SKILL_CATALOG="$PROJECT_ROOT/gamelib/single/daemons/ancient_skilld.pike"
ANCIENT_HIDDEN_SKILL_IDS=()

load_ancient_hidden_skill_ids() {
    local catalog_entry
    local skill_id

    if [ ! -s "$ANCIENT_SKILL_CATALOG" ]; then
        print_error "太古隐藏传承目录缺失：$ANCIENT_SKILL_CATALOG"
        exit 1
    fi

    ANCIENT_HIDDEN_SKILL_IDS=()
    while IFS= read -r catalog_entry; do
        skill_id="${catalog_entry#\"}"
        skill_id="${skill_id%%|*}"
        ANCIENT_HIDDEN_SKILL_IDS+=("$skill_id")
    done < <(grep -oE '"[a-z0-9]+\|[^"]+"' "$ANCIENT_SKILL_CATALOG")

    if [ "${#ANCIENT_HIDDEN_SKILL_IDS[@]}" -ne 70 ]; then
        print_error "太古隐藏传承目录应包含70个技能，实际为${#ANCIENT_HIDDEN_SKILL_IDS[@]}个"
        exit 1
    fi
    if printf '%s\n' "${ANCIENT_HIDDEN_SKILL_IDS[@]}" | sort | uniq -d | grep -q .; then
        print_error "太古隐藏传承目录存在重复技能ID"
        exit 1
    fi
}

# 从命令行参数或环境变量读取配置
# 优先级：命令行参数 > 环境变量 > 默认值
GAME_AREA_INPUT="${1:-${GAME_AREA:-xd01}}"
TOMCAT_HTTP_PORT="${2:-${TOMCAT_HTTP_PORT:-9001}}"
HTTP_API_PORT="${3:-${HTTP_API_PORT:-8888}}"

# Docker Hub 配置（将通过 get_docker_username 函数获取）
DOCKER_USER="${DOCKER_USER:-}"
DOCKER_TOKEN="${DOCKER_TOKEN:-}"

# 分区列表配置（用于 Vue 前端下拉框）
# 格式：xd01,xd02,xd03,xd04,xd05 或 xd01-05
GAME_AREAS="${GAME_AREAS:-xd01,xd02,xd03,xd04,xd05}"

# 标准化 GAME_AREA 格式（支持 xd01、01、1 或范围 xd01-05、01-05）
if [[ $GAME_AREA_INPUT =~ ^xd[0-9]+(-[0-9]+)?$ ]]; then
    # 格式: xd01 或 xd01-05
    GAME_AREA="$GAME_AREA_INPUT"
elif [[ $GAME_AREA_INPUT =~ ^[0-9]+(-[0-9]+)?$ ]]; then
    # 格式: 01 或 01-05 或 1 或 1-5
    GAME_AREA=$(echo "$GAME_AREA_INPUT" | sed 's/^/xd/')
    # 确保两位数格式（如果是范围，两个数字都要处理）
    if [[ $GAME_AREA =~ ^xd([0-9]+)-([0-9]+)$ ]]; then
        start=$(printf "%02d" "${BASH_REMATCH[1]}")
        end=$(printf "%02d" "${BASH_REMATCH[2]}")
        GAME_AREA="xd${start}-${end}"
    else
        GAME_AREA=$(printf "xd%02d" "${GAME_AREA#xd}")
    fi
else
	echo "[ERROR] GAME_AREA 必须是 xdNN、NN 或 xdNN-NN 格式" >&2
	exit 1
fi

# 提取数字部分作为 AREA（用于某些地方需要纯数字或范围）
AREA="${GAME_AREA#xd}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

preflight_map_worker_deploy_config() {
    local deploy_config="${XIAND_MAP_WORKER_DEPLOY_CONFIG:-}"
    local preflight_dir
    local preflight_config
    local desired_values
    local desired_enabled
    local desired_traffic_mode
    local desired_worker_count
    local desired_worker_capacity
    local live_config_dir="/usr/local/games/allxd/${GAME_AREA}/data_xiand/map_workers"
    local live_config="$live_config_dir/config.json"
    [ -n "$deploy_config" ] || return 0
    if [ -L "$live_config_dir" ] || [ -L "$live_config" ] ||
       { [ -e "$live_config" ] && [ ! -f "$live_config" ]; }; then
        print_error "宿主worker配置路径不安全，旧容器保持运行：$live_config"
        return 1
    fi
    preflight_dir="$(mktemp -d)"
    preflight_config="$preflight_dir/config.json"
    if ! XIAND_MAP_WORKER_DEPLOY_CONFIG="$deploy_config" \
         XIAND_MAP_WORKER_CONFIG="$preflight_config" \
            "$PROJECT_ROOT/scripts/sync_map_worker_deploy_config.sh" \
            >/dev/null; then
        rmdir "$preflight_dir" 2>/dev/null || true
        print_error "Git worker配置预检失败，旧容器保持运行"
        return 1
    fi
    desired_values="$(python3 - "$preflight_config" <<'PY'
import json
import sys
config = json.load(open(sys.argv[1], encoding="utf-8"))
print("\t".join(str(config[key]) for key in
                ("enabled", "traffic_mode", "worker_count", "worker_capacity")))
PY
)"
    unlink "$preflight_config"
    rmdir "$preflight_dir"
    IFS=$'\t' read -r desired_enabled desired_traffic_mode \
        desired_worker_count desired_worker_capacity <<< "$desired_values"
    XIAND_MAP_WORKER_ENABLED="$desired_enabled"
    XIAND_MAP_WORKER_TRAFFIC_MODE="$desired_traffic_mode"
    XIAND_MAP_WORKER_COUNT="$desired_worker_count"
    XIAND_MAP_WORKER_CAPACITY="$desired_worker_capacity"
    if [ -n "$XIAND_MAP_WORKER_COUNT_OVERRIDE" ]; then
        XIAND_MAP_WORKER_COUNT="$XIAND_MAP_WORKER_COUNT_OVERRIDE"
    fi
    if [ "$desired_traffic_mode" = "active" ]; then
        XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only
    fi
    print_success "Git worker配置预检通过：mode=$desired_traffic_mode workers=$XIAND_MAP_WORKER_COUNT"
}

prepare_map_worker_runtime() {
    local config_dir="/usr/local/games/allxd/${GAME_AREA}/data_xiand/map_workers"
    local config_file="$config_dir/config.json"
    local deploy_config="${XIAND_MAP_WORKER_DEPLOY_CONFIG:-}"
    local worker_token
    local actual_values
    local actual_enabled
    local actual_traffic_mode
    local actual_worker_count
    local actual_worker_capacity
    if [ -n "$deploy_config" ]; then
        XIAND_MAP_WORKER_DEPLOY_CONFIG="$deploy_config" \
        XIAND_MAP_WORKER_CONFIG="$config_file" \
            "$PROJECT_ROOT/scripts/sync_map_worker_deploy_config.sh"
        if [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["traffic_mode"])' "$config_file")" = "active" ]; then
            # A reviewed, version-controlled active config is the explicit
            # deployment acknowledgement. The persistent fallback latch still
            # takes precedence inside the container.
            XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only
        fi
    fi
    XIAND_ENV_FILE="$XIAND_ENV_FILE" \
    XIAND_MAP_WORKER_CONFIG="$config_file" \
    XIAND_MAP_WORKER_ENABLED="$XIAND_MAP_WORKER_ENABLED" \
    XIAND_MAP_WORKER_TRAFFIC_MODE="$XIAND_MAP_WORKER_TRAFFIC_MODE" \
    XIAND_MAP_WORKER_COUNT="$XIAND_MAP_WORKER_COUNT" \
    XIAND_MAP_WORKER_COUNT_OVERRIDE="$XIAND_MAP_WORKER_COUNT_OVERRIDE" \
    XIAND_MAP_WORKER_CAPACITY="$XIAND_MAP_WORKER_CAPACITY" \
    XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="$XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK" \
        "$PROJECT_ROOT/scripts/bootstrap_map_worker_runtime.sh"

    actual_values="$(python3 - "$config_file" <<'PY'
import json
import sys
config = json.load(open(sys.argv[1], encoding="utf-8"))
print("\t".join(str(config[key]) for key in
                ("enabled", "traffic_mode", "worker_count", "worker_capacity")))
PY
)"
    IFS=$'\t' read -r actual_enabled actual_traffic_mode \
        actual_worker_count actual_worker_capacity <<< "$actual_values"
    XIAND_MAP_WORKER_ENABLED="$actual_enabled"
    XIAND_MAP_WORKER_TRAFFIC_MODE="$actual_traffic_mode"
    XIAND_MAP_WORKER_COUNT="$actual_worker_count"
    XIAND_MAP_WORKER_CAPACITY="$actual_worker_capacity"
    if [ "$actual_traffic_mode" = "active" ] && [ -n "$deploy_config" ]; then
        XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK=isolated-test-server-only
    fi

    if [ -n "$INHERITED_XIAND_WORKER_TOKEN" ]; then
        XIAND_WORKER_TOKEN="$INHERITED_XIAND_WORKER_TOKEN"
    else
        XIAND_WORKER_TOKEN="$(awk -F= '
            $1 == "XIAND_WORKER_TOKEN" {
                print substr($0,index($0,"=")+1)
                exit
            }
        ' "$XIAND_ENV_FILE")"
    fi
    worker_token="${XIAND_WORKER_TOKEN:-}"
    if [ "$XIAND_MAP_WORKER_ENABLED" = "1" ] && [ "${#worker_token}" -lt 32 ]; then
        print_error "XIAND_WORKER_TOKEN 生成失败或长度不足32位"
        exit 1
    fi
    if [ ! -s "$config_file" ] || [ -L "$config_file" ]; then
        print_error "worker配置未安全持久化到宿主机：$config_file"
        exit 1
    fi
    chmod 700 "$config_dir"
    chmod 600 "$config_file"
    export XIAND_WORKER_TOKEN XIAND_MAP_WORKER_ENABLED
    export XIAND_MAP_WORKER_TRAFFIC_MODE XIAND_MAP_WORKER_COUNT
    export XIAND_MAP_WORKER_CAPACITY XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK
    print_success "worker配置已持久化到宿主机：$config_file"
}

recover_historical_map_worker_fallback() {
    local config_dir="/usr/local/games/allxd/${GAME_AREA}/data_xiand/map_workers"
    XIAND_MAP_WORKER_SAFE_STOP_CONFIRMED="$MAP_WORKER_SAFE_STOP_CONFIRMED" \
    XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK="$XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK" \
    XIAND_MAP_WORKER_FORCE_ACTIVE="$FORCE_ACTIVE" \
    XIAND_MAP_WORKER_AUDIT_IMAGE="$SELECTED_DOCKER_IMAGE" \
        "$PROJECT_ROOT/scripts/recover_map_worker_fallback_latch.sh" \
        "$config_dir"
}

verify_map_worker_runtime_in_container() {
    local container_name="$1"
    local deadline=$((SECONDS + 240))
    local runtime_mode=""
    while (( SECONDS < deadline )); do
        if ! docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q true; then
            print_error "容器在worker启动验证期间退出：$container_name"
            docker logs --tail 120 "$container_name" 2>/dev/null || true
            return 1
        fi
        runtime_mode="$(docker exec "$container_name" \
            sh -c 'cat /app/xiand/data_xiand/map_workers/runtime-mode 2>/dev/null' \
            2>/dev/null || true)"
        case "$runtime_mode" in
            shadow|active)
                if docker exec \
                    -e XIAND_MAP_WORKER_LAUNCHER=background \
                    -e XIAND_MAP_WORKER_AREA_NAME="$GAME_AREA" \
                    "$container_name" \
                    /app/xiand/scripts/map_worker_cluster.sh health \
                    >/dev/null 2>&1; then
                    print_success "容器worker运行验证通过：$runtime_mode"
                    return 0
                fi
                ;;
            legacy-main|legacy-fallback|shadow-degraded)
                if docker exec "$container_name" \
                    curl -fsS --max-time 3 http://127.0.0.1:8888/health \
                    >/dev/null 2>&1; then
                    if [ "$runtime_mode" = "legacy-fallback" ]; then
                        if [ "$FORCE_ACTIVE" = "1" ]; then
                            print_error "--force-active 未能进入 active；服务已安全回退旧主进程"
                            return 1
                        fi
                        print_warning "active Worker 已安全熔断，当前运行旧主进程：$runtime_mode"
                    else
                        print_success "容器已安全运行于旧主进程模式：$runtime_mode"
                    fi
                    return 0
                fi
                ;;
        esac
        sleep 2
    done
    print_error "240秒内未完成worker/旧主进程运行验证"
    docker logs --tail 120 "$container_name" 2>/dev/null || true
    return 1
}

# 函数：检查必要的命令
check_commands() {
    local commands=("docker" "rsync")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd 命令未找到，请先安装"
            exit 1
        fi
    done
    if [ ! -x "$PROJECT_ROOT/scripts/recover_map_worker_fallback_latch.sh" ]; then
        print_error "缺少可执行的 Worker 熔断恢复审计脚本"
        exit 1
    fi
}

# 准备逻辑区持久化目录。模板可以自动补齐，真实 xdNN.conf 只有在显式指定
# XIAND_LOGICAL_ZONE_SEED_DIR 时才初始化，且永不覆盖管理员已经修改的配置。
prepare_logical_zone_directory() {
    local source_zone_dir="$1"
    local target_zone_dir="$2"
    local metadata
    local config
    local config_name
    local copied=0
    local existing=0

    if [ -L "$target_zone_dir" ]; then
        print_error "逻辑区配置目录不能是符号链接：$target_zone_dir"
        exit 1
    fi
    mkdir -p "$target_zone_dir"

    for metadata in README.md zone.conf.example; do
        if [ -f "$source_zone_dir/$metadata" ] && \
           [ ! -e "$target_zone_dir/$metadata" ]; then
            cp -p "$source_zone_dir/$metadata" "$target_zone_dir/$metadata"
        fi
    done

    for config in "$target_zone_dir"/*.conf; do
        [ -f "$config" ] || continue
        existing=$((existing+1))
    done

    if [ "$existing" -eq 0 ] && [ -n "$LOGICAL_ZONE_SEED_DIR" ]; then
        if [[ "$LOGICAL_ZONE_SEED_DIR" != /* ]] || \
           [ ! -d "$LOGICAL_ZONE_SEED_DIR" ]; then
            print_error "XIAND_LOGICAL_ZONE_SEED_DIR 必须是已存在的绝对目录"
            exit 1
        fi
        for config in "$LOGICAL_ZONE_SEED_DIR"/xd[0-9][0-9].conf; do
            [ -f "$config" ] || continue
            config_name="$(basename "$config")"
            if [ ! -e "$target_zone_dir/$config_name" ]; then
                cp -p "$config" "$target_zone_dir/$config_name"
                copied=$((copied+1))
            fi
        done
        if [ "$copied" -eq 0 ]; then
            print_error "首次部署未找到任何逻辑区种子配置"
            exit 1
        fi
        print_info "首次部署逻辑区配置完成：新增 ${copied} 份"
    elif [ "$existing" -gt 0 ]; then
        print_info "检测到 ${existing} 份线上逻辑区配置，保留原文件且跳过首装种子"
    fi

    for config in "$target_zone_dir"/*.conf; do
        [ -e "$config" ] || continue
        config_name="$(basename "$config")"
        if [ -L "$config" ] || [ ! -f "$config" ] || \
           [[ ! "$config_name" =~ ^xd[0-9]{2}\.conf$ ]] || \
           [ ! -r "$config" ]; then
            print_error "逻辑区配置文件类型、文件名或权限非法：$config"
            exit 1
        fi
        if [ "$(wc -c < "$config")" -gt 8192 ]; then
            print_error "逻辑区配置超过 8192 字节：$config"
            exit 1
        fi
    done
    print_success "逻辑区运行时配置目录已就绪：$target_zone_dir"
}

# 容器启动后确认 etc 确实来自宿主持久化挂载，并检查分区代码没有漏包。
verify_logical_zone_runtime_in_container() {
    local container_name="$1"
    local mounted

    mounted="$(docker inspect --format '{{range .Mounts}}{{println .Destination}}{{end}}' \
        "$container_name" 2>/dev/null || true)"
    if ! grep -Fxq '/app/xiand/gamelib/etc' <<< "$mounted"; then
        print_error "容器未挂载逻辑区持久化 etc 目录，停止部署"
        exit 1
    fi

    if ! docker exec "$container_name" /bin/bash -lc '
        test -s /app/xiand/gamelib/single/daemons/logical_zoned.pike &&
        test -s /app/xiand/gamelib/single/daemons/_logical_zone_mod/config_loader.pike &&
        test -s /app/xiand/gamelib/single/daemons/_logical_zone_mod/reconciliation.pike &&
        test -s /app/xiand/gamelib/single/daemons/_home_mod/logical_zone.pike &&
        test -s /app/xiand/gamelib/cmds/mgr_logical_zone.pike &&
        test -d /app/xiand/gamelib/etc/logical_zones
    '; then
        print_error "容器内逻辑区代码或配置挂载校验失败，停止部署"
        exit 1
    fi
    print_success "容器逻辑区代码与持久化配置挂载校验通过"
}

# 函数：同步镜像外置的游戏物品目录
sync_item_directory() {
    local source_item_dir="$PROJECT_ROOT/gamelib/clone/item"
    local shared_item_dir="$SHARED_ITEM_DIR"
    local skill_id

    if [ ! -d "$source_item_dir" ]; then
        print_error "源 item 目录不存在: $source_item_dir"
        exit 1
    fi

    load_ancient_hidden_skill_ids

    if [[ "$shared_item_dir" != /* ]]; then
        print_error "共享 item 目录必须是绝对路径: $shared_item_dir"
        exit 1
    fi

    if ! mkdir -p "$shared_item_dir"; then
        print_error "无法创建共享 item 目录: $shared_item_dir"
        exit 1
    fi

    print_info "同步游戏物品到容器映射目录..."
    echo "  来源：$source_item_dir/"
    echo "  目标：$shared_item_dir/"
    if ! rsync -a "$source_item_dir/" "$shared_item_dir/"; then
        print_error "游戏物品同步失败，停止部署"
        exit 1
    fi

    # 基础方士技能书继续作为旧部署事故的兼容哨兵。
    if [ ! -s "$shared_item_dir/book/huling1" ]; then
        print_error "物品同步校验失败，缺少方士技能书: $shared_item_dir/book/huling1"
        exit 1
    fi

    for skill_id in "${HIDDEN_MYTHIC_SKILL_IDS[@]}"; do
        if [ ! -s "$shared_item_dir/book/$skill_id" ]; then
            print_error "物品同步校验失败，缺少隐藏秘籍: $shared_item_dir/book/$skill_id"
            exit 1
        fi
    done

    for skill_id in "${ANCIENT_HIDDEN_SKILL_IDS[@]}"; do
        if [ ! -s "$shared_item_dir/book/$skill_id" ]; then
            print_error "物品同步校验失败，缺少太古隐藏秘籍: $shared_item_dir/book/$skill_id"
            exit 1
        fi
    done

    chmod -R 755 "$shared_item_dir" 2>/dev/null || true
    print_success "游戏物品同步完成，并已校验${#HIDDEN_MYTHIC_SKILL_IDS[@]}本原隐藏秘籍与${#ANCIENT_HIDDEN_SKILL_IDS[@]}本太古隐藏秘籍"
}

# 将仓库中的房间等级目录增量合并到持久化挂载。已有路径保持线上值，
# 只补齐新地图条目；使用同目录临时文件和原子替换避免中断时留下半行。
sync_room_level_catalog() {
    local source_catalog="$1"
    local target_catalog="$2"
    local target_dir
    local temp_catalog
    local level
    local room_path
    local room_name
    local added=0

    if [ ! -s "$source_catalog" ]; then
        print_error "房间等级源目录缺失：$source_catalog"
        return 1
    fi
    target_dir="$(dirname "$target_catalog")"
    mkdir -p "$target_dir"
    temp_catalog="$(mktemp "$target_dir/.room_level.merge.XXXXXX")"
    if [ -f "$target_catalog" ]; then
        cp -p "$target_catalog" "$temp_catalog"
    else
        cp -p "$source_catalog" "$temp_catalog"
        added="$(wc -l < "$source_catalog")"
        chmod 666 "$temp_catalog"
        mv -f "$temp_catalog" "$target_catalog"
        print_success "房间等级目录已同步：新增 ${added} 条，已有路径保持不变"
        return 0
    fi

    while IFS='|' read -r level room_path room_name; do
        [ -n "$level" ] && [ -n "$room_path" ] && [ -n "$room_name" ] || \
            continue
        if ! [[ "$level" =~ ^[0-9]+$ ]] || \
           ! [[ "$room_path" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
            print_error "房间等级源目录存在非法条目：$room_path"
            rm -f "$temp_catalog"
            return 1
        fi
        # 只以部署前的目标为判断基准，使源目录中同一路径的历史多级
        # 条目能成组补齐；已有线上路径仍完全不改。
        if ! grep -Fq "|${room_path}|" "$target_catalog"; then
            printf '%s|%s|%s\n' "$level" "$room_path" "$room_name" \
                >> "$temp_catalog"
            added=$((added+1))
        fi
    done < "$source_catalog"

    chmod 666 "$temp_catalog"
    mv -f "$temp_catalog" "$target_catalog"
    print_success "房间等级目录已同步：新增 ${added} 条，已有路径保持不变"
}

# 函数：验证运行镜像与外挂 item 目录中的隐藏技能资源完全一致
verify_hidden_mythic_assets_in_container() {
    local container_name="$1"
    local skill_id

    for skill_id in "${HIDDEN_MYTHIC_SKILL_IDS[@]}"; do
        if ! docker exec "$container_name" \
            test -s "/app/xiand/gamelib/clone/item/book/$skill_id"; then
            print_error "容器隐藏秘籍校验失败: book/$skill_id"
            return 1
        fi

        if ! docker exec "$container_name" \
            test -s "/app/xiand/gamelib/single/skills/$skill_id"; then
            print_error "容器技能主体校验失败: skills/$skill_id；请先重建并推送最新镜像"
            return 1
        fi

        if ! docker exec "$container_name" \
            grep -Fq "\"book/$skill_id\"" \
            /app/xiand/gamelib/single/daemons/itemsd.pike; then
            print_error "容器隐藏掉落池校验失败: book/$skill_id；请先重建并推送最新镜像"
            return 1
        fi
    done

	if [ "${#ANCIENT_HIDDEN_SKILL_IDS[@]}" -ne 70 ]; then
		load_ancient_hidden_skill_ids
	fi
	for skill_id in "${ANCIENT_HIDDEN_SKILL_IDS[@]}"; do
		if ! docker exec "$container_name" \
			test -s "/app/xiand/gamelib/clone/item/book/$skill_id"; then
			print_error "容器太古隐藏秘籍校验失败: book/$skill_id"
			return 1
		fi

		if ! docker exec "$container_name" \
			test -s "/app/xiand/gamelib/single/skills/$skill_id"; then
			print_error "容器太古技能主体校验失败: skills/$skill_id；请先重建并推送最新镜像"
			return 1
		fi

		if ! docker exec "$container_name" \
			grep -Fq "\"$skill_id|" \
			/app/xiand/gamelib/single/daemons/ancient_skilld.pike; then
			print_error "容器太古传承目录校验失败: $skill_id；请先重建并推送最新镜像"
			return 1
		fi
	done

    print_success "容器内${#HIDDEN_MYTHIC_SKILL_IDS[@]}套原隐藏传承与${#ANCIENT_HIDDEN_SKILL_IDS[@]}套太古隐藏传承均已校验"
}

# 函数：把中立阵营职业图标和人物头像更新到容器内 Tomcat 的新旧访问路径
copy_neutral_profession_images_to_container() {
    local container_name="$1"
    local app_root="/app/xiand"
    local tomcat_root="/usr/local/tomcat/webapps/ROOT"
    local image_names=(
        "third_logo.png"
        "human_fangshi_logo.png"
        "human_fangshi_male.png"
        "human_fangshi_female.png"
        "zhenyue_logo.png"
        "zhenyue_male.png"
        "zhenyue_female.png"
        "zhenyue_male.gif"
		"zhenyue_female.gif"
		"tianxiang_logo.png"
		"tianxiang_male.png"
		"tianxiang_female.png"
		"tianxiang_male.gif"
		"tianxiang_female.gif"
		"lingyi_logo.png"
		"lingyi_male.png"
		"lingyi_female.png"
		"lingyi_male.gif"
		"lingyi_female.gif"
		"wuxiang_logo.png"
		"wuxiang_male.png"
		"wuxiang_female.png"
		"wuxiang_logo.gif"
		"wuxiang_male.gif"
		"wuxiang_female.gif"
		"taiji_logo.png"
		"taiji_male.png"
		"taiji_female.png"
		"taiji_logo.gif"
		"taiji_male.gif"
		"taiji_female.gif"
    )
    local image_name
    local source_image
    local web_image

    if ! docker exec "$container_name" mkdir -p \
        "$app_root/images" "$app_root/web/images" \
        "$tomcat_root/images" "$tomcat_root/xd/images"; then
        print_error "无法创建容器内 Tomcat 头像目录"
        return 1
    fi

    for image_name in "${image_names[@]}"; do
        source_image="$PROJECT_ROOT/images/$image_name"
        web_image="$PROJECT_ROOT/web/images/$image_name"

        if [ ! -f "$source_image" ] || [ ! -f "$web_image" ]; then
            print_error "中立职业图片源文件不完整: $image_name"
            return 1
        fi

        if ! docker cp "$source_image" \
            "$container_name:$app_root/images/$image_name"; then
            print_error "复制容器项目中立职业图片失败: $image_name"
            return 1
        fi

        if ! docker cp "$web_image" \
            "$container_name:$app_root/web/images/$image_name"; then
            print_error "复制容器 Web 源中立职业图片失败: $image_name"
            return 1
        fi

        if ! docker cp "$web_image" \
            "$container_name:$tomcat_root/images/$image_name"; then
            print_error "复制 Web 中立职业图片失败: $image_name"
            return 1
        fi

        if ! docker cp "$source_image" \
            "$container_name:$tomcat_root/xd/images/$image_name"; then
            print_error "复制游戏中立职业图片失败: $image_name"
            return 1
        fi

        if ! docker exec "$container_name" \
            test -s "$app_root/images/$image_name" ||
           ! docker exec "$container_name" \
            test -s "$app_root/web/images/$image_name" ||
           ! docker exec "$container_name" \
            test -s "$tomcat_root/images/$image_name" ||
           ! docker exec "$container_name" \
            test -s "$tomcat_root/xd/images/$image_name"; then
            print_error "容器内 Tomcat 中立职业图片校验失败: $image_name"
            return 1
        fi
    done

    print_success "方士阵营图标及男女头像已更新到容器项目和 Tomcat"
}

# 函数：从 Docker 配置获取用户名
get_docker_username() {
    # 如果已通过环境变量指定，直接使用
    if [ -n "$DOCKER_USER" ]; then
        echo "$DOCKER_USER"
        return 0
    fi

    # 尝试从 docker info 获取
    local username=$(docker info 2>/dev/null | grep -E "^Username:" | sed 's/Username: *//' | tr -d '\r')
    if [ -n "$username" ]; then
        echo "$username"
        return 0
    fi

    # 尝试从 ~/.docker/config.json 读取
    local config_file="$HOME/.docker/config.json"
    if [ -f "$config_file" ]; then
        # 尝试解析 auths（Base64 解码）
        # 注意：如果使用 credsStore，这里无法直接获取
        local auths=$(python3 -c "
import json, sys, base64
try:
    with open('$config_file', 'r') as f:
        config = json.load(f)
    for key, val in config.get('auths', {}).items():
        if 'auth' in val:
            decoded = base64.b64decode(val['auth']).decode('utf-8')
            print(decoded.split(':')[0])
            break
except Exception as e:
    pass
" 2>/dev/null)
        if [ -n "$auths" ]; then
            echo "$auths"
            return 0
        fi
    fi

    return 1
}

# 函数：初始化游戏数据库
initialize_game_database() {
    local game_area="$1"

    # 解析游戏区号
    local db_name="$game_area"

    # 检查 MySQL 是否可用
    if ! command -v mysql &> /dev/null && ! command -v mariadb &> /dev/null; then
        print_warning "MySQL 客户端未安装，跳过数据库初始化"
        return 0
    fi

    local mysql_cmd="mysql"
    command -v mysql &> /dev/null || mysql_cmd="mariadb"

    # 使用与容器相同的 TCP 路径验证认证，避免本机 socket
    # 能登录、但 Docker 网段账号密码不同时误判为可用。
    if ! MYSQL_PWD="$MYSQL_PASSWORD" "$mysql_cmd" \
        -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" \
        -N -B -e "SELECT 1" >/dev/null 2>&1; then
        print_error "MySQL 认证失败，拒绝启动拍卖/排行数据库不可用的容器"
        return 1
    fi

    # 尝试创建数据库
    if MYSQL_PWD="$MYSQL_PASSWORD" "$mysql_cmd" \
        -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" \
        -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>/dev/null; then
        print_success "数据库 '${db_name}' 已创建"
    else
        print_error "无法创建数据库 '${db_name}'"
        return 1
    fi

    # 检查数据库是否为空，如果为空则导入 xd.sql
    local sql_script="${PROJECT_ROOT}/xd.sql"
    if [ -f "$sql_script" ]; then
        local table_count
        if ! table_count=$(MYSQL_PWD="$MYSQL_PASSWORD" "$mysql_cmd" \
            -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -N -B \
            -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}';" \
            2>/dev/null); then
            print_error "无法检查数据库 '${db_name}'"
            return 1
        fi
        if [ "$table_count" -eq 0 ]; then
            print_info "数据库 '${db_name}' 为空，正在导入 xd.sql..."
            if MYSQL_PWD="$MYSQL_PASSWORD" "$mysql_cmd" \
                -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" \
                "$db_name" < "$sql_script" 2>/dev/null; then
                print_success "数据库 '${db_name}' 导入成功"
            else
                print_error "数据库 '${db_name}' 导入失败"
                return 1
            fi
        else
            print_info "数据库 '${db_name}' 已有 ${table_count} 张表，跳过导入"
        fi
    else
        print_warning "SQL 文件不存在: $sql_script"
    fi
}

# 函数：准备游戏数据目录（保留用于兼容，实际由 prepare_data_directories 处理）
prepare_game_directories() {
    local game_area="$1"

    local base_path="/usr/local/games/allxd"
    local game_path="${base_path}/${game_area}"
    local log_path="${base_path}/log/${game_area}"

    # 创建目录
    mkdir -p "${game_path}" 2>/dev/null || print_warning "无法创建目录 ${game_path}"
    mkdir -p "${log_path}" 2>/dev/null || print_warning "无法创建目录 ${log_path}"

    # 设置权限
    chmod 750 "${game_path}" "${log_path}" 2>/dev/null || true

    print_success "游戏数据目录已准备就绪"
}

# 函数：打开防火墙端口
open_firewall_port() {
    local port=$1
    print_info "打开防火墙端口: $port"

    if command -v firewall-cmd &> /dev/null; then
        if sudo firewall-cmd --query-port=$port/tcp 2>/dev/null | grep -q "yes"; then
            print_info "端口 $port 已开放"
        else
            if sudo firewall-cmd --permanent --add-port=$port/tcp > /dev/null 2>&1; then
                if sudo firewall-cmd --reload > /dev/null 2>&1; then
                    print_success "端口 $port 已成功打开"
                else
                    print_warning "防火墙重新加载失败，请手动运行: sudo firewall-cmd --reload"
                fi
            else
                print_warning "无法打开端口 $port，请检查权限或手动运行: sudo firewall-cmd --permanent --add-port=$port/tcp && sudo firewall-cmd --reload"
            fi
        fi
    else
        print_warning "未检测到 firewalld，请手动打开端口 $port"
    fi
}

ensure_logrotate_policy() {
    local source_policy="$PROJECT_ROOT/deploy/logrotate/xiand"
    local target_policy="/etc/logrotate.d/xiand"
    local installer="$PROJECT_ROOT/scripts/install-logrotate.sh"

    if [ ! -s "$source_policy" ]; then
        print_warning "日志轮转策略缺失：$source_policy"
        return
    fi
    if [ -r "$target_policy" ] && cmp -s "$source_policy" "$target_policy"; then
        print_success "宿主机日志轮转策略已是最新版本"
        return
    fi
    if [ "$(id -u)" -eq 0 ]; then
        if "$installer"; then
            print_success "宿主机日志轮转策略已安装并校验"
        else
            print_warning "日志轮转策略安装失败；游戏仍可启动，请检查 logrotate"
        fi
        return
    fi
    print_warning "宿主机日志轮转策略缺失或过期；请执行：sudo $installer"
}

# 函数：拉取 Docker 镜像
pull_docker_images() {
    print_info "拉取 Docker 镜像..."
    echo ""

    # 如果有 token，先登录 Docker Hub
    if [ -n "$DOCKER_TOKEN" ]; then
        print_info "登录 Docker Hub ($DOCKER_USER)..."
        if echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin > /dev/null 2>&1; then
            print_success "Docker Hub 登录成功"
        else
            print_warning "Docker Hub 登录失败，尝试直接拉取镜像..."
        fi
    fi

    # 拉取统一镜像（MUD + Tomcat）
    print_info "拉取统一镜像 (${DOCKER_USER}/xiand-all:latest)..."
    if docker pull ${DOCKER_USER}/xiand-all:latest 2>/dev/null; then
        print_success "统一镜像拉取成功"
        docker tag ${DOCKER_USER}/xiand-all:latest xiand-all:latest 2>/dev/null || true
        SELECTED_DOCKER_IMAGE="${DOCKER_USER}/xiand-all:latest"
    else
        print_warning "远程镜像拉取失败，使用本地构建的镜像..."
        if docker image inspect xiand-all:latest >/dev/null 2>&1; then
            print_success "使用本地 xiand-all:latest 镜像"
            SELECTED_DOCKER_IMAGE="xiand-all:latest"
        else
            print_error "无法找到 xiand-all 镜像，请先运行 ./rebuild-image.sh 构建镜像"
            exit 1
        fi
    fi
    echo ""

    # 显示镜像信息
    print_info "已有的 Docker 镜像："
    docker images | grep -E "xiand-all|REPOSITORY" | head -3
    echo ""
}

# 先让容器内的集群完成停流和全员原子存档，再停止 PID 1。若无法证明
# Worker 已安全退出，则保留原容器继续运行，不进入删除/覆盖流程。
stop_existing_container_safely() {
    local container_name="xiand-$GAME_AREA"
    local exit_code=""
    MAP_WORKER_SAFE_STOP_CONFIRMED=0
    if ! docker ps --format '{{.Names}}' 2>/dev/null | \
       grep -Fxq "$container_name"; then
        MAP_WORKER_SAFE_STOP_CONFIRMED=1
        return 0
    fi

    print_info "安全停止旧容器 $container_name（先停流并保存所有 Worker）..."
    if docker exec "$container_name" \
       test -f "/app/xiand/log/map-workers/$GAME_AREA/topology.json"; then
        if ! "$PROJECT_ROOT/scripts/stop_old_map_worker_cluster.sh" \
            "$container_name" "$GAME_AREA"; then
            print_error "Worker 集群未能证明安全存档，拒绝停止或删除旧容器"
            exit 1
        fi
    fi

    if ! docker stop -t 600 "$container_name" >/dev/null; then
        print_error "旧容器未能在安全超时内停止，拒绝继续部署"
        exit 1
    fi
    exit_code="$(docker inspect -f '{{.State.ExitCode}}' \
        "$container_name" 2>/dev/null || true)"
    if [ "$exit_code" = "137" ]; then
        print_error "旧容器被强制终止（exit 137），拒绝删除并停止部署"
        exit 1
    fi
    MAP_WORKER_SAFE_STOP_CONFIRMED=1
    print_success "旧容器已完成安全停止"
}

# 函数：创建必要的数据目录
prepare_data_directories() {
    print_info "准备数据目录..."

    local area_num="$AREA"
    if [[ "$area_num" =~ ^xd ]]; then
        area_num="${area_num#xd}"
    fi

    # item 不进入 Docker 镜像，部署时必须同步到实际的共享挂载目录。
    sync_item_directory

    # 检查是否是范围格式（01-05）
    if [[ $area_num =~ ^([0-9]+)-([0-9]+)$ ]]; then
        # 合服目录: /usr/local/games/allxd/xd01-05/
        local area_dir="/usr/local/games/allxd/xd$area_num"
        mkdir -p "$area_dir/data_xiand"
        chmod -R 755 "$area_dir" 2>/dev/null || true
        print_success "已创建合服目录: /usr/local/games/allxd/xd$area_num/"
    else
        # 单区目录: /usr/local/games/allxd/xd01/
        local area_dir="/usr/local/games/allxd/xd$area_num"
        mkdir -p "$area_dir/data_xiand"
        chmod -R 755 "$area_dir" 2>/dev/null || true
        print_success "已创建目录: /usr/local/games/allxd/xd$area_num/"
    fi

    # 创建用户数据子目录（u 和 bangpai）
    local data_dir="/usr/local/games/allxd/xd$area_num/data_xiand"
    mkdir -p "$data_dir/u"
    mkdir -p "$data_dir/bangpai"
    if ! sync_room_level_catalog \
       "$PROJECT_ROOT/data_xiand/room_level.log" \
       "$data_dir/room_level.log"; then
        print_error "房间等级目录同步失败，停止部署"
        exit 1
    fi
    find "$data_dir" -type d -exec chmod 700 {} + 2>/dev/null || true
    find "$data_dir" -type f -exec chmod 600 {} + 2>/dev/null || true
    print_success "已创建用户数据目录: u/ 和 bangpai/"

    # 创建日志目录: /usr/local/games/allxd/log/xd01/
    local log_dir="/usr/local/games/allxd/log/xd$area_num"
    local source_log_dir="/usr/local/games/xiand/log"

    mkdir -p "$log_dir"

    # 创建所有必需的日志子目录（根据代码中 append_file 调用分析）
    local log_subdirs=(
        "pk"                      # userd.pike: human/monst 用户日志
        "stat/online"             # countd.pike: 在线统计
        "stat/consume"            # 各种消费统计
        "stat/daily"              # user_countd.pike: 每日统计
        "stat/reg"                # 注册审计
        "stat/money_consume"      # 金币消费统计
        "fee_log"                 # 费用日志
        "home"                    # 家园日志
        "home/drop"               # 家园掉落日志
        "auto_learn"              # auto_learn 日志
        "push"                    # push 推送日志
        "daily"                   # 每日日志
        "month"                   # 月度日志
        "db_log/daily_user"       # 脱敏统计 SQL 审计
        "db_log/reg_new"          # 注册 SQL 审计
    )

    for subdir in "${log_subdirs[@]}"; do
        mkdir -p "$log_dir/$subdir"
    done

    # 如果源目录存在，复制源 log 目录的其他子目录结构
    if [ -d "$source_log_dir" ]; then
        for subdir in "$source_log_dir"/*; do
            if [ -d "$subdir" ]; then
                local dirname=$(basename "$subdir")
                mkdir -p "$log_dir/$dirname"
                # 如果源子目录有内容且目标子目录为空，则复制内容
                if [ -z "$(ls -A "$log_dir/$dirname" 2>/dev/null)" ] && [ -n "$(ls -A "$subdir" 2>/dev/null)" ]; then
                    cp -r "$subdir"/* "$log_dir/$dirname/" 2>/dev/null || true
                fi
            fi
        done
    fi

    chmod 750 "$log_dir"

    # 创建 etc 目录: /usr/local/games/allxd/xd01/etc/
    local etc_dir="/usr/local/games/allxd/xd$area_num/etc"
    local source_etc_dir="$PROJECT_ROOT/gamelib/etc"

    mkdir -p "$etc_dir"

    # 复制源 etc 目录的所有内容（如果目标为空）
    if [ -d "$source_etc_dir" ]; then
        # 检查目标目录是否为空
        if [ -z "$(ls -A "$etc_dir" 2>/dev/null)" ]; then
            print_info "复制初始化 etc 数据..."
            # logical_zones 单独处理，防止开发机的 xdNN.conf 被意外带到生产。
            rsync -a --exclude 'logical_zones/' "$source_etc_dir/" "$etc_dir/"
            print_success "已复制初始化 etc 数据"
        else
            print_info "etc 目录已存在数据，跳过整体复制"
            for conf_file in account_characters.conf; do
                if [ -f "$source_etc_dir/$conf_file" ]; then
                    cp -f "$source_etc_dir/$conf_file" "$etc_dir/$conf_file"
                    print_info "已同步配置文件: $conf_file"
                fi
            done
        fi

		# 容器直接挂载此目录；在线修改 .conf 后 MUD 会在 5 秒内热加载。
		prepare_logical_zone_directory \
			"$source_etc_dir/logical_zones" "$etc_dir/logical_zones"
    fi

    chmod -R 755 "$etc_dir" 2>/dev/null || true

    # 修改权限
	find "/usr/local/games/allxd/log/xd$area_num" -type d -exec chmod 750 {} + 2>/dev/null || true
	find "/usr/local/games/allxd/log/xd$area_num" -type f -exec chmod 640 {} + 2>/dev/null || true
	find "/usr/local/games/allxd/xd$area_num/data_xiand" -type d -exec chmod 700 {} + 2>/dev/null || true
	find "/usr/local/games/allxd/xd$area_num/data_xiand" -type f -exec chmod 600 {} + 2>/dev/null || true
	# etc 包含逻辑区热配置，MUD 只需读取；禁止世界可写，避免隔离策略被篡改。
	find "$etc_dir" -type d -exec chmod 755 {} + 2>/dev/null || true
	find "$etc_dir" -type f -exec chmod 644 {} + 2>/dev/null || true

    print_success "数据目录权限已修改"
}

# 主流程
main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   xiand Docker 启动脚本             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    MYSQL_USER="${MYSQL_USER:-root}"
    MYSQL_HOST="${MYSQL_HOST:-172.17.0.1}"
    MYSQL_PORT="${MYSQL_PORT:-3306}"
    if [ -z "${MYSQL_PASSWORD:-}" ]; then
        print_error "MYSQL_PASSWORD 必须通过环境变量或受限权限的 .env 提供"
        echo ""
        echo "首次部署请在终端执行："
        echo "  cd $PROJECT_ROOT"
        echo "  ./scripts/setup_deploy_env.sh"
        exit 1
    fi

    # 显示使用说明
    echo "用法："
    echo "  $0 [GAME_AREA] [TOMCAT_HTTP_PORT] [HTTP_API_PORT]"
    echo ""
    echo "示例："
    echo "  $0                                  # 使用默认值 xd01、端口 9001、API 8888"
    echo "  $0 xd01                             # 指定区号 xd01，其他使用默认值"
    echo "  $0 xd01 9001                        # 指定区号 xd01、端口 9001、API 8888"
    echo "  $0 xd01 9001 8888                   # 指定区号 xd01、端口 9001、API 8888"
    echo "  $0 xd02 9002 8889                   # 指定区号 xd02、端口 9002、API 8889"
    echo ""
    echo "环境变量："
    echo "  GAME_AREAS='xd01,xd02,xd03,xd04,xd05'  # Vue 前端分区列表"
    echo "  XIAND_LOGICAL_ZONE_SEED_DIR=/path/to/seed # 可选的首装逻辑区配置"
    echo "  DOCKER_USER=用户名                    # Docker Hub 用户名"
    echo ""
    echo "镜像说明："
    echo "  使用统一镜像 (自动从 Docker 配置获取用户名)"
    echo ""

    # ============================================
    # 打包 vue_source 前端
    # ============================================
    print_info "[0/6] 打包 vue_source 前端..."
    cd "${PROJECT_ROOT}/vue_source" && node build.js
    if [ $? -eq 0 ]; then
        print_success "vue_source 打包成功！"
    else
        print_error "vue_source 打包失败！"
        exit 1
    fi
    cd "${PROJECT_ROOT}"
    echo ""

    # 检查必要命令
    check_commands
    preflight_map_worker_deploy_config
    if [ "$FORCE_ACTIVE" = "1" ] && {
       [ "$XIAND_MAP_WORKER_ENABLED" != "1" ] ||
       [ "$XIAND_MAP_WORKER_TRAFFIC_MODE" != "active" ]; }; then
        print_error "--force-active 需要经过校验的 enabled=1、traffic_mode=active 配置"
        exit 1
    fi

    # 获取 Docker 用户名
    if [ -z "$DOCKER_USER" ]; then
        DOCKER_USER=$(get_docker_username)
        if [ -z "$DOCKER_USER" ]; then
            print_warning "无法自动获取 Docker 用户名，请设置 DOCKER_USER 环境变量"
            print_info "示例: DOCKER_USER=your_username $0 $@"
            DOCKER_USER="lijingmt"  # 默认值
        fi
    fi

    # 验证 docker-compose 文件存在
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        print_error "docker-compose 文件不存在：$DOCKER_COMPOSE_FILE"
        exit 1
    fi

    print_info "使用配置："
    echo "  项目根目录：$PROJECT_ROOT"
    echo "  游戏区号：$GAME_AREA"
    echo "  分区列表：$GAME_AREAS"
    echo "  Tomcat HTTP 端口：$TOMCAT_HTTP_PORT"
    echo "  HTTP API 端口：$HTTP_API_PORT"
    echo "  地图 Worker 数量：$XIAND_MAP_WORKER_COUNT"
    echo "  Docker 镜像：${DOCKER_USER}/xiand-all:latest"
    echo ""

    # 执行步骤 - 自动化初始化和启动流程
    print_info "[1/7] 初始化游戏数据库..."
    initialize_game_database "$GAME_AREA"

    print_info "[2/7] 拉取 Docker 镜像..."
    pull_docker_images

    print_info "[3/7] 配置防火墙端口..."
    open_firewall_port "$HTTP_API_PORT"
    open_firewall_port "$TOMCAT_HTTP_PORT"
    open_firewall_port "$((TOMCAT_HTTP_PORT + 10000))"
    ensure_logrotate_policy

    print_info "[4/7] 安全停止旧容器..."
    stop_existing_container_safely

    print_info "[5/7] 准备宿主机数据与 Worker 配置..."
    prepare_game_directories "$GAME_AREA"
    prepare_data_directories
	prepare_map_worker_runtime
	recover_historical_map_worker_fallback

    # 清理已停止的相同区号容器
    if docker ps -a --filter "name=xiand-$GAME_AREA" --format "{{.Names}}" 2>/dev/null | grep -q "xiand-$GAME_AREA"; then
        docker rm -f "xiand-$GAME_AREA" 2>/dev/null || true
    fi

    print_info "[6/7] 启动统一容器 (Pike MUD + Tomcat + Workers)..."

    # 使用统一镜像
    local docker_image="${SELECTED_DOCKER_IMAGE:-${DOCKER_USER}/xiand-all:latest}"

    # 5 个 Pike Worker、协调器与 Tomcat 的生产实测会超过 6 GiB。
    # 保留足够的编译缓存与高峰余量，避免 cgroup OOM 触发持久 fallback。
    if docker run -d \
        --name "xiand-${GAME_AREA}" \
        --restart unless-stopped \
        --stop-timeout 600 \
        --memory=18g \
        --memory-swap=32g \
        --log-driver json-file \
        --log-opt max-size=50m \
        --log-opt max-file=5 \
        --ulimit stack=-1:-1 \
        --ulimit nofile=65535:65535 \
        --add-host=host.docker.internal:host-gateway \
        -p "$((TOMCAT_HTTP_PORT + 10000)):13800" \
        -p "${HTTP_API_PORT}:8888" \
        -p "${TOMCAT_HTTP_PORT}:8080" \
        -p "$((TOMCAT_HTTP_PORT + 443)):8443" \
        -e GAME_AREA="$GAME_AREA" \
        -e GAME_AREAS="$GAME_AREAS" \
        -e MYSQL_HOST="$MYSQL_HOST" \
        -e MYSQL_PORT="$MYSQL_PORT" \
        -e MYSQL_USER="$MYSQL_USER" \
        -e MYSQL_PASSWORD \
        -e XIAND_HEALTH_TOKEN \
        -e XIAND_WORKER_TOKEN \
        -e XIAND_MAP_WORKER_ENABLED \
        -e XIAND_MAP_WORKER_TRAFFIC_MODE \
        -e XIAND_MAP_WORKER_COUNT \
        -e XIAND_MAP_WORKER_CAPACITY \
        -e XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK \
        -e XIAND_GATEWAY_MAX_REQUESTS \
        -e XIAND_GATEWAY_MAX_REQUESTS_PER_WORKER \
        -v /usr/local/games/allxd/${GAME_AREA}/data_xiand:/app/xiand/data_xiand \
        -v /usr/local/games/allxd/${GAME_AREA}/etc:/app/xiand/gamelib/etc \
        -v "${SHARED_ITEM_DIR}:/app/xiand/gamelib/clone/item" \
        -v /usr/local/games/allxd/log/${GAME_AREA}:/app/xiand/log \
        -v /usr/local/games/allxd/log/${GAME_AREA}/db_log:/app/xiand/db_log \
        "${docker_image}" >/dev/null 2>&1; then
        print_success "容器已启动"
    else
        print_error "容器启动失败"
        exit 1
    fi

    verify_logical_zone_runtime_in_container "xiand-${GAME_AREA}"
    verify_map_worker_runtime_in_container "xiand-${GAME_AREA}"

    print_info "[7/7] 更新Vue前端分区配置..."
    CONTAINER_NAME="xiand-${GAME_AREA}"

    # 检查容器是否运行
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        # Vue app.js在容器内的路径（Tomcat webapps目录）
        VUE_JS_PATH="/usr/local/tomcat/webapps/ROOT/web_vue/js/app.js"

        if ! verify_hidden_mythic_assets_in_container "$CONTAINER_NAME"; then
            print_error "隐藏大神传承部署不完整，停止后续部署"
            exit 1
        fi

        # 复制本地编译的前端文件到容器（确保使用最新代码）
        print_info "复制本地编译的前端文件到容器..."
        docker cp "${PROJECT_ROOT}/web/web_vue/js/app.js" "${CONTAINER_NAME}:${VUE_JS_PATH}" 2>/dev/null || true
        docker cp "${PROJECT_ROOT}/web/web_vue/manifest.json" "${CONTAINER_NAME}:/usr/local/tomcat/webapps/ROOT/web_vue/manifest.json" 2>/dev/null || true
        docker cp "${PROJECT_ROOT}/web/web_vue/index.html" "${CONTAINER_NAME}:/usr/local/tomcat/webapps/ROOT/web_vue/index.html" 2>/dev/null || true
        print_success "前端文件已复制到容器"

        # 更新方士阵营图标和人物头像；游戏使用 /xd/images，Web 使用 /images。
        if ! copy_neutral_profession_images_to_container "$CONTAINER_NAME"; then
            print_error "中立职业图片部署失败，停止后续部署"
            exit 1
        fi

        # 创建 /tmp 目录和必要的日志文件
        docker exec "${CONTAINER_NAME}" mkdir -p /tmp 2>/dev/null || true

        # 使用sed替换分区列表
        # 替换 getDefaultPartitions 函数返回的分区列表
        docker exec "${CONTAINER_NAME}" \
            sed -i "s/defaultPartitions() {/\/* AUTO-GENERATED *\n    defaultPartitions() {/" \
            "${VUE_JS_PATH}" 2>/dev/null || true

        # 生成新的分区列表 JS 代码
        local areas_array=$(echo "$GAME_AREAS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
        local partitions_js=""
        IFS=',' read -ra AREAS <<< "$GAME_AREAS"
        for area in "${AREAS[@]}"; do
            local num="${area#xd}"
            partitions_js="${partitions_js}{ value: '${area}', label: '${num}区' },"
        done

        # 替换默认分区列表
        docker exec "${CONTAINER_NAME}" \
            sed -i "s/{ value: 'tx01', label: '原1区' },.*{ value: 'tx06', label: '原6区' }/$(echo "$partitions_js" | sed 's/&/\%26/g' | sed 's/ /\\ /g')/" \
            "${VUE_JS_PATH}" 2>/dev/null || print_warning "分区配置更新失败，使用默认配置"

        # 同时替换 API 端口
        docker exec "${CONTAINER_NAME}" \
            sed -i "s/'8888'/'${HTTP_API_PORT}'/g; s|:8888|:${HTTP_API_PORT}|g" \
            "${VUE_JS_PATH}" 2>/dev/null

        print_success "Vue前端配置已更新: 分区=$GAME_AREAS, API端口=$HTTP_API_PORT"
    else
        print_warning "容器未运行，跳过Vue配置"
    fi

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   xiand 统一容器已启动！            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "相关信息："
    echo "  容器名称：xiand-${GAME_AREA}"
    echo "  MUD 地址：localhost:$((TOMCAT_HTTP_PORT + 10000))"
    echo "  HTTP API：localhost:${HTTP_API_PORT}"
    echo "  Web 地址：http://localhost:${TOMCAT_HTTP_PORT}/"
    echo "  分区列表：$GAME_AREAS"
    echo "  数据库：${GAME_AREA}"
    echo ""
    echo "查看日志："
    echo "  docker logs -f xiand-${GAME_AREA}"
    echo ""
}

# 执行主函数；被测试脚本 source 时只加载函数，不执行部署。
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
