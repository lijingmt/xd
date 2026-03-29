---
name: fangshi-system
description: 方士职业完整系统，包括召唤、技能、PK、装备掉落和单元测试
version: 1.0.0
---

# 方士职业系统 (Fangshi Profession System)

方士是游戏中的**中立职业**，通过召唤灵兽（虎、鹤、龟）进行战斗。这个文档涵盖了方士系统的完整实现，包括所有踩过的坑和解决方案。

## 目录
- [职业基础](#职业基础)
- [召唤系统](#召唤系统)
- [技能系统](#技能系统)
- [PK系统](#pk系统)
- [装备系统](#装备系统)
- [单元测试](#单元测试)
- [常见问题](#常见问题)

---

## 职业基础

### 职业配置

**raceId**: `third` (中立阵营)
**profeId**: `fangshi` (方士职业)

### 核心文件

| 文件 | 作用 |
|------|------|
| `gamelib/setup_player.pike` | 角色创建，添加方士职业选项 |
| `gamelib/single/skills/` | 方士技能目录 |
| `gamelib/single/skills/lingxuan` | 灵玄（主动攻击技能） |
| `gamelib/single/skills/linghuoshao` | 灵火烧（DOT减防） |
| `gamelib/single/skills/lingzhi` | 灵治（治疗+驱散） |
| `gamelib/single/skills/lingdun` | 灵盾（防御+反弹） |
| `gamelib/single/skills/huling` | 虎灵（召唤猛虎） |
| `gamelib/single/skills/heling` | 鹤灵（召唤仙鹤） |
| `gamelib/single/skills/guiling` | 龟灵（召唤灵龟） |

### 技能类型

```pike
skill_type = ({"zhudong", "fangshi"});  // 主动技能
skill_type = ({"beidong", "fangshi"});  // 被动技能
s_skill_type = "phy";     // 物理攻击
s_skill_type = "buff";    // 增益效果
s_skill_type = "heal";    // 治疗
s_skill_type = "curse";   // 减益效果
```

---

## 召唤系统

### 召唤兽类型

| 召唤兽 | 技能文件 | 特点 |
|--------|----------|------|
| 猛虎 | `huling` | 高攻击、嘲讽、暴击加成 |
| 仙鹤 | `heling` | 治疗主人、法术攻击 |
| 灵龟 | `guiling` | 高防御、减伤、保护主人 |

### 召唤系统核心文件

| 文件 | 作用 |
|------|------|
| `gamelib/single/skills/base_summon.pike` | 召唤兽基类 |
| `gamelib/single/daemons/summond.pike` | 召唤守护进程 |
| `lowlib/wapmud2/cmds/summon.pike` | 召唤命令 |

### ⚠️ 重要踩坑记录

#### 坑1: 心跳函数使用 time() % n 不可靠

**问题代码：**
```pike
void heart_beat() {
    if(time() % 3 == 0) {  // ❌ 错误！
        // 每3秒执行一次
    }
}
```

**原因：** `time()` 返回的是从1970年至今的秒数，不是心跳计数。

**正确做法：** 使用计数器
```pike
int heal_counter = 0;

void heart_beat() {
    heal_counter++;
    if(heal_counter >= 3) {
        heal_counter = 0;
        // 执行治疗逻辑
    }
}
```

#### 坑2: _tasknpc 标志阻止召唤兽参与战斗

**问题代码：**
```pike
void create() {
    _tasknpc = 1;  // ❌ 错误！这会阻止召唤兽战斗
}
```

**正确做法：** 不要设置 `_tasknpc` 标志
```pike
void create() {
    // 只设置必要的属性
    set("race", "summon");
    set("gender", "无性");
}
```

#### 坑3: 继承语法必须使用大写定义

**错误：**
```pike
inherit wap_npc;  // ❌ 错误
```

**正确：**
```pike
#include <wapmud2.h>
inherit WAP_NPC;  // ✓ 正确
```

#### 坑4: foreach 语法顺序

**错误：**
```pike
foreach(string summon_type, object summon; summons)  // ❌ 错误
```

**正确：**
```pike
foreach(summons; string summon_type; object summon)  // ✓ 正确
```

#### 坑5: tell_room 在 daemon 中不可用

**问题：** `base_summon.pike` 继承自 `WAP_NPC`，但在某些情况下 `tell_room` 不可用。

**解决：** 创建辅助函数
```pike
void summon_tell_room(object env, string msg) {
    if(env && objectp(env)) {
        if(functionp(env->tell_room)) {
            env->tell_room(msg);
        } else {
            // 备用方案
            all_inventory(env)->hear_msg(msg);
        }
    }
}
```

### 召唤兽AI逻辑

```pike
void heart_beat() {
    if(!summon_owner || !objectp(summon_owner)) {
        destruct(this_object());
        return;
    }

    // 获取主人的战斗目标
    object target = summon_owner->query_attack_target();

    if(target && target->get_cur_life() > 0) {
        // 攻击主人的敌人
        attack_target(target);
    } else if(some_other_condition) {
        // 根据召唤兽类型执行不同逻辑
        // 猛虎：攻击目标
        // 仙鹤：治疗主人
        // 灵龟：保护主人
    }
}
```

---

## 技能系统

### 技能文件结构

```pike
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_SKILL;

protected void create() {
    name = "skill_name";           // 内部名称
    name_cn = "技能中文名";        // 显示名称
    desc = "技能描述";             // 描述
    s_type = "zhudong";            // 类型：zhudong(主动) / beidong(被动)
    s_skill_type = "phy";          // 效果类型：phy/buff/curse/heal
    s_curse_type = "attack";       // 诅咒类型（DOT技能用）

    // 冷却和持续时间
    s_delayTime = 30;              // 冷却时间（秒）
    s_lasttime = 15;               // 持续时间（秒）

    // 伤害/效果值（按等级）
    performs_attack[1] = 500;
    performs_attack[2] = 800;
    performs_attack[3] = 1200;
    performs_attack[4] = 1700;
    performs_attack[5] = 2500;

    // 法力消耗
    performs_cast[1] = 50;
    performs_cast[2] = 60;
    performs_cast[3] = 70;
    performs_cast[4] = 80;
    performs_cast[5] = 100;

    // 职业限制
    skill_type += ({"fangshi"});

    // 等级限制
    performs_level_limit[1] = 10;
    performs_level_limit[2] = 30;
    performs_level_limit[3] = 50;
    performs_level_limit[4] = 70;
    performs_level_limit[5] = 90;
}
```

### 神秘技能（商店售卖）

| 技能 | 特点 | 文件 |
|------|------|------|
| 灵玄·秘 | 更高伤害+混乱 | `lingxuan_mystic` |
| 灵火烧·秘 | 更长DOT+更大减防 | `linghuoshao_mystic` |
| 灵治·秘 | 治疗+驱散负面 | `lingzhi_mystic` |
| 灵盾·秘 | 更高防御+伤害反弹 | `lingdun_mystic` |
| 虎灵·秘 | 更强虎灵+更长持续时间 | `huling_mystic` |

神秘技能标记：
```pike
skill_rare = "mystic";  // 稀有度标记
```

---

## PK系统

### 方士vs方士 PK测试

**测试文件：** `test_unit/test_fangshi_pk.pike`

**测试场景：**
1. 双方都是方士职业
2. 各自召唤灵兽
3. 互相攻击
4. 验证伤害计算
5. 验证召唤兽参与战斗

### PK关键代码

```pike
// 获取PK目标
object opponent = find_player("other_fangshi_player");

// 发起攻击
this_player()->kill(opponent);

// 召唤兽自动攻击主人的敌人
// 召见 summon.pike 中的 logic_ai() 函数
```

### PK测试验证点

- [ ] 双方玩家都能成功召唤
- [ ] 召唤兽正确攻击对方的召唤兽或玩家
- [ ] 伤害数值正确计算
- [ ] 召唤兽死亡后处理正确
- [ ] 玩家死亡后召唤兽消失
- [ ] 技能冷却正常工作

---

## 装备系统

### ⚠️ 重大踩坑：装备掉落不包含方士职业

#### 问题描述

玩家打怪掉落的装备显示：
```
要求职业：剑仙 羽士 诛仙 狂妖 巫妖 影鬼
```
**缺少"方士"！**

#### 根本原因

装备生成流程：
1. 打怪掉落时，`itemsd.pike` 读取装备模板
2. 如果装备文件**已存在**，直接 clone 返回
3. 如果装备文件**不存在**，生成新文件并写入

**问题代码（修复前）：**
```pike
if(Stdio.exist(ITEM_PATH+item_name)){
    // 文件存在，直接返回
    rtn_ob=clone(ITEM_PATH+item_name);
    return (rtn_ob);  // ❌ 没有添加方士职业！
}
```

#### 解决方案

**方案1：在生成新文件时添加方士**

```pike
// itemsd.pike 和 bossdropd.pike
// 在 write_item_file 之前添加

// 自动为所有生成的装备添加方士职业支持
if(search(writeback, "set_item_profeLimit(\"fangshi\")") == -1 &&
   search(writeback, "set_item_profeLimit") != -1) {
    // 在文件结束前 } 之前插入
    int last_brace = search(writeback, "\n}\n");
    if(last_brace == -1) {
        last_brace = search(writeback, "}\n");
    }
    if(last_brace != -1) {
        writeback = writeback[..last_brace-1] + "    set_item_profeLimit(\"fangshi\");\n" + writeback[last_brace..];
    }
}
```

**方案2：在 clone 已有装备时添加方士**

```pike
// itemsd.pike
if(Stdio.exist(ITEM_PATH+item_name)){
    rtn_ob=clone(ITEM_PATH+item_name);
    // 即使装备已存在，也要检查并添加方士职业
    if(rtn_ob) {
        array(string) profs = rtn_ob->query_item_profeLimit();
        if(profs && sizeof(profs) > 0 && search(profs, "fangshi") == -1) {
            rtn_ob->set_item_profeLimit("fangshi");
        }
    }
    return (rtn_ob);
}
```

### 装备相关文件

| 文件 | 修改内容 |
|------|----------|
| `gamelib/single/daemons/itemsd.pike` | 普通装备掉落，添加方士职业 |
| `gamelib/single/daemons/bossdropd.pike` | BOSS装备掉落，添加方士职业 |
| `lowlib/mudlib/inherit/feature/equip.pike` | 装备职业限制显示 |

### 装备职业限制

```pike
// 设置装备职业限制
set_item_profeLimit("fangshi");
set_item_profeLimit("jianxian");
set_item_profeLimit("yushi");
// ... 可以多次调用，职业会累加到数组中

// 查询装备职业限制
array(string) profs = item->query_item_profeLimit();
// 返回: ({"fangshi", "jianxian", "yushi", ...})
```

---

## 单元测试

### 测试文件结构

| 测试文件 | 测试内容 |
|----------|----------|
| `test_unit/test_fangshi.pike` | 基础功能测试（8个测试） |
| `test_unit/test_fangshi_pk.pike` | PK系统测试（7个测试） |
| `test_unit/test_fangshi_edge_cases.pike` | 边缘测试（24个测试） |
| `test_unit/test_equipment_drop_fangshi.pike` | 装备掉落测试（7个测试） |

### 测试运行

所有测试在游戏启动时自动运行：
```pike
// gamelib/single/daemons/testunitd.pike
void run_tests() {
    run_test_unit_file("test_fangshi.pike");
    run_test_unit_file("test_fangshi_pk.pike");
    run_test_unit_file("test_fangshi_edge_cases.pike");
    run_test_unit_file("test_equipment_drop_fangshi.pike");
}
```

### 测试框架

```pike
#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
    "total": 0,
    "passed": 0,
    "failed": 0,
]);

void test_start(string test_name) {
    test_results["total"]++;
    werror("\n[测试 %d] %s\n", test_results["total"], test_name);
}

void test_pass() {
    test_results["passed"]++;
    werror("  ✓ 通过\n");
}

void test_fail(string reason) {
    test_results["failed"]++;
    werror("  ✗ 失败: %s\n", reason);
}

void run_tests() {
    // 测试代码
    test_start("测试名称");
    // 测试逻辑
    if(成功条件) {
        test_pass();
    } else {
        test_fail("失败原因");
    }
}
```

---

## 常见问题

### Q1: 召唤兽不攻击敌人？

**检查清单：**
1. 是否设置了 `_tasknpc = 1`？如果有，去掉它
2. 召唤兽的 `heart_beat()` 是否正常工作？
3. 是否正确获取了主人的攻击目标？
4. 敌人是否还活着？

```pike
// 检查心跳是否启动
if(query_heart_beat() == 0) {
    set_heart_beat(1);
}
```

### Q2: 装备掉落后没有方士职业？

**检查清单：**
1. 确认 `itemsd.pike` 和 `bossdropd.pike` 已修改
2. 重启游戏让修改生效
3. 获取**新掉落**的装备（旧的不会自动更新）
4. 检查调试输出日志

### Q3: 方士技能学习失败？

**检查清单：**
1. 技能文件是否存在？
2. 技能文件的 `create()` 函数是否正确定义？
3. `skill_type` 是否包含 `"fangshi"`？
4. CSV配置文件是否正确？

```bash
# 检查技能文件
ls gamelib/single/skills/huling

# 检查CSV配置
grep "huling" gamelib/data/can_buy_book_list.csv
```

### Q4: 召唤兽消失问题？

**可能原因：**
1. 主人死亡
2. 主人登出
3. 召唤时间结束
4. 召唤兽被杀

**解决方案：**
```pike
void check_owner_status() {
    if(!summon_owner || !objectp(summon_owner)) {
        // 主人不存在，召唤兽消失
        destruct(this_object());
        return;
    }

    if(summon_owner->get_cur_life() <= 0) {
        // 主人死亡，召唤兽消失
        destruct(this_object());
        return;
    }
}
```

### Q5: PK时召唤兽行为异常？

**检查清单：**
1. 确认召唤兽的 `attack_target()` 函数正确
2. 检查 `query_attack_target()` 是否返回正确的敌人
3. 确认召唤兽没有被其他因素干扰

---

## 技能书学习系统

### ⚠️ 重要踩坑：职业匹配问题

#### 问题描述

方士玩家学习技能书时提示职业限制错误，即使职业是方士。

**错误信息：**
```
你仔细研读【方】灵一触，但是该技能并非你这个职业所能领悟的！
```

#### 根本原因

`readed.pike` 中的职业比较逻辑：
- 技能书使用职业ID（如 `"fangshi"`）从CSV导入
- 但代码只比较职业中文名（如 `"方士"`）
- 两者不匹配导致学习失败

**修复前代码：**
```pike
// 只比较职业中文名
if(this_object()->profe_read_limit==me->query_profe_cn(me->query_profeId()))
```

#### 解决方案

**修复后代码（支持两种格式）：**
```pike
// 修复：比较职业ID而不是职业名称
// 之前比较 profe_read_limit(如"fangshi") 与 query_profe_cn()(如"方士") 会失败
if(this_object()->profe_read_limit==me->query_profeId() || this_object()->profe_read_limit==me->query_profe_cn(me->query_profeId()))
```

**向后兼容：**
- 老技能书使用中文名（`profe_read_limit="方士"`）→ 匹配 `query_profe_cn()`
- 新技能书使用职业ID（`profe_read_limit="fangshi"`）→ 匹配 `query_profeId()`
- OR逻辑确保两种格式都能正常工作

#### 修复文件

| 文件 | 修改内容 |
|------|----------|
| `lowlib/mudlib/inherit/feature/readed.pike` | 修复 `read()`, `beidong_read()`, `spec_read()` 三个函数中的职业比较 |

### 技能书学习单元测试

| 测试文件 | 测试内容 |
|----------|----------|
| `test_unit/test_skill_book_learning.pike` | 技能书文件静态检查（10个测试） |
| `test_unit/test_skill_learning_simulation.pike` | 真实模拟学习逻辑（11个测试） |

### 学习返回码

| 返回码 | 含义 | 提示消息 |
|--------|------|----------|
| 0 | 学习失败 | 通用错误 |
| 1 | 学习成功 | 成功学会了技能！ |
| 2 | 已经学会 | 你已经学会该技能了 |
| 3 | 职业限制 | 该技能并非你这个职业所能领悟的 |
| 4 | 等级限制 | 你等级不够，无法领悟该技能 |
| 5 | 必须学会前一级 | 必须学会前一级技能 |
| 6 | 同级不能学习 | 已学会同级技能 |
| 7 | 跳级学习不能 | 不能跳级学习技能 |

---

## 关键文件清单

### 方士核心文件

```
gamelib/
├── setup_player.pike                    # 角色创建
├── single/
│   ├── daemons/
│   │   ├── summond.pike                 # 召唤守护进程
│   │   ├── itemsd.pike                  # 装备掉落（已修改）
│   │   ├── bossdropd.pike               # BOSS掉落（已修改）
│   │   └── testunitd.pike               # 单元测试守护进程
│   └── skills/
│       ├── base_summon.pike             # 召唤兽基类
│       ├── lingxuan                     # 灵玄
│       ├── linghuoshao                  # 灵火烧
│       ├── lingzhi                      # 灵治
│       ├── lingdun                      # 灵盾
│       ├── huling                       # 虎灵
│       ├── heling                       # 鹤灵
│       ├── guiling                      # 龟灵
│       ├── lingxuan_mystic              # 灵玄·秘
│       ├── linghuoshao_mystic           # 灵火烧·秘
│       ├── lingzhi_mystic               # 灵治·秘
│       ├── lingdun_mystic               # 灵盾·秘
│       └── huling_mystic                # 虎灵·秘
└── cmds/
    └── summon.pike                      # 召唤命令

lowlib/
├── mudlib/inherit/feature/
│   └── readed.pike                      # 技能书学习（已修复职业匹配）
└── wapmud2/
    ├── cmds/
    │   └── summon_command.pike          # 召令命令
    └── inherit/
        └── summon.pike                  # 召唤继承

test_unit/
├── test_fangshi.pike                    # 基础测试
├── test_fangshi_pk.pike                 # PK测试
├── test_fangshi_edge_cases.pike         # 边缘测试
├── test_equipment_drop_fangshi.pike     # 装备测试
├── test_skill_book_learning.pike        # 技能书静态检查
└── test_skill_learning_simulation.pike  # 技能学习模拟测试
```

---

## 使用场景

当用户提到以下问题时，触发此技能：
- "方士"
- "fangshi"
- "召唤兽"
- "召唤系统"
- "虎灵"
- "鹤灵"
- "龟灵"
- "装备掉落方士"
- "方士技能"
- "方士PK"
- "third race"
- "中立职业"
