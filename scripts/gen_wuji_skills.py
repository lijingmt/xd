#!/usr/bin/env python3
"""Generate all 17 wuji skill files from taiji templates (30% stronger + AOE/heal tweaks)."""
import re, os, math

OUT = "gamelib/single/skills"
MULT = 1.3  # 30% stronger than taiji

# (suffix, cn_name, type_override, desc, is_aoe, is_group_heal)
SKILLS = [
    ("quan",  "【极】无极拳", None,           "无极入门近战拳法，三系均衡发挥，威力胜太极三成", False, False),
    ("jue",   "【极】无极诀", None,           "无极风系法术打击，快过太极诀三成",               False, False),
    ("yi",    "【极】无极医", None,           "无极自愈心法，回血胜太极三成",                   False, False),
    ("dun",   "【极】无极盾", None,           "无极护盾，厚度胜太极三成",                       False, False),
    ("hou",   "【极】无极吼", None,           "无极战吼，全属性加成胜太极三成",                 False, False),
    ("jian",  "【极】无极剑", None,           "无极剑法，剑气胜太极三成",                       False, False),
    ("yan",   "【极】无极焰", "balanced_aoe", "无极群攻法术，覆盖同房敌对目标，燎原之势胜太极焰三成", True, False),
    ("tian",  "【极】无极天雷", "balanced_aoe", "无极天雷群杀，九天雷罚覆盖全场敌对目标",         True, False),
    ("jing",  "【极】无极净", None,           "无极净化，驱散负面状态",                         False, False),
    ("bi",    "【极】无极壁", None,           "无极壁垒，守护全队，坚胜太极三成",               False, False),
    ("huan",  "【极】无极唤", None,           "无极召唤灵兽协力作战",                           False, False),
    ("yu",    "【极】无极雨", None,           "无极甘霖群奶，治愈全队队友，回血胜太极雨三成",   False, True),
    ("lin",   "【极】无极灵泉", "balanced_team_heal", "无极灵泉群奶，生命之泉涌流全场队友",       False, True),
    ("ji",    "【极】无极击", None,           "无极重击，力道胜太极三成",                       False, False),
    ("mie",   "【极】无极灭", "all_mofa_attack", "无极灭世群杀，湮灭全场敌对目标",              True, False),
    ("guixu", "【神】无极·归墟", None,        "无极归墟心法，全属性强化胜太极三成",             False, False),
    ("hunyuan", "【神】无极·混元", None,      "无极混元连击，三段打击胜太极三成",               False, False),
    ("wuji",  "【神】无极·无极", None,        "无极终极奥义，万物归一",                         False, False),
    ("guizhen", "【极】无极归真", None,       "无极归真，觉醒终极形态",                         False, False),
]

def scale_num(n):
    return int(math.ceil(n * MULT))

def scale_pair(pair):
    return f"({{{scale_num(pair[0])},{scale_num(pair[1])}}})"

def gen_skill(suffix, cn, type_override, desc, is_aoe, is_group_heal):
    taiji = "taiji" + suffix if suffix != "tian" and suffix != "lin" else None
    if taiji and os.path.exists(f"{OUT}/{taiji}"):
        src = open(f"{OUT}/{taiji}").read()
    else:
        # New skills (tian/lin) base on yan/yu
        base = "yan" if is_aoe else "yu"
        src = open(f"{OUT}/taiji{base}").read()

    # Replace prefix
    src = src.replace('taiji', 'wuji')
    # Replace name
    src = re.sub(r'name_cn="[^"]*"', f'name_cn="{cn}"', src)
    src = re.sub(r'desc="[^"]*"', f'desc="{desc}"', src)

    # Override type if specified
    if type_override:
        src = re.sub(r's_skill_type="[a-z_]+"',
                     f's_skill_type="{type_override}"', src)

    # Scale all numeric damage values by 1.3
    # performs_attack[N]=num
    src = re.sub(r'(performs_attack\[\d+\]=)(\d+)',
                 lambda m: f"{m.group(1)}{scale_num(int(m.group(2)))}", src)
    # performs_mofa_attack[N]=({lo,hi})
    src = re.sub(r'(performs_mofa_attack\[\d+\]=)\((\{)(\d+),(\d+)(\})\)',
                 lambda m: f"{m.group(1)}({m.group(2)}{scale_num(int(m.group(3)))},{scale_num(int(m.group(4)))}{m.group(5)})", src)
    # performs_defend[N]=num
    src = re.sub(r'(performs_defend\[\d+\]=)(\d+)',
                 lambda m: f"{m.group(1)}{scale_num(int(m.group(2)))}", src)

    # Update skill_type tag
    src = src.replace('skill_type+=({"wuji"})', 'skill_type+=({"wuji"})')

    # Update performs_desc to reflect scaled values
    # For new skills, regenerate descriptions
    if suffix in ("tian", "lin"):
        # Rewrite descriptions
        lines = src.split('\n')
        new_lines = []
        for line in lines:
            if 'performs_desc' in line:
                if is_aoe:
                    line = re.sub(r'造成(\d+)至(\d+)点',
                                  lambda m: f'造成{scale_num(int(m.group(1)))}至{scale_num(int(m.group(2)))}点',
                                  line)
                elif is_group_heal:
                    line = re.sub(r'恢复(\d+)至(\d+)点|恢复(\d+)点',
                                  lambda m: f'恢复{scale_num(int(m.group(1) or m.group(3)))}点',
                                  line)
            new_lines.append(line)
        src = '\n'.join(new_lines)

    outpath = f"{OUT}/wuji{suffix}"
    with open(outpath, 'w') as f:
        f.write(src)
    return outpath

generated = []
for suffix, cn, ty, desc, aoe, heal in SKILLS:
    path = gen_skill(suffix, cn, ty, desc, aoe, heal)
    generated.append(path)
    print(f"  ✓ wuji{suffix}")

print(f"\nGenerated {len(generated)} skill files")
