# 仙道 Xiand — 开源说明书

> 东方幻想多职业文字 MUD：Pike 9 后端 + Vue 3 网页 + React Native 手机客户端，多 Worker 横向扩展。

## 快速开始

### 环境要求

| 组件 | 版本 | 说明 |
|---|---|---|
| Pike | 9.0.x | 引擎运行时（本仓库自带 `lowlib/` 标准库） |
| MySQL | 5.7+ | 可选（排行榜/帮派持久化，见 `docs/MYSQL_SETUP.md`） |
| Node.js | 18+ | 前端构建（Vue + RN 客户端） |
| Docker | 20+ | 生产部署（推荐） |

### 本地启动（单进程 + TestUnit）

```bash
git clone <repo> && cd xiand
./scripts/restart_with_testunit.sh
# 自动：拉起 Pike → 执行全部 TestUnit → 报告 146 通过/0 失败
# 完成后游戏在 127.0.0.1:8888（HTTP）、127.0.0.1:13800（MUD）运行
```

### 本地启动（多 Worker 集群）

```bash
./scripts/restart_map_workers_with_testunit.sh
# 1 个协调器 + N 个地图 Worker + TestUnit 全量回归
```

### Docker 生产启动（runboot）

```bash
docker compose -f docker/docker-compose.yml up -d
# 容器入口是 docker/start-unified.sh（"runboot"）：
#   1. 启动 Tomcat（静态资源/JSP 兼容层）
#   2. 拉起多 Worker 集群（scripts/map_worker_cluster.sh apply）
#   3. 等待 HTTP 健康端点就绪（最长 1200 秒冷编译窗口）
#   4. 进入监督者循环：
#      - 健康探针每 5 秒检查协调器状态
#      - 软故障（在线快照未就位）需持续 600 秒才升级
#      - 硬故障 3 连击 → 安全停机 → 整轮重启（保留存档屏障）
#      - 冷启动稳定窗口 900 秒内不判定不健康
```

环境变量可覆盖：`XIAND_MAP_WORKER_CONFIG`、`XIAND_MAP_WORKER_STARTUP_STABILIZATION_SECONDS`、`XIAND_ACTIVE_START_ATTEMPTS` 等，见 `docker/start-unified.sh` 头部注释。

## 目录结构

```
xiand/
├── lowlib/              Pike 标准库（driver、user、item 继承链）
│   └── driver.pike      引擎入口（-p 13800 启动）
├── gamelib/
│   ├── cmds/            玩家/管理命令（refine、pet、timed_event 等）
│   ├── clone/           物品/NPC/房间克隆模板
│   ├── inherit/         NPC、装备、书本继承层
│   ├── single/daemons/  守护进程（autofightd、itemsd、refined、
│   │                    pike_gateway、map_worker_rpc 等）
│   └── etc/             配置（timed_events.json、app_version.conf）
├── vue_source/          Vue 3 前端源码（构建后输出 web/web_vue/）
├── rn_client/           React Native 手机客户端（iOS + Android）
├── docker/              Dockerfile.all + docker-compose.yml + runboot
├── scripts/
│   ├── restart_with_testunit.sh       单进程 + 测试门禁
│   ├── restart_map_workers_with_testunit.sh  集群 + 测试门禁
│   ├── map_worker_cluster.sh         Worker 生命周期管理
│   └── build/build_vue_frontend.sh  Vue 构建脚本
├── test_unit/           全部回归测试（当前 147 个）
├── data_xiand/          运行时数据（玩家存档、集群状态——不入库）
└── docs/                架构文档 + 专题设计文档
```

## 核心架构文档

