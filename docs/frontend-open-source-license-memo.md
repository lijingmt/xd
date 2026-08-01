# Xiand 前端开源库商用许可备忘录

更新日期：2026-08-01

## 结论

本次新增的四个前端库均采用宽松开源许可证，可以免费用于 Xiand 的商业运营、收费游戏、容器镜像和网页分发。它们不要求公开 Xiand 的游戏源码，也没有按用户数、收入或部署数量收费的条款。

工程侧需要持续履行的义务是：分发这些库或其重要部分时，保留对应的版权声明和许可证文本。当前构建流水线已经自动完成许可证复制。

## 已批准使用的版本

| 软件包 | 固定版本 | 许可证 | 免费商用 | 修改与分发 | 要求公开Xiand源码 |
|---|---:|---|---|---|---|
| [`canvas-confetti`](https://github.com/catdad/canvas-confetti) | `1.9.4` | ISC | 是 | 允许 | 否 |
| [`howler`](https://github.com/goldfire/howler.js) | `2.2.4` | MIT | 是 | 允许 | 否 |
| [`@formkit/auto-animate`](https://github.com/formkit/auto-animate) | `0.10.0` | MIT | 是 | 允许 | 否 |
| [`driver.js`](https://github.com/kamranahmedse/driver.js) | `1.8.0` | MIT | 是 | 允许 | 否 |

## 许可证含义

### ISC

ISC 与 MIT 的实际使用范围非常接近，允许为任何目的免费使用、复制、修改和分发，包括商业用途。分发时必须保留原作者版权声明和许可声明。

### MIT

MIT 允许免费使用、复制、修改、合并、发布、分发、再许可和销售软件副本。分发软件或其重要部分时必须保留版权声明和许可声明。

四个许可证都包含常见的“按现状提供”免责条款：原作者不为软件提供担保，也不承担使用产生的损失责任。

## 项目中的许可证位置

依赖安装后的原始许可证：

- `vue_source/node_modules/canvas-confetti/LICENSE`
- `vue_source/node_modules/howler/LICENSE.md`
- `vue_source/node_modules/@formkit/auto-animate/LICENSE`
- `vue_source/node_modules/driver.js/license`

正式前端构建产物：

- `web/web_vue/vendor/CANVAS_CONFETTI_LICENSE.txt`
- `web/web_vue/vendor/HOWLER_LICENSE.txt`
- `web/web_vue/vendor/AUTO_ANIMATE_LICENSE.txt`
- `web/web_vue/vendor/DRIVER_LICENSE.txt`

`vue_source/build.js` 和 `scripts/build/build_vue_frontend.sh` 会检查并复制上述运行库及许可证；缺失时构建失败，避免发布时遗漏声明。

## 素材授权边界

这份结论只覆盖上述四个软件包本身。以后新增的音乐、配音、字体、图片、Lottie动画或其他素材必须单独核对授权，不能因为渲染它们的软件包是开源的，就推定素材本身也可以商用。

当前新增的游戏提示音由 Xiand 前端代码在浏览器中实时合成，没有引用第三方音乐或音效文件，因此不存在额外的第三方音频素材许可。

## 升级规则

以上结论对应表格中的固定版本。未来升级主版本、替换上游仓库或引入插件时，应重新检查：

1. `package.json` 中声明的许可证是否变化；
2. npm 包内实际许可证文本是否变化；
3. 是否新增商业插件、付费功能或第三方素材；
4. 构建产物是否仍包含全部许可证文件；
5. `npm audit` 是否保持无已知安全告警。

本文件是工程许可备忘，不替代针对特殊发行渠道或重大商业交易的正式法律意见。
