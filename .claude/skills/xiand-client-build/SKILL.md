---
name: xiand-client-build
description: 仙道原生客户端(rn_client)的开发流程、测试门禁、iOS/Android 打包发布全链路与踩坑速查。用户提到客户端、rn_client、打包、出包、上架、TestFlight、Google Play、模拟器、客户端 bug 时使用。
---

# 仙道客户端开发 / 打包 / 发布流程

## 架构速览

- `rn_client/`：Expo 54 + RN 0.81（iOS/Android/Web 三端），Zustand 状态管理。
- **store 层零 react-native 依赖**（`useGameStore.js` 不 import react-native），
  离线 TestUnit 可直接加载。本地持久化一律走"可注入后端"模式：
  `utils/sessionStore.js`、`utils/suiyuLog.js`、`utils/savedAccounts.js`
  都有 `setStorageBackend()`，测试注入内存 Map，运行时动态 import AsyncStorage。
- 纯函数放 `utils/`（正则解析、数值格式化、目标判定），组件放 `components/`，
  全部有 `test/run_tests.mjs` 覆盖。
- 服务端接口在 `gamelib/single/daemons/http_api_daemon.pike` +
  `_http_api_mod/*.pike`（如 `/api/equipment_panel`、`/api/account/*`、
  `/api/iap_verify`）。

## 开发验证门禁（改客户端必跑）

```bash
cd rn_client
node test/run_tests.mjs                      # 前端 TestUnit，必须 0 失败
npx expo export --platform web --clear \
  --output-dir /tmp/xiand-web-check          # 编译打包检查
```

改了服务端 Pike：另跑完整 `./restart.sh`（Vue 构建 + 全量 TestUnit 131+
+ 多 worker 拓扑重启），看 `[TESTUNITD] COMPLETE failed=0`。

## 版本号与打包

版本三处同步改（iOS 两处 + Android 一处）：

1. `rn_client/app.json`：`version`、`ios.buildNumber`、`android.versionCode`
2. `ios/app.xcodeproj/project.pbxproj`：`CURRENT_PROJECT_VERSION`（2 处）、
   `MARKETING_VERSION`（2 处）
3. `android/app/build.gradle`：`versionCode`、`versionName`

> `ios/`、`android/` 目录被 .gitignore（prebuild 生成），原生侧改动只存在
> 本机；可持久化的配置写进 `app.json` plugins（如 expo-build-properties）。

### iOS（Cocobuy Online LLC / JDNC3D9869 / com.wapmud.xiandao）

```bash
cd rn_client
xcodebuild -workspace ios/app.xcworkspace -scheme app -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/build/app.xcarchive archive
xcodebuild -exportArchive -archivePath /tmp/build/app.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath /tmp/build/ipa
open -a Transporter /tmp/build/ipa/app.ipa   # 用户点"提交"上传 App Store Connect
```

- **build number 不能重复上传**：每次重传（即使同版本）必须递增 buildNumber，
  否则 ASC 报 "The provided entity includes an attribute..."。
- Transporter 队列里的旧包要先删掉再传新包。
- IAP 只有 iOS 有；充值入口 iOS 才显示（`Platform.OS === 'ios'`）。

### Android（com.wapmud.xiandao / release.keystore alias xiandao）

```bash
cd rn_client/android
./gradlew bundleRelease assembleRelease
# AAB: app/build/outputs/bundle/release/app-release.aab  (Google Play 用)
# APK: app/build/outputs/apk/release/app-release.apk     (官网直装用)
```

- **R8 混淆 + 资源压缩永久开启**（用户已拍板）。配置双保险：
  `app.json` expo-build-properties `{android:{minifyEnabled:true,
  shrinkResources:true}}` + `android/gradle.properties` 两个 enable 开关。
- 首次 R8 缺类报错看 `app/build/outputs/mapping/release/missing_rules.txt`，
  把生成的 `-dontwarn` 追加进 `android/app/proguard-rules.pro`
  （已有：`-dontwarn expo.modules.kotlin.runtime.MainRuntime`，expo-webview 反射引用）。
- `mapping.txt` 由 AGP 自动嵌入 AAB，Play 反混淆警告随之消失；副本随包存档。

### 出包冒烟（Android，防 R8 运行时崩）

