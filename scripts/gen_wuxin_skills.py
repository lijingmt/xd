#!/usr/bin/env python3
"""Generate all 19 wuxin (无心) skill files from wuji templates.

无心 = 无极之上的终极隐藏职业：
- 技能基础数值（伤害/防御/治疗）= 无极 × 2（PVE 实际生效；
  PVP 由 fight.pike 的 wuxin_pvp_adjust 减回无极水准）
- 法力消耗 performs_cast = 无极 × 1.5
- 冷却节奏沿用 s_delayTime（3 秒全局轮转，与无极一致）
"""
import re, os, math

OUT = "gamelib/single/skills"
DMG_MULT = 2.0
CAST_MULT = 1.5

# (wuji_suffix, wuxin_cn_name)
SKILLS = [
    ("quan",    "【心】无心拳"),
    ("jue",     "【心】无心诀"),
    ("yi",      "【心】无心医"),
    ("dun",     "【心】无心盾"),
    ("hou",     "【心】无心吼"),
    ("jian",    "【心】无心剑"),
    ("yan",     "【心】无心焰"),
    ("tian",    "【心】无心天雷"),
    ("jing",    "【心】无心净"),
    ("bi",      "【心】无心壁"),
    ("huan",    "【心】无心唤"),
    ("yu",      "【心】无心雨"),
    ("lin",     "【心】无心灵泉"),
    ("ji",      "【心】无心击"),
    ("mie",     "【心】无心灭"),
    ("guixu",   "【灵】无心·归墟"),
    ("hunyuan", "【灵】无心·混元"),
    ("wuji",    "【灵】无心·无心"),
    ("guizhen", "【心】无心归真"),
]

def dmg(n):
    return int(math.ceil(n * DMG_MULT))

def cast(n):
    return int(math.ceil(n * CAST_MULT))

def gen_skill(suffix, cn):
    src_path = f"{OUT}/wuji{suffix}"
    if not os.path.exists(src_path):
        raise SystemExit(f"missing template {src_path}")
    src = open(src_path).read()

    src = src.replace('wuji', 'wuxin')
    src = re.sub(r'name_cn="[^"]*"', f'name_cn="{cn}"', src)

    # 数值段：攻击/防御/治疗 全部 ×2
    src = re.sub(r'(performs_attack\[\d+\]=)(\d+)',
                 lambda m: f"{m.group(1)}{dmg(int(m.group(2)))}", src)
    src = re.sub(r'(performs_mofa_attack\[\d+\]=)\((\{)(\d+),(\d+)(\})\)',
                 lambda m: f"{m.group(1)}({m.group(2)}{dmg(int(m.group(3)))},{dmg(int(m.group(4)))}{m.group(5)})", src)
    src = re.sub(r'(performs_defend\[\d+\]=)(\d+)',
                 lambda m: f"{m.group(1)}{dmg(int(m.group(2)))}", src)
    # 法力消耗 ×1.5
    src = re.sub(r'(performs_cast\[\d+\]=)(\d+)',
                 lambda m: f"{m.group(1)}{cast(int(m.group(2)))}", src)
    # 描述里的数值同步（造成X至Y点/恢复X至Y点/消耗法力X点）
    src = re.sub(r'造成(\d+)至(\d+)点',
                 lambda m: f'造成{dmg(int(m.group(1)))}至{dmg(int(m.group(2)))}点', src)
    src = re.sub(r'恢复(\d+)至(\d+)点',
                 lambda m: f'恢复{dmg(int(m.group(1)))}至{dmg(int(m.group(2)))}点', src)
    src = re.sub(r'消耗法力(\d+)点',
                 lambda m: f'消耗法力{cast(int(m.group(1)))}点', src)

    out = f"{OUT}/wuxin{suffix}"
    with open(out, 'w') as f:
        f.write(src)
    return out

generated = []
for suffix, cn in SKILLS:
    p = gen_skill(suffix, cn)
    generated.append(p)
    print(f"  ✓ wuxin{suffix}")
print(f"\nGenerated {len(generated)} wuxin skill files")
