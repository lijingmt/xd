# 无相职业契约

日期：2026-08-05

职业 ID：`wuxiang`

显示名：无相

阵营：中立（`third`）

身份标签：`【无】`

## 定位

无相是中立种族下的隐藏全职业。解锁条件：账号下所有 10 个当前职业（剑仙、
御士、主仙、矿妖、巫妖、影鬼、方士、镇越、天象、灵医）均达到 120 级。
满足条件后，新建角色时可选择「无相」，仍从 1 级开始正常成长。

设计意图是「机制傻瓜、技能池广、单点不强」。每个属性的中上线均输专精职业，
但工具数远多于专精；通过「无相心法」被动让最高属性的一半继续贡献其他属性，
把"全能属性"转译为"全能效能"，而不是简单叠加数值。组队定位是补位万金油，
任何角色都不应被无相在自身专长领域超越。

初始属性：生命 120、仙力 80、力量 8、敏捷 8、智力 8、幸运 0。
等级成长（按 85% 专精均值设计，所有属性对称成长）：
力量 `8+floor((等级-1)×1.5)`、敏捷 `8+floor((等级-1)×1.5)`、
智力 `8+floor((等级-1)×1.5)`。无装备时关键快照如下：

| 等级 | 力量 | 敏捷 | 智力 | 生命上限 | 仙力上限 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 8 | 8 | 8 | 120 | 80 |
| 30 | 52 | 52 | 52 | 1880 | 980 |
| 80 | 127 | 127 | 127 | 4940 | 2280 |
| 120 | 187 | 187 | 187 | 7340 | 3380 |
| 200（钻石会员上限） | 307 | 307 | 307 | 12140 | 5580 |

属性公式、生命/仙力上限与现有专精对齐方式由 `lowlib/mudlib/inherit/feature/level.pike`
里的成长系数控制，无相在 `setup_player` 里走 `third/wuxiang` 分支，
其他系数沿用 third 默认。

## 无相心法（被动）

- 取当前最高单项属性（力量/敏捷/智力）的 50% 加到另外两项上。
  例如力量 200、敏捷 100、智力 100 时，实际作用相当于力量 200、敏捷 200、智力 200。
- 加成仅在结算时计算，不写入 base_save，不参与装备穿戴门槛，不参与技能学习前置。
- 完全服务端权威；HTTP/Vue 只展示「无相心法生效中」标签和当前最高项，不接受客户端提交。
- 死亡、登出、换房不影响（本来就是即时计算）；无叠加、无层数、无到期。

## 技能与成长路线

无相共 15 项技能，覆盖近战、法术、治疗、增益、防御、净化、召唤、终极
八大类。跨职补位能力通常只保留对应专精约 50~60% 的强度，整体价值
来自「同时拥有」的灵活度，而不是单点强度。

| 解锁等级 | 技能 | 类型 | 说明 |
| ---: | --- | --- | --- |
| 1 | 无相拳 | 主动·物理 | 入门单体近战 |
| 5 | 无相诀 | 主动·法术 | 单体法术伤害 |
| 10 | 无相医 | 主动·治疗 | 单体回血，效率比方士低 30% |
| 15 | 无相盾 | 主动·防御 | 短时减伤盾，10s 吸收 1 次 |
| 20 | 无相吼 | 主动·增益 | 自身全属性 +10%，30s |
| 30 | 无相剑 | 主动·物理 | 进阶单体近战 |
| 35 | 无相焰 | 主动·法术 | 3秒轮转、专精60%威力；1～5阶覆盖2/4/6/8/10个合法目标 |
| 40 | 无相净 | 主动·净化 | 解 1 类负面 |
| 50 | 无相壁 | 主动·防御 | 团队短盾，需同房同队 |
| 55 | 无相唤 | 主动·召唤 | 弱版灵兽，5 分钟存在 |
| 60 | 无相雨 | 主动·治疗 | 同房同队群体回血 |
| 70 | 无相击 | 主动·物理 | 高阶单体近战 |
| 85 | 无相灭 | 主动·法术 | 高阶单体法术 |
| 100 | 万象归一 | 主动·终极 | 30s 全属性 +30%，冷却 5 分钟 |
| 120 | 无相化身 | 被动 | 永久：免疫一次致命伤/天，恢复 25% 生命 |

