# 仙道原生客户端（rn_client）

像 txpike9 一样的**原生渲染**客户端（React Native + Expo，非 WebView 壳），
直接消费仙道 HTTP API（/api/json、/api/status、/api/battle_status、/api/autofight、
/api/autofight_view、/api/equipment_panel、/api/account/*）。

## 已完成功能

### 核心链路
- **登录**：分区选择 + 账号密码 → 账号令牌 → 角色仪表盘 → 选角进游
- **多角色**：账号中心列出全部角色（永恒服/幻境标记），点卡片即入
- **建角**：种族 → 职业（隐藏职业按解锁+幻境门禁）→ 性别 → 名字 → 头像
- **会话保持**：令牌/账号/服务器地址 AsyncStorage 持久化，重开免登录

### 游戏画面
- **MUD 原生渲染**：彩色文本（§ 颜色码 + 遗留 HTML div/font/br）、按钮、输入框、图片
- **Header**：头像 + 宠物徽章 + 名字 + Lv/职业徽章 + 三条属性条（生命/法力/精力）+ 横跨经验条 + Buff 药丸
- **战斗场景**：左右对峙布局（玩家+宠物 VS 敌人），Animated 血条平滑过渡、低血量红光、伤害闪红/治疗闪绿
- **浮动战斗数字**：伤害（暴击金色放大）、治疗、闪避/格挡/中毒标记、胜利横幅、技能名
- **底部六 Tab**：场景 / 状态 / 物品 / 技能 / 装备 / 更多（14 个常用功能）
- **装备面板**：14 槽位结构化卡片，稀有度染色，一键穿卸，候选装备快速切换

### 挂机系统
- **flushview 轮询**：txpike9 同款 `cmd=flushview&platform=ios`，战斗 1s / 待机 3s 自适应
- **AppState 恢复**：iOS 切后台回前台立即补一帧
- **401 智能恢复**：先尝试重选角色，账号令牌也失效才登出
- **乐观反馈**：点挂机按钮立即变色+转圈，失败回滚+错误提示

### 稳定性
- 图片走 Tomcat 8080（非 API 8888），失败显示占位方块
- 纯数字单字符垃圾行（服务端拼接残留的"0"）自动过滤
- FlatList 内容哈希 key（全量替换时不重渲染 400 行）
- 智能滚动（只在底部附近才跟随新行，阅读历史不被打断）

## 目录

```
rn_client/
├── app.js                        # 根组件：SafeArea + 登录⇄游戏路由
├── index.js                      # Expo 入口
├── src/
│   ├── api/
│   │   ├── mudApi.js             # 核心 API（fetch 可注入）
│   │   ├── accountApi.js         # 多角色账号 API
│   │   └── equipmentApi.js       # 装备面板 API
│   ├── store/useGameStore.js     # zustand 全局状态
│   ├── utils/
│   │   ├── segments.js           # MUD 行渲染纯函数（颜色/HTML/按钮/key）
│   │   ├── battleFeedback.js     # 战斗文案→浮动数字/状态事件
│   │   └── sessionStore.js       # 会话持久化（存储后端可注入）
│   ├── data/characterOptions.js  # 建角选项（种族/职业/头像）
│   └── components/
│       ├── LoginScreen.js        # 登录（品牌/分区/表单）
│       ├── CharacterScreen.js    # 角色仪表盘
│       ├── CharacterCreateModal.js # 建角弹层
│       ├── GameScreen.js         # 主游戏屏（Header/Feed/Tab/命令栏）
│       ├── BattleScene.js        # 战斗对峙场景（Animated HP）
│       ├── EquipmentPanel.js     # 装备面板
│       └── GameSmartImage.js     # 图片加载+失败占位
└── test/
    ├── run_tests.mjs             # 离线单测（node 零依赖，52 项）
    └── smoke_live.mjs            # 在线冒烟（注册→登录→建角→战斗→挂机→装备）
```

## 测试策略（硬规则）

**任何前端修改都必须通过前端 TestUnit：**

```bash
cd rn_client && ./scripts/run_frontend_tests.sh
# 或 npm test（仅离线）/ npm run test:live（含在线冒烟）
```

- `run_tests.mjs`：52 项离线单测——URL构造、txd轮换、错误转换、§颜色码、
  遗留HTML解析、颜色嵌套、按钮样式、图片地址（Tomcat端口）、行key、
  垃圾行过滤、战斗事件解析、角色卡归一化、账号API形状、store全流程、
  会话持久化、装备面板归一化。
- `smoke_live.mjs`：14 步在线冒烟——注册→账号登录→角色列表→游戏内建角引导
  （纯按钮驱动）→flushview→status→battle→autofight→装备面板。

## 构建管线

1. **Web 版先行**：`npm run web` → `dist_web/`
   ```bash
   cd dist_web && python3 -m http.server 8099 --bind 0.0.0.0
   # 手机同WiFi: http://<Mac IP>:8099，服务器栏填 http://<Mac IP>:8888
   ```
2. 原生打包（Web 验收后）：
   - iOS：`npm run ios`（需 Xcode）
   - Android APK：`npm run android`

## 服务器契约备注

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/challenge` | GET | 注册时获取挑战码 |
| `/api/json?userid=&password=&cmd=init` | GET | 直连登录（回退路径） |
| `/api/json?txd=&cmd=<cmd>` | GET | 游戏命令（含 flushview） |
| `/api/status?txd=` | GET | 玩家状态轮询 |
| `/api/battle_status?txd=` | GET | 战斗状态 |
| `/api/autofight` | POST | 挂机开关（表单 txd/action） |
| `/api/autofight_view?txd=&after=&generation=` | GET | 挂机画面增量（备用通道） |
| `/api/equipment_panel?txd=` | GET | 装备面板结构化数据 |
| `/api/account/login` | POST JSON | 账号登录→令牌+角色清单 |
| `/api/account/characters` | POST JSON | 刷新角色列表 |
| `/api/account/characters/select` | POST JSON | 选角→bootstrap txd |
| `/api/account/characters/create` | POST JSON | 建角 |
| `/api/html?cmd=login_regnew...` | GET | 注册（免认证通道） |

**图片在 Tomcat(8080)不在 API(8888)**——`getImageBase(apiBase)` 推导。

## 路线图

- [x] v0.1 骨架 + Web 导出 + 双层 TestUnit
- [x] v0.2 多角色账号中心 + 角色仪表盘 + 建角 + 会话保持
- [x] v0.3 品质打磨：Header/Tab/战斗场景/浮动数字/装备面板/HTML渲染/图片修复/挂机优化
- [ ] v0.4 推送（APNs：神太古掉落/邀请）——需 Apple 开发者证书
- [ ] v0.5 IAP（沿用挂机精灵合规策略）——需 App Store Connect 配置
- [ ] v1.0 App Store 送审
