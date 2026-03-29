---
name: skill-proficiency
description: 技能熟练度系统 - 技能升级、熟练度增长机制
version: 1.0.0
---

# 技能熟练度系统 (Skill Proficiency System)

本文档说明游戏中技能熟练度的工作原理，包括技能升级机制、熟练度增长规则和显示逻辑。

## 目录

- [技能数据结构](#技能数据结构)
- [熟练度增长机制](#熟练度增长机制)
- [技能升级条件](#技能升级条件)
- [显示逻辑](#显示逻辑)
- [相关文件](#相关文件)
- [常见问题](#常见问题)

---

## 技能数据结构

### skills 映射结构

```pike
// 玩家技能数据存储在 player->skills 映射中
mapping skills = ([
    "skill_name": ({等级, 熟练度}),
    "lingyichu": ({1, 0}),      // 灵一触：1级，0熟练度
    "lingshu": ({1, 0}),        // 灵书：1级，0熟练度
]);
```

**数组索引：**
- `[0]` - 技能等级（1-10级）
- `[1]` - 当前熟练度（0到升级要求）

### 初始学习状态

```pike
// readed.pike 中学习新技能时初始化
me->skills[this_object()->skill_bname] = ({1, 0});
// 结果：skills["lingyichu"] = ({1, 0})
```

---

## 熟练度增长机制

### 每次使用技能

**文件位置：** `lowlib/wapmud2/inherit/feature/fight.pike:183-201`

```pike
void skills_level_check(string sname){
    if(MUD_SKILLSD[sname]->boss_skill == 1)
        return;  // BOSS技能不增加熟练度

    int cur_skills_level_limit = 10;

    // 检查是否达到升级条件
    if(this_object()->skills[sname][1] >= MUD_SKILLSD[sname]->performs_shuliandu[this_object()->skills[sname][0]]){
        // 升级逻辑
        if(this_object()->skills[sname][0] < cur_skills_level_limit){
            this_object()->skills[sname][0]++;   // 等级+1
            this_object()->skills[sname][1] = 0; // 熟练度归零
        }
    }
    else{
        // 技能升级速度降低一半
        int tmp = random(3) + 1;
        if(tmp == 2)
            this_object()->skills[sname][1]++;   // 熟练度+1
    }
}
```

### 关键规则

| 项目 | 说明 |
|------|------|
| 增加概率 | **33%** (random(3)+1, 当等于2时增加) |
| 每次增加 | +1 熟练度 |
| 调用时机 | 每次使用技能后自动调用 |
| BOSS技能 | 不增加熟练度 |

### 熟练度要求

**文件位置：** `lowlib/mudlib/inherit/skill.pike:17-22`

```pike
mapping(int:int) performs_shuliandu = ([
    1: 2000,   // 1级→2级需要2000点
    2: 4000,   // 2级→3级需要4000点
    3: 8000,   // 3级→4级需要8000点
    4: 12000,  // 4级→5级需要12000点
    5: 20000,  // 5级→6级需要20000点
    // ... 以此类推
]);
```

### 升级所需次数估算

```
1级→2级: 2000点 ÷ (1/3概率) ≈ 6000次使用
2级→3级: 4000点 ÷ (1/3概率) ≈ 12000次使用
3级→4级: 8000点 ÷ (1/3概率) ≈ 24000次使用
```

---

## 显示逻辑

### 技能列表显示

**文件位置：** `lowlib/wapmud2/inherit/feature/skills.pike:34`

```pike
// 显示格式：技能名(等级/X%)
out += "[" + MUD_SKILLSD[name]->query_name_cn() +
       "(" + m[name][0] + "级/" +
       (int)(100 * m[name][1] / MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]) +
       "%):skill_detail " + name + "]";

// 示例输出：【方】灵一触(1级/0%)
```

### 计算公式

```
显示百分比 = int(当前熟练度 × 100 / 该等级升级要求)

示例：
- 熟练度0:   (100 × 0 / 2000)   = 0%
- 熟练度1:   (100 × 1 / 2000)   = 0.05% → 0% (整数截断)
- 熟练度19:  (100 × 19 / 2000)  = 0.95% → 0%
- 熟练度20:  (100 × 20 / 2000)  = 1%   → 1%
- 熟练度2000: (100 × 2000 / 2000) = 100% → 升级到2级
```

### 为什么总是显示0%？

**原因：**
1. 使用整数除法，小数部分被截断
2. 需要至少20点熟练度才能显示1%
3. 大约需要使用60次技能才能看到1%

**这是正常现象！** 不是bug。

---

## 技能升级条件

### 升级检查流程

```
使用技能
  ↓
调用 skills_level_check()
  ↓
随机增加熟练度 (33%概率)
  ↓
检查: 熟练度 >= 要求值?
  ├── YES → 技能等级+1，熟练度归零
  └── NO  → 保持当前状态
```

### 自动升级

当熟练度达到要求时，**自动升级**，无需额外操作：

```pike
if(this_object()->skills[sname][1] >= required_proficiency){
    this_object()->skills[sname][0]++;   // 等级+1
    this_object()->skills[sname][1] = 0; // 熟练度归零
}
```

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `lowlib/wapmud2/inherit/feature/fight.pike` | `skills_level_check()` 熟练度增加逻辑 |
| `lowlib/wapmud2/inherit/feature/skills.pike` | 技能显示界面 |
| `lowlib/mudlib/inherit/skill.pike` | 默认熟练度要求定义 |
| `lowlib/mudlib/inherit/feature/readed.pike` | 技能书学习，初始化技能数据 |
| `gamelib/single/skills/` | 各技能具体定义 |

---

## 常见问题

### Q1: 技能熟练度不增长？

**检查清单：**
1. 确认技能使用成功（有伤害/效果输出）
2. 确认不是BOSS技能（boss_skill == 1）
3. 查看档案数据确认实际数值

```bash
# 查看档案中的技能数据
strings /usr/local/games/xiand/data_xiand/u/i1/xd01fangshi1.o | grep "skills ("
```

### Q2: 为什么总是0%？

**答：** 这是正常的！
- 使用整数除法显示百分比
- 需要20点熟练度才显示1%
- 大约60次使用才能看到1%

### Q3: 熟练度系统可以调整吗？

**可以调整的方式：**
1. 修改增加概率（修改 `random(3)+1` 为 `random(2)+1` = 50%）
2. 修改熟练度要求（修改 `performs_shuliandu` 映射）
3. 修改显示逻辑（使用浮点数显示小数）

**注意：** 调整会影响游戏平衡，建议谨慎修改。

### Q4: 技能升级会保留等级吗？

**答：** 升级后：
- 技能等级 +1
- 熟练度归零（重新计算下一级的进度）

---

## 使用场景

当用户提到以下问题时，触发此技能：
- "技能熟练度"
- "技能不升级"
- "为什么是0%"
- "技能升级"
- "performs_shuliandu"
- "skills_level_check"
