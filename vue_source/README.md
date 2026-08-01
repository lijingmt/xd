# Vue UI Integration - 部署说明

> 第三方前端特效库的版本、商用许可和分发义务见
> [`docs/frontend-open-source-license-memo.md`](../docs/frontend-open-source-license-memo.md)。

## 架构概览

```
┌─────────────┐      HTTP      ┌──────────────┐
│  Vue 前端   │ ──────────────> │ HTTP API    │
│  (浏览器)   │  Port 8080      │  (Pike)      │
└─────────────┘                 └──────────────┘
                                       │
                                       ▼
                                ┌──────────────┐
                                │  游戏核心     │
                                │  find_player │
                                └──────────────┘
```

## 目录结构

```
txpike9/
├── gamenv/single/daemons/
│   └── http_api.pike       # HTTP API 守护进程
├── vue_source/
│   ├── index.html          # Vue 入口
│   ├── css/app.css         # 样式
│   ├── js/app.js           # Vue 应用
│   ├── build.js            # 构建脚本
│   ├── serve.js            # 开发服务器
│   └── dist/               # 构建输出
└── pikenv/system/filter/
    └── json2026.pike       # JSON 输出过滤器 (备用)
```

## 部署步骤

### 1. 构建 Vue 前端

```bash
cd vue_source
npm install
node build.js --prod
```

### 2. 启动 HTTP API 守护进程

HTTP API 守护进程会在游戏服务器启动时自动启动，监听 8080 端口。

手动启动方式：

```pike
// 在游戏中执行
call_out(HTTP_API_D->start_server, 0);
```

检查状态：

```pike
HTTP_API_D->query_status()
```

### 3. 访问 Vue 界面

在生产环境中，访问：

```
http://your-server:8080/
```

开发环境可使用代理服务器：

```bash
cd vue_source
npm run dev
# 访问 http://localhost:3000
```

## API 接口

### /api

执行游戏命令

**参数:**
- `txd` - 加密的认证信息 (userid~password)
- `cmd` - 要执行的命令 (默认: "look")

**响应:**

```json
{
  "timestamp": 1737628800,
  "messages": [
    {
      "type": "info",
      "text": "你来到了北京城",
      "timestamp": 1737628800
    }
  ],
  "actions": [
    {
      "label": "任务",
      "command": "quest",
      "style": "success"
    }
  ],
  "navigation": {
    "exits": [
      {
        "direction": "east",
        "label": "东",
        "command": "east"
      }
    ],
    "currentRoom": {
      "name": "北京城",
      "id": "beijing_city"
    }
  },
  "player": {
    "id": "player001",
    "name": "张三",
    "level": 45,
    "hp": 1500,
    "hpMax": 2000,
    "hpPercent": 75.0,
    "mp": 800,
    "mpMax": 1000,
    "mpPercent": 80.0,
    "vip": {
      "level": 8
    },
    "money": 1500000,
    "exp": 75850
  }
}
```

### /health

健康检查

**响应:**

```json
{
  "status": "ok",
  "time": 1737628800,
  "port": 8080
}
```

## TXD 加密说明

TXD 是用户凭证的加密格式：`userid~password`

加密规则：

**userid:**
- 偶数位字符: ASCII + 2 (121 → %7B)
- 奇数位字符: ASCII + 1 (122 → %7B)

**password:**
- 偶数位字符: ASCII + 1 (122 → %7B)
- 奇数位字符: ASCII + 2 (121 → %7B, 122 → %7C)

前端 `encodeTxd()` 函数已实现此加密。

## 开发调试

### 开发模式

```bash
cd vue_source
npm run dev
```

开发服务器会：
- 启动在 3000 端口
- 自动代理 /api 请求到 8080 端口
- 支持热重载

### 生产构建

```bash
cd vue_source
node build.js --prod
```

构建产物在 `dist/` 目录。

## 测试

### 测试 API 连接

```bash
curl http://localhost:8080/health
```

### 测试游戏命令

```bash
# 需要先有玩家登录游戏
curl "http://localhost:8080/api?txd=YOUR_ENCODED_TXD&cmd=look"
```

## 故障排查

### HTTP API 未启动

```pike
// 在游戏中检查
HTTP_API_D->query_status()
// 应返回: (["running": 1, "port": 8080])
```

### 玩家未登录

前端会显示 "玩家未登录" 错误。确保玩家已通过 WAP/网页端登录。

### CORS 错误

HTTP API 已配置 CORS 头，允许所有来源访问。

## 后续扩展

1. **WebSocket 支持** - 实现实时推送
2. **增量更新** - 减少传输量
3. **离线缓存** - PWA 支持
4. **多语言** - i18n 支持