| 文档 | 内容 |
|---|---|
| [docs/map-worker-architecture.md](map-worker-architecture.md) | 多 Worker 拓扑、路由、反克隆栅栏、故障恢复 |
| [docs/new-moon-multi-worker-architecture.zh-CN.md](new-moon-multi-worker-architecture.zh-CN.md) | 新月套装体系与多 Worker 的交互 |
| [docs/illusion-realm-s1.md](illusion-realm-s1.md) | 幻境赛季（S1）设计：81 章剧情、反克隆、结算 |
| [docs/frontend-open-source-license-memo.md](frontend-open-source-license-memo.md) | 前端依赖许可证合规 |
| [docs/MYSQL_SETUP.md](MYSQL_SETUP.md) | MySQL 配置 |

## 近期新增系统（2026-08~09）

### 提炼系统（gamelib/single/daemons/refined.pike + cmds/refine.pike）

装备 +1 级全属性 +1%。淬炼石由 PVP 击杀随机掉落（40%×1-3 颗、日上限 200、五条防刷规则）。离火玉 1:1 碎玉购买。950 级后每 50 级设门槛：失败降级而非清零，保底回到本段起点。月度 PK 榜 + 捐赠月榜跨 Worker 合并，榜首获守护符。套装共鸣：穿戴同系列≥5 件+5%、≥8 件+10% 提炼加成。

### 服务端自动挂机（gamelib/single/daemons/autofightd.pike）

浏览器/客户端只读画面，战斗在服务端 tick 驱动。全局单调度器按世界队列压力分级派发（正常 16/秒 → 严重 4/秒）。额度自停后 6 小时会话保活（防空闲清理误踢）。溢出分流房：公共房满员时克隆独立无出口副本，闲置 10 分钟回收。3 万行守护进程覆盖：智能技能队列、自动嗑药、自动清包、套装回收、定向快照自愈。

### 在线快照自愈（_http_api_mod/pike_gateway.pike）

2026-09-10 两次全集群重启的根因修复：活玩家路由分歧（`online_route_mismatch`）持续 600 秒触发全服强停。现在同一玩家毒化快照 120 秒即定向 `local_discard`（踢一人重登），不升级为集群重启。校验失败日志带 `user_ref` + 路由详情，可定位肇事者。

### 限时活动（_timed_event_mod/）

每日 20:00 天衡绝境（PVP 镜域）与 21:00 九曜镇渊（PVE 九宫）。经验按升级所需百分比结算（参与 3%~冠军 15%，封顶角色折算双倍令牌）。名次奖励带淬炼石。天衡令/九曜令可兑换补给与锻造材料。时钟注入测试钩子支持确定性全流程回归。

### 幻境赛季（seasonal_chard.pike + illusion_journeyd.pike）

81 章九卷剧情 + 确定性支线 + 三条路线（寻星/破阵/同心）。反克隆不变量：结算只改账号索引 `illusion→eternal`，绝不复制存档。跨 Worker 状态文件用 PID 后缀临时文件 + mkdir 锁 + 月份感知合并。

### 手机客户端（rn_client/）

React Native + Expo。并行多角色（本地可调上限 10-50）、一键登录全部角色并开挂机、聊天室、装备纸娃娃、世界地图、版本更新提示、用户服务协议门禁、充值引导。构建见 `docs/` 内打包相关文档。

## 测试门禁

```bash
./scripts/restart_with_testunit.sh
# 期望输出：
# [restart] TestUnit passed: [TESTUNITD] COMPLETE passed=147 failed=0 skipped=4
```

**任何改动必须过此门禁才能推送。** 测试发现编译错误、数值回归、存档不守恒等问题。已有 147 个测试文件覆盖：提炼公式边界、幻境全职业全流程、限时活动报名→结算、快照自愈、多 Worker 事务锁、XSS 防护等。

## 许可证

见 [LICENSE.zh.md](../LICENSE.zh.md)。前端依赖许可证合规见专项备忘录。

---

克隆后遇到问题？QQ 群 610653957 · 电报 https://t.me/wapmud

**English version: [README.en.md](README.en.md)** — the same guide in English for international players and contributors.
