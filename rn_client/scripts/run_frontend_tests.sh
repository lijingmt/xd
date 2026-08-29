#!/usr/bin/env bash
# 前端 TestUnit 统一入口：任何 rn_client/ 下的修改都必须跑通本脚本。
#   离线单测：永远执行（node，零网络依赖）。
#   在线冒烟：本地游戏服(默认127.0.0.1:8888)在线时自动执行。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 前端离线单元测试"
node test/run_tests.mjs

HOST="${XIAND_SMOKE_HOST:-http://127.0.0.1:8888}"
if curl -sf "${HOST}/health" >/dev/null 2>&1; then
  echo "==> 检测到本地游戏服，执行在线冒烟 (${HOST})"
  node test/smoke_live.mjs
else
  echo "==> 本地游戏服未启动，跳过在线冒烟（离线单测已覆盖）"
fi

echo "==> 前端 TestUnit 全部通过"
