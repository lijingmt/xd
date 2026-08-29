#!/usr/bin/env bash
# 一键构建部署：测试 → Web导出 → 部署静态服务
# 用法:
#   ./scripts/build_and_deploy.sh          # 测试+构建+部署到8099
#   ./scripts/build_and_deploy.sh --no-test # 跳过测试（不推荐）
#   ./scripts/build_and_deploy.sh --port 9000 # 自定义端口
set -euo pipefail
cd "$(dirname "$0")/.."

PORT=8099
SKIP_TEST=0
while (( $# )); do
  case "$1" in
    --no-test) SKIP_TEST=1; shift ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "==> 仙道客户端构建部署 (端口 $PORT)"

if [[ "$SKIP_TEST" == "0" ]]; then
  echo "==> 运行前端 TestUnit..."
  ./scripts/run_frontend_tests.sh
fi

echo "==> 导出 Web 版..."
npx expo export --platform web --output-dir dist_web

echo "==> 部署到 http://0.0.0.0:$PORT ..."
if command -v lsof >/dev/null 2>&1; then
  PID=$(lsof -ti :"$PORT" 2>/dev/null || true)
  if [[ -n "$PID" ]]; then
    echo "  端口 $PORT 被占用(PID $PID)，先关闭..."
    kill "$PID" 2>/dev/null || true
    sleep 1
  fi
fi
cd dist_web
nohup python3 -m http.server "$PORT" --bind 0.0.0.0 > /tmp/xiand-client-web.log 2>&1 &
SERVER_PID=$!
sleep 1
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || echo "000")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "✗ 部署失败 (HTTP $HTTP_CODE)，查看 /tmp/xiand-client-web.log"
  exit 1
fi

LAN_IP=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1 || echo "")
echo ""
echo "✓ 构建部署完成"
echo "  本机:   http://127.0.0.1:$PORT"
if [[ -n "$LAN_IP" ]]; then
  echo "  手机:   http://$LAN_IP:$PORT"
  echo "  服务器: http://$LAN_IP:8888"
fi
echo "  PID:    $SERVER_PID"
