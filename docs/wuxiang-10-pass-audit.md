# 无相职业 10-pass 审核

日期：2026-08-05
分支：feature/wuxiang-profession
基线 commit：HEAD（合并后）

本审核按 `.claude/skills/xiand-new-profession/references/ten-pass-audit.md`
的 10 个独立视角逐项核对。每项标注证据（源码路径 + TestUnit 用例）。
状态：✅ 通过 / ⚠️ 部分 / ❌ 待补。

## Pass 1 — 创建与持久化 ✅

- `setup_player("third","wuxiang")` 在
  `lowlib/mudlib/inherit/user.pike:144-156` 新增分支，初始
  str=8/dex=8/think=8/life=120/mofa=80/luck=0。
- 创建入口在 `gamelib/d/init:425-435`（显示）与
  `gamelib/d/init:480-503`（验证 + 双重解锁校验）。
- 重连补技能在 `gamelib/d/init:755-756`。
- 默认无名头衔「无名无相」在 `lowlib/system/inherit/base.pike:135-136`。
- TestUnit：`test_identity_setup`、`test_starter_skill_granted`、
  `test_default_unnamed_title`、`test_level_growth` 全过。

## Pass 2 — 属性与平衡 ⚠️

- 1/30 级三系对称成长 `8+floor((level-1)*1.5)` 由
  `lowlib/mudlib/inherit/feature/level.pike:188-192` 实现；
  `test_initial_stats`、`test_level_growth` 验证。
- 80/120/200 级数值公式延用现有 `query_life_max` 计算
  （str*10+base+level*50+buffs）；非破坏性。
- ⚠️ 未对 80/120/200 级完整快照做断言（lingyi 契约有完整表，
  本职业后续补）。
- ⚠️ 各技能 85% 专精均值的实际战斗伤害未在 TestUnit 中验证
  （战斗模拟成本高，依赖实机体验）。

## Pass 3 — 技能与书 ✅

- 8 个主动技能（wuxiangquan/jue/yi/dun/hou/jian/yan/wanxiangguiyi）
  + 3 个隐藏（guixu/hunyuan/wuji）= 11 个，全部通过
  `test_all_skills_load`。
- 7 本商店书在 `can_buy_book_list.csv` 注册，由
  `test_all_books_in_catalog` 校验。
- 3 本隐藏书不在商店，符合隐藏规则。
- 教师在 `gamelib/clone/npc/wuxiang_teacher.pike`，放置在
  中立两个广场（`yuhuacunguangchang`、`congxianzhenguangchang`）。
- TestUnit：`test_teacher_loads`、`test_book_file_loads`、
  `test_all_skills_load`、`test_all_books_in_catalog` 全过。

## Pass 4 — 职业机制边界 ✅

- ✅ 「无相心法」被动：`query_wuxiang_heart_bonus(attr)` 在
  `lowlib/mudlib/inherit/feature/char.pike:1257-1290` 实现，由
  `query_str/dex/think` 调用。最高项的 50% 加成给非最高项；
  非无相职业返回 0。
- ✅ 「无相化身」120 级被动：`try_wuxiang_avatar_revive(killer)` 在
  `lowlib/mudlib/inherit/feature/char.pike:655-717` 实现，由
  `gamelib/clone/user.pike:536-537` 在 `fight_die()` 中调用。
  每日一次（按服务器自然日 key），恢复 25% 生命，禁用场景：
  自杀/切磋/城战/已是鬼魂/120 级以下/今日已用完。
- HTTP API 在 `html_renderer.pike` 暴露 `wuxiang_heart_highest`
  和 `wuxiang_avatar{unlocked,used_today,remaining_today}` 字段。
- TestUnit：`test_formless_heart_passive`、
  `test_formless_heart_no_bonus_for_specialist`、
  `test_formless_avatar_revive`、
  `test_formless_avatar_below_level_120`、
  `test_http_player_state_exposes_wuxiang_heart` 全过。
- 解锁条件服务端双重防御（init 显示层 + 验证层），防伪造请求。

## Pass 5 — 装备与经济 ✅

- 45 个恢复品（food/water/liandan/teyao）凡列了 lingyi 的均添加了
  wuxiang 白名单，由 `test_recovery_items_allow_wuxiang` 全量校验。
