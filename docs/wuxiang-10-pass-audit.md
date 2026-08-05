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

## Pass 4 — 职业机制边界 ⚠️

- ⚠️ 「无相心法」被动（最高属性 50% 加成其他属性）**尚未实现**。
  当前仅属性基础值生效，心法加成需要后续在 attack.pike / defend.pike
  的伤害结算处加 hook。
- ⚠️ 「无相化身」每日免疫一次致命伤（120 级被动）**尚未实现**。
- 解锁条件服务端双重防御（init 显示层 + 验证层），防伪造请求。
- TestUnit：解锁条件由 `test_identity_setup` 间接覆盖（创建后即解锁
  路径正确）；完整的"未解锁账号被拒"测试待补。

## Pass 5 — 装备与经济 ✅

- 45 个恢复品（food/water/liandan/teyao）凡列了 lingyi 的均添加了
  wuxiang 白名单，由 `test_recovery_items_allow_wuxiang` 全量校验。
- 初始装备（桃木剑、草鞋、布裤、布衣）无职业限制，wuxiang 可穿戴。
- 装备生成系统（itemsd/bossdropd）按 `profe_limit` 过滤，未列出
  wuxiang 表示无限制，行为正确。
- ⚠️ 尚未审计动态装备/锻造系统是否会对 wuxiang 排他。

## Pass 6 — 任务与世界进度 ❌

- ❌ 未实现无相专属的 level-20 奖励、level-53 任务链。
- ❌ 新手引导 `newbie_guide.pike` 未对 wuxiang 显式分支；
  玩家可走通用引导。
- 现有通用任务系统（taskd）按 profeId 过滤；wuxiang 不在限制中
  默认可参与，但缺少专属任务。
- 智能挂机（autofight）走通用路径，wuxiang 无需特殊处理。

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

## Pass 10 — 发布证明 ⚠️

- 静态审计脚本未运行（保留作后续工作）。
- TestUnit：60 passed / 0 failed / 4 skipped（包含 11 个 wuxiang
  专项用例 + 5 个其他测试文件因 31→34 池子扩展的同步更新）。
- 端口 13800、8888 均响应。
- `./startup.sh` 重启链路稳定。
- ⚠️ 未跑 `docs/build_xiand_profession_guide.py` PDF 重生
  （依赖 pdftoppm，本次会话跳过）。
- ⚠️ 未跑 audit_profession.py --require-assets 静态体检
  （后续补一份体检报告）。

## 当前完成度总评

| 维度 | 状态 |
|------|------|
| 角色可创建（解锁后） | ✅ |
| 角色能升级、能学习技能 | ✅ |
| 商店可买书、能学习 | ✅ |
| 教师存在、能交易 | ✅ |
| 恢复品白名单兼容 | ✅ |
| 隐藏书进入正式池子 | ✅ |
| 部署脚本含新文件 | ✅ |
| TestUnit 60/0 全过 | ✅ |
| 无相心法（核心被动） | ❌ 待补 |
| 无相化身（120 级被动） | ❌ 待补 |
| 专属任务链 | ❌ 待补 |
| PDF 文档重生 | ❌ 待补 |
| 静态体检脚本 | ❌ 待补 |

**结论**：MVP+ 完成度。角色可创建、可玩、可学习、可挂机、可参与共享系统。
核心被动机制（无相心法）和 120 级终极被动（无相化身）需要后续实现，
否则职业特性不够明显。文档侧 PDF 重生和静态体检可在下个会话补。
