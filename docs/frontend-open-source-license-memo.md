# Xiand 前端开源依赖商业使用许可备忘录

更新日期：2026-08-02

## 结论

Xiand 当前 Vue 前端的 5 个直接运行依赖均采用宽松开源许可证，可以免费用于 Xiand 的商业运营，也不要求公开 Xiand 的源代码：

| 依赖 | 锁定版本 | 许可证 | 免费商用 | 修改与再发布 | 要求公开 Xiand 源码 |
| --- | --- | --- | --- | --- | --- |
| Vue | `3.5.40` | MIT | 是 | 允许 | 否 |
| canvas-confetti | `1.9.4` | ISC | 是 | 允许 | 否 |
| howler | `2.2.4` | MIT | 是 | 允许 | 否 |
| @formkit/auto-animate | `0.10.0` | MIT | 是 | 允许 | 否 |
| driver.js | `1.8.0` | MIT | 是 | 允许 | 否 |

商业发布时必须保留适用的版权声明、许可证文本及 NOTICE 文件。依赖本身免费商用，不等于其演示图片、字体、音频、视频、图标、模型或其他素材也自动获得相同授权；素材必须单独审查。

## 本次依赖变更记录

- `74b3dc4bc8`（2026-08-01，`build: harden frontend dependencies`）：Vue 实际锁定版本从 3.5.27 升级到 3.5.40，依赖声明改为精确版本，并移除未使用的 `http-server`。
- `62b92bbc2d`（2026-08-01，`feat: add progressive frontend effects`）：加入 canvas-confetti、howler、@formkit/auto-animate 和 driver.js。

当前 `package-lock.json` 内所有 27 个有许可证元数据的包均属于宽松许可：MIT 23 个、ISC 2 个、BSD-2-Clause 1 个、BSD-3-Clause 1 个。2026-08-02 执行 `npm audit --omit=dev`，已知漏洞总数为 0。

安全漏洞审计和许可证审计是两件不同的事，两者都必须通过。

## 许可证义务摘要

- MIT、ISC、BSD-2-Clause、BSD-3-Clause、0BSD、Zlib：允许商业使用、修改和再发布；发布时按许可证要求保留版权与许可文本。
- Apache-2.0：允许商业使用、修改和再发布；除许可证文本外，还必须保留适用的 NOTICE，并遵守其专利及变更声明条款。
- 上述许可不会要求 Xiand 因使用这些库而公开自身源代码，也不收取运行次数或销售额授权费。

这份备忘录是工程合规记录，不替代针对特殊商业安排的正式法律意见。

## 新依赖准入规则

今后新增、升级、内嵌或分发任何前端库前，必须同时满足以下条件：

1. 对应精确版本具有可追溯的公开源码或官方发布物。
2. `package.json` 使用精确版本，不使用 `^`、`~`、`*`、Git 分支或未固定 URL；`package-lock.json` 必须同步。
3. npm 元数据、实际安装包中的 LICENSE/COPYING 文件和官方仓库对应版本的许可信息一致。不能只参考 README 徽章。
4. 许可证属于经审查可接受的宽松范围：MIT、ISC、BSD-2-Clause、BSD-3-Clause、Apache-2.0、0BSD 或 Zlib。
5. 所有直接和传递依赖均通过同样的许可证检查，所需版权、LICENSE 和 NOTICE 可以随产品保留。
6. 安全审计、构建和现有前端测试全部通过。
7. 更新本备忘录，记录包名、精确版本、许可证、来源、用途和应履行义务。

下列情况默认禁止引入，除非另行完成法律审核并得到明确批准：

- GPL、AGPL、LGPL、MPL、EPL、CDDL 等 copyleft 或弱 copyleft 许可证；
- SSPL、BSL、PolyForm、Commons Clause 等 source-available 或带商业限制的条款；
- 非商业、禁止演绎、禁止再分发、用途限制、用户数量限制或收费条件；
- 自定义许可证、没有许可证、许可证字段与 LICENSE 文件冲突、无法确认精确版本；
- 多许可证表达式但未明确记录本项目选择哪一套许可及其义务。

宽松许可证在上面的准入名单中只表示“可以进入工程审查”，不代表可以忽略其署名、NOTICE、专利或再发布义务。依赖每次升级都要重新审查，因为新版本可能变更许可证或传递依赖。

## 构建与发布中的许可证保留

源码安装目录内的许可证文件：

- `vue_source/node_modules/vue/LICENSE`
- `vue_source/node_modules/canvas-confetti/LICENSE`
- `vue_source/node_modules/howler/LICENSE.md`
- `vue_source/node_modules/@formkit/auto-animate/LICENSE`
- `vue_source/node_modules/driver.js/license`

前端构建会把许可证复制到发布目录 `web/web_vue/vendor/`：

- `VUE_LICENSE.txt`
- `CANVAS_CONFETTI_LICENSE.txt`
- `HOWLER_LICENSE.txt`
- `AUTO_ANIMATE_LICENSE.txt`
- `DRIVER_LICENSE.txt`

`vue_source/build.js`、开发服务脚本和共享构建流程都应继续校验这些文件存在。以后新增依赖时，除了通过许可证审计，还要把相应 LICENSE/NOTICE 纳入构建产物。

## 自动化门禁

仓库内的 [frontend-permissive-license Skill](../.claude/skills/frontend-permissive-license/SKILL.md) 定义了完整审查工作流。可以运行：

```bash
python3 .claude/skills/frontend-permissive-license/scripts/audit_frontend_licenses.py --project vue_source
```

脚本会检查直接依赖是否精确锁定、安装版本是否一致、许可证文件是否存在，以及整个锁文件中的许可证是否全部位于宽松许可名单中。任何缺失、冲突或未知情况都会以非零状态退出，阻止依赖进入项目。