本机是 M3 Max 但 shell 是 Rosetta，模拟器全部命令要 `arch -arm64` 前缀，
AVD `Pixel_6` 需 arm64 字段（`abi.type=arm64-v8a`、`hw.cpu.arch=arm64`、
`image.sysdir.1=system-images/android-34/google_apis/arm64-v8a/`）：

```bash
arch -arm64 ~/Library/Android/sdk/emulator/emulator -avd Pixel_6 \
  -no-window -no-audio -gpu swiftshader_indirect &   # 等 Boot completed
arch -arm64 adb install -r android/app/build/outputs/apk/release/app-release.apk
arch -arm64 adb shell am start -n com.wapmud.xiandao/.MainActivity
arch -arm64 adb logcat -d | grep -E "FATAL|AndroidRuntime"   # 应为空
arch -arm64 adb exec-out screencap -p > /tmp/smoke.png       # 肉眼确认登录页
```

## 分发

| 产物 | 去处 |
|---|---|
| IPA | Transporter → App Store Connect → TestFlight/提审 |
| AAB | Google Play Console 上传 |
| APK | `scp` 覆盖 `root@192.168.1.205:/usr/local/tomcat/webapps/gamehome/xiandao.apk`，固定下载页 `https://www.wapmud.com/gamehome/xiandao.apk`（MD5 校验 + curl 200 验证） |
| 归档 | `~/Documents/xiandao/xiand-<ver>-android-vN.aab/.apk`、`xiand-<ver>-ios-build<N>.ipa`、`-mapping.txt` |

## 环境 / 服务器

- 客户端默认连生产 WAN `https://xd01-02.wapmud.com`；登录页可切
  内网 `http://192.168.1.234:8888`（本机开发服，同一 WiFi）。
- **账号数据按服务器独立**：账号中心注册的账号/新角色只在注册的那台服上存在。
  客户端登录是"账号中心优先，失败回退旧版单角色直登"；回退时游戏能玩但
  多开/角色条/账号功能全无——现在回退会在进游首屏显示原因提示。
  排查"某端没有多开"先确认：登录页服务器地址 → 该服有没有这个账号 →
  ☰菜单"多开角色"是否正常。
- 205 部署 = 本地 `rebuild-image.sh`（构建镜像推 Docker Hub）→ 205
  `restart-all-docker.sh`（拉镜像重启容器）；客户端功能依赖的服务端改动
  必须部署到 205 后生产才生效。
- 本地多 worker 开发服重启：`./restart.sh`（Vue 构建→TestUnit→停旧拓扑→
  起新拓扑，全程约 5-8 分钟）。**必须 nohup 脱离终端跑**，否则会话结束会把
  screen 会话连带杀掉（服务器起完又被停）。

## 踩坑速查（真实事故）

- **RN fetch + AbortController**：响应体会变 undefined。一律不用 signal，
  用 `text()+JSON.parse` 手工解析并抛带上下文的错误。
- **乱码毁 JSON**：旧存档字段里的坏 UTF-8 会让 Hermes 严格解析整包失败
  （网页端宽容），表现为"状态暂无内容"。服务端三层清洗 + JSON 编码终检。
- **普通 `View` 塞 Animated 值**：`Transform with key of "scale" must be a
  number` 运行时崩——动画元素必须 `Animated.View`。
- **Pike 9 无 `string_width`**：用 `foreach(values(data), int v)` 扫 >0xFF。
- **iOS 版本号冲突 / Transporter 旧包**：见上文打包节。
- **后台任务跑 restart.sh**：任务结束杀进程树（含 screen），用 nohup。
- **客户端零安卓分支**：两端同一 JS；出现"单端差异"先查连接的服务器、
  账号模式（token 有无）、会话恢复路径，再怀疑平台。

## 发布前检查单

1. `node test/run_tests.mjs` 0 失败；`expo export --platform web` 通过。
2. 服务端有改动则 `./restart.sh` 全绿 + 本地 HTTP health 200。
3. 版本三处同步；iOS archive/export 成功；Android R8 构建成功。
4. Android 模拟器冒烟：启动、登录页渲染、logcat 无 FATAL。
5. APK 上 205 后 MD5 双端一致 + 固定 URL HTTP 200。
6. git 提交（英文规范）+ push；staged 只含任务文件，不含
   data_xiand/运行数据/dist 生成物。