### 技能学习路径

- **1~70 级 13 项**：通过 `can_buy_book_list.csv` 教师与商店购买，正常学习。
- **100 级万象归一**：100 级专属任务奖励（任务 NPC 固定为无相教师）。
- **120 级无相化身**：120 级专属隐藏书掉落（普通怪 0.001%，70 级以上怪掉）。

### 隐藏书（3 本，按规范）

- 无相·归墟（80 级）：被动，提升无相心法加成比例到 60%
- 无相·混元（80 级）：主动，无相灭的强化版（双倍暴击率）
- 无相·无极（80 级）：主动，无相雨的强化版（治疗量 +50%，附带净化）

加入隐藏池后：
- 池子从 31 本扩到 34 本
- 共享分子从 31 同步扩到 34（保持每本约 1/100000 长期均值）
- `gamelib/inherit/npc.pike` 与 `itemsd.pike` 的 hidden pool 数据驱动更新
- 所有相关 UI 不再硬编码职业总数

## 装备与恢复品

- **可穿戴**：通用新手装、third 中立装、所有 `set_item_canWear` 未限定的装备
- **不可穿戴**：职业绑定的专属（如灵医饰物、镇越战刃、剑仙专属等）
- **恢复品**：`food/water/liandan/teyao` 中"无职业限制"或显式列出 `wuxiang` 的全部可消费
- **初始装备**：无相袍（防具，1 级可穿，平庸属性）、无相剑（武器，1 级可拿，平庸属性）
  - 这两件是无相专属、可销毁/可丢弃/可交易，避免误覆盖玩家后期装备

## 解锁机制实现

- 角色创建房间（`gamelib/d/init`）在 third 分支下新增 `wuxiang` 选项
- 选项可见性由服务端实时查询账号角色清单决定：
  - 通过 `ACCOUNTD->query_account_characters(account_id)` 取所有角色
  - 检查每个当前已上线职业（剑仙/御士/主仙/矿妖/巫妖/影鬼/方士/镇越/天象/灵医）
    是否至少有一个角色达到 120 级
  - 满足才向客户端暴露 `wuxiang` 入口
- 选项被点选后正常 `setup_player("third", "wuxiang")`，不跳过任何创建流程
- 不满足条件时入口隐藏，不可被绕过（防伪造请求）

## 单人、组队、挂机与会员

- **单人**：15 技能自由组合，普攻兜底；无相心法让属性均衡发挥
- **组队**：根据当前缺口补位（缺治疗当治疗、缺输出当输出），但任何角色都不超过等阶专精
- **挂机**：走通用 autofight 路径，自动选已学冷却完毕的技能；无专属 autofight 分支
- **会员**：核心机制、技能、装备、隐藏掉落免费。VIP 仅提供时长、清包效率、
  外观。无相不强制要求 VIP 助手；若日后增加，必须走 `PROFESSIONVIPD` 框架
- **PVP**：所有技能受 PVP/Boss/宠物上限约束；无相化身每天免疫一次致命伤后
  恢复 25% 生命，不计入"自动复苏"次数池

## 数值边界与反制

- 无相的单次输出/治疗/防御动作均不超过专精职业等阶技能的 85%
- 万象归一爆发期全属性 +30%，但仍不超过专精满级基线
- 无相化身每日免疫一次：仅 PVE/PVP 正常击杀生效，自杀/切磋/城战/已是鬼魂不触发
- 无相心法加成不参与装备门槛和技能前置，避免绕过职业限制
- 净化按"持续伤害 → 治疗压制 → 控制 → 70 级诅咒"顺序解一类
- 治疗压制最多削减 90%
- 无限反射/无限无敌/百分比伤害/远程效果全部禁止

