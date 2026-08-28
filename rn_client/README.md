# 仙道原生客户端（rn_client）

像 txpike9 一样的**原生渲染**客户端（React Native + Expo，非 WebView 壳），
直接消费仙道 HTTP API（/api/json、/api/status、/api/battle_status、/api/autofight）。

## 目录

```
rn_client/
├── app.js                     # 根组件：登录 ⇄ 游戏
├── index.js                   # Expo 入口
├── src/api/mudApi.js          # API层（fetch可注入，供测试）
├── src/store/useGameStore.js  # zustand 全局状态
├── src/utils/segments.js      # MUD 行/段落渲染纯函数（颜色/按钮/输入）
├── src/components/            # LoginScreen / GameScreen
└── test/                      # 前端 TestUnit（见下）
```

## 测试策略（硬规则）

**任何前端修改都必须通过前端 TestUnit：**

```bash
cd rn_client && ./scripts/run_frontend_tests.sh
# 或 npm test（仅离线）/ npm run test:live（含在线冒烟）
```

- `test/run_tests.mjs`：离线单测（node 零依赖）——URL构造、txd轮换、错误转换、
  颜色/按钮/输入渲染纯函数、store 登录/命令/战斗判定/行数截断。
- `test/smoke_live.mjs`：在线冒烟（需本地服 8888）——真实注册临时账号→
  init登录→look→status→battle_status→autofight 全链路。

## 构建管线（按用户既定流程）

1. **Web 版先行**：`npm run web` → `dist_web/`（python3 -m http.server 即可测试）
2. 验证无误后再打包原生：
   - iOS：`npm run ios`（需 Xcode；后续接 ios-local-build 流程）
   - Android APK：`npm run android`

## 服务器契约备注

- 登录：`GET /api/json?userid=<区+账号>&password=<明文>&cmd=init`
- 账号中心：`POST /api/account/login|characters|characters/select`（JSON，令牌只在请求体）
- 注册：`GET /api/html?cmd=login_regnew gamelib <区+账号> <密码> <会话> <challenge>`（用户名≤12字符，不含区号）
- 挂机：`POST /api/autofight`（表单 txd/action=toggle|on|off）——只支持 POST
- 战斗判定：响应行含 [察看战况] 按钮即在战斗中（与 Vue 端一致）

## 路线图

- [x] v0.1 骨架：登录/场景渲染/命令/战斗条/挂机开关 + 双层TestUnit + Web导出
- [x] v0.2 多角色账号中心 + 角色仪表盘（账号登录/角色列表/选角进游；账号服务异常自动回退单人物直登）
- [ ] v0.3 推送（APNs：神太古掉落/邀请）、桌面 Widget、建角流程
- [ ] v0.4 IAP（沿用挂机精灵合规策略：iOS 内购、外部支付不出现在端内）
- [ ] v1.0 App Store 送审（原生价值层齐全后）
