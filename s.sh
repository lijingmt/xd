#!/usr/bin/env bash
# 205 一键启动：合并区 xd01-02 · 10 workers · active 流量模式
# （内部走 restart-all-docker.sh，区号/端口已固化：Tomcat 2002 / API 2003）
set -euo pipefail
cd "$(dirname "$0")"

# 205 root 的 docker context 曾残留 desktop-linux，默认回退 default。
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-default}"

exec ./restart-all-docker.sh --workers 10 --force-active