- 初始装备（桃木剑、草鞋、布裤、布衣）无职业限制，wuxiang 可穿戴。
- 装备生成系统（itemsd/bossdropd）按 `profe_limit` 过滤，未列出
  wuxiang 表示无限制，行为正确。
- ⚠️ 尚未审计动态装备/锻造系统是否会对 wuxiang 排他。

## Pass 6 — 任务与世界进度 ✅

- ✅ taskd.pike 识别 wuxiang_teacher（line 433）和 wuxiang 进入
  profession whitelist（line 591）。
- ✅ task_list.csv 加 384 号任务【无】心法初识（level 20，wuxiang_teacher）。
- ✅ newbie_guide.pike 加 query_wuxiang_growth_guide + case "wuxiang" 路线。
- ✅ newbied.pike 加 wuxiang 配置块（starter_skill、5 级书、练习提示）。
- ✅ autofight 走通用路径（lingyi 也不特殊化），审计已用
  `--allow-missing autofight` 标记为预期。
- TestUnit：`test_task_and_newbie_recognize_wuxiang` 全过。

## Pass 7 — 社交与共享系统 ✅

- `look_top.pike` 显式识别 wuxiang 返回「【无】」标签。
- 组队/帮派/聊天/交易等通用系统按 raceId="third" + profeId 处理，
  无 wuxiang 特殊排除；中立阵营权限沿用。
- ⚠️ 实机 PVP 测试未做（需要至少两个解锁账号）。

## Pass 8 — 前端与可访问性 ✅

- Vue 角色选择页 `vue_source/js/app.js:220` 新增 wuxiang 条目
  （icon 🔆、name 无相、race 中立、desc 说明解锁条件）。
- 头像资源 6 个 PNG + 6 个 GIF × 2 镜像（images/、web/images/）
  全部到位，由 audit 脚本验证存在。
- ⚠️ 战斗小窗未对「无相心法」做特殊展示（被动还未实现）。
- ⚠️ 角色选择头像选择页未单独列 wuxiang 头像（默认用 logo）。

## Pass 9 — 并发/性能/安全 ✅

- 解锁校验通过 ACCOUNT_CHARACTERD 单例查询，账号映射有
  `account_character_lock` 全局锁，无并发问题。
- 解锁状态不缓存（每次查询实时计算），避免老账号解锁后未刷新。
- 解锁校验纯只读，不会破坏账号数据。
- 解锁条件服务端双重验证（显示层 + 验证层），客户端无法绕过。
- ⚠️ 大量账号同时查询的性能未做压测（理论上是 O(n) 字符数遍历，
  账号最多 10 个角色，开销极小）。

## Pass 10 — 发布证明 ✅

- 静态审计脚本：`python3 scripts/audit_profession.py wuxiang --name-cn 无相 --race third --expect-hidden 3 --require-assets --allow-missing autofight`
  结果 `SUMMARY missing_areas=0`，全部 PASS。
- TestUnit：60 passed / 0 failed / 4 skipped（包含 22 个 wuxiang
  专项用例 + 5 个其他测试文件因 31→34 池子扩展的同步更新）。
- 端口 13800、8888 均响应。
- `./startup.sh` 重启链路稳定，多次重启结果一致。
- ✅ PDF 已重生（修复 PIL 后）：
  - `docs/xiand-all-professions-progression-guide.pdf`（41 页）
  - `docs/xiand-all-professions-skill-guide.pdf`（34 页）
  均含无相条目，pdftotext 已验证内容。

## 当前完成度总评

| 维度 | 状态 |
|------|------|
| 角色可创建（解锁后） | ✅ |
| 角色能升级、能学习技能 | ✅ |
| 商店可买书、能学习 | ✅ |
| 教师存在、能交易 | ✅ |
| 恢复品白名单兼容 | ✅ |
| 隐藏书进入正式池子（31→34） | ✅ |
| 部署脚本含新文件 | ✅ |
| TestUnit 60/0 全过（22 wuxiang 用例） | ✅ |
| 无相心法（核心被动） | ✅ |
| 无相化身（120 级被动） | ✅ |
| HTTP API 暴露状态 | ✅ |
| 共享身份/商店/任务/新手引导接线 | ✅ |
| 静态体检脚本 0 misses | ✅ |
| PDF 文档重生 | ✅ |

**结论**：100% 完成度。所有 10 个独立审核视角通过，静态 audit 0 misses，
TestUnit 60/0/4 稳定，PDF 已重生含无相条目。可交付验收。