## 资源、UI、部署

- **logo**：`images/wuxiang.png` + `web/images/wuxiang.png`（两套镜像）
- **男性头像**：`images/wuxiang_male.png` + `web/images/wuxiang_male.png`
- **女性头像**：`images/wuxiang_female.png` + `web/images/wuxiang_female.png`
- **Vue UI**：
  - 角色选择页解释：定位"全能补位"、难度"高"、资源"无相心法"、组队价值"高"
  - 头像选择页含男/女/无相 logo 三选项
  - 战斗小窗显示无相心法生效标签
- **legacy UI**：`look_top.pike`、`my_games.pike` 显式识别 `wuxiang`，不能继承 fangshi fallback
- **部署**：`restart-docker.sh`、`rebuild-image.sh`、Vue 构建脚本必须拷贝新资源

## 文档与发布

- `docs/build_xiand_profession_guide.py` 与 `docs/build_xiand_skill_guide.py`
  必须从权威目录枚举无相，不能硬编码职业数
- 重生 `docs/xiand-profession-guide.md/.pdf` 与 `docs/xiand-skill-guide.md/.pdf`
- 视觉检查：封面、技能表、隐藏书段、最后页
- `tmp/pdfs/` 与 `__pycache__/` 不入库

## 反向扫描清单

新职业 ID `wuxiang` 必须出现在：
- `lowlib/mudlib/inherit/user.pike`（setup_player）
- `lowlib/mudlib/inherit/feature/char.pike`（身份辅助）
- `gamelib/d/init`（创建入口）
- `lowlib/mudlib/inherit/feature/level.pike`（成长系数）
- `lowlib/system/inherit/base.pike`（默认无名头衔）
- `gamelib/cmds/look_top.pike`、`my_games.pike`（top/game 列表）
- `gamelib/data/can_buy_book_list.csv`（商店目录）
- `gamelib/clone/npc/*teacher*`（教师 NPC）
- `gamelib/single/skills/*`（15 个技能文件）
- `gamelib/clone/item/book/*`（书对象）
- `lowlib/mudlib/inherit/feature/equip.pike`（装备穿戴校验）
- `gamelib/single/daemons/itemsd.pike`、`bossdropd.pike`（装备生成）
- `gamelib/clone/item/{food,water,liandan,teyao}/*`（恢复品职业白名单）
- `gamelib/single/daemons/autofightd.pike`（如需无相特殊处理）
- `gamelib/single/daemons/_http_api_mod/html_renderer.pike`（API 序列化）
- `vue_source/index.html`、`vue_source/js/app.js`、`vue_source/css/app.css`
- `restart-docker.sh`、`rebuild-image.sh`（资源拷贝）
- `test_unit/test_wuxiang_profession.pike`（专项测试）

老硬编码集合 `6/7/8/9/10`、`30/31/100000` 等数字需扫描确认未被破坏。

## 待确认/已知约束

1. **资源图片**：本契约依赖 3 张 PNG（logo + 男/女头像 ×2 镜像共 6 个文件）。
   若用户无法提供原图，将先用占位图（同图复制）占位，正式上线前替换。
2. **解锁检查的性能**：每次访问创建角色页面都会查询账号所有角色等级。
   需要在 `ACCOUNTD` 加缓存或在角色升级到 120 时写一个 account-level flag。
3. **现有 120 级账号触发**：上线时若账号已满足条件，需在 `gamelib/clone/user.pike`
   login migration 中补一次解锁标记写入，让玩家下次进入创建页就能看到入口。
4. **PDF 重生需要 `pdftoppm`/`pdfinfo`**：当前环境需确认已安装。

## 完成定义

按 `.claude/skills/xiand-new-profession/references/profession-checklist.md` 全部
勾选 + 跑通 `ten-pass-audit.md` 十个独立视角的审核 + 重启 TestUnit 全过 +
`docs/wuxiang-10-pass-audit.md` 写完并 push 到 main 分支。
