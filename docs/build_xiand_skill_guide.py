#!/usr/bin/env python3
"""Build the standalone Xiand all-profession skill handbook.

The handbook is intentionally separate from the equipment/progression guide.
It reads the current skill objects and skill-book catalog, then documents the
31 legacy mythic skills and all 70 account-bound ancient inheritances.
"""

from __future__ import annotations

import datetime as dt
import html
import re
import shutil
from collections import defaultdict
from pathlib import Path

from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import Image, PageBreak, Paragraph, Spacer, Table, TableStyle
from reportlab.platypus.tableofcontents import TableOfContents

from build_xiand_profession_guide import (
    BOTTOM_MARGIN,
    CONTENT_W,
    DOCS,
    GOLD,
    GOLD_LIGHT,
    INK,
    LEFT_MARGIN,
    LINE,
    MUTED,
    NAVY,
    PAGE_H,
    PAGE_W,
    PROFESSIONS,
    RED,
    RIGHT_MARGIN,
    ROOT,
    TEAL,
    TOP_MARGIN,
    GuideDocTemplate,
    HandbookBuilder,
    book_rows,
    build_styles,
    git_value,
    parse_books,
    parse_ancient_skills,
    parse_skills,
    mythic_runtime_cooldown,
    mythic_runtime_summary,
    register_fonts,
    skill_rows,
)


PDF_PATH = DOCS / "xiand-all-professions-skill-guide.pdf"
MD_PATH = DOCS / "xiand-all-professions-skill-guide.md"
DESKTOP_PDF_PATH = Path.home() / "Desktop" / "仙道全职业技能专册-隐藏神技详解.pdf"

MYTHIC_SKILLS = [
    {
        "profession": "jianxian",
        "id": "wanjianguizong",
        "role": "高额武器物理爆发",
        "usage": "定位为剑仙的单体决胜技，施放时必须装备主手武器。建议先以破阵剑意削弱防御，再在安全窗口集中剑势；50秒冷却决定它更适合关键目标，而不是普通怪轮流点放。",
    },
    {
        "profession": "jianxian",
        "id": "taiqingjianyu",
        "role": "20秒高额防御剑域",
        "usage": "适合在Boss爆发、多人集火或自身血线将要承压前预先开启。它提高的是防御值，不会直接回血，也不是羽士那种按额度吸收伤害的护盾。",
    },
    {
        "profession": "jianxian",
        "id": "pozhenjianyi",
        "role": "12秒高额破防",
        "usage": "适合在团队物理爆发前施放，让剑仙与物理队友共享12秒破防窗口。它削减物理防御，对主要依靠法术抗性的目标收益有限。",
    },
    {
        "profession": "yushi",
        "id": "jiutianleiyin",
        "role": "风系单体爆发",
        "usage": "定位为羽士的风系单体斩杀。先用冰魄缠身降低敌人攻频，或用太乙玄光稳住自身，再对Boss和高威胁目标释放；50秒内无法反复施放。",
    },
    {
        "profession": "yushi",
        "id": "taiyixuanguang",
        "role": "20秒高额吸收盾",
        "usage": "在敌方爆发、Boss强攻或挂机进入危险血线前开启最有价值。玄光按固定额度吸收伤害，但不会回复已经损失的生命，护盾耗尽后也不会继续减伤。",
    },
    {
        "profession": "yushi",
        "id": "bingpochanshen",
        "role": "12秒攻击减速控制",
        "usage": "通过延长目标攻击间隔降低持续承伤，适合在护盾前后衔接，为施法和走位争取时间。它不是眩晕，敌人仍能行动和攻击。",
    },
    {
        "profession": "zhuxian",
        "id": "zhutianwujie",
        "role": "高武器倍率物理爆发",
        "usage": "定位为诛仙的高倍率斩杀技，施放时必须装备主手武器。建议先开启天煞剑意，再把诛天无界放进12秒暴击窗口；不要在增益尚未开启时仓促交掉。",
    },
    {
        "profession": "zhuxian",
        "id": "tianshajianyi",
        "role": "12秒暴击强化",
        "usage": "在准备连续释放高伤技能前开启，把无影封喉和诛天无界安排进12秒窗口。它只提高暴击等级，不提供命中、减伤或必定暴击。",
    },
    {
        "profession": "zhuxian",
        "id": "wuyingfenghou",
        "role": "12秒追杀伤害",
        "usage": "适合Boss长战和残血追击，先挂上12秒持续伤害，再开启剑意并衔接爆发。持续伤害不会替代正面输出，也不能在90秒冷却内重复刷新。",
    },
    {
        "profession": "kuangyao",
        "id": "xuemoshijie",
        "role": "高固定值物理爆发",
        "usage": "定位为狂妖的正面重击，施放时必须装备主手武器。固定伤害更突出、武器倍率相对克制，适合在修罗狂意窗口内打向高血量目标。",
    },
    {
        "profession": "kuangyao",
        "id": "shurakuangyi",
        "role": "12秒物攻强化",
        "usage": "在血魔噬界和其他物理技能前开启，可在12秒内抬高人物基础物攻。狂意不提供减伤、吸血或控制，低血量时仍应先保命。",
    },
    {
        "profession": "kuangyao",
        "id": "xuehailieshang",
        "role": "12秒流血伤害",
        "usage": "先制造12秒流血，再以修罗狂意强化后续物理攻击，适合高血量目标和持久战。完整持续对普通目标约造成10.8%至14.4%最大生命真实伤害，Boss最多3%；弱持续伤害不会覆盖它。",
    },
    {
        "profession": "wuyao",
        "id": "huangquanwudu",
        "role": "毒系单体爆发",
        "usage": "定位为巫妖的毒系即时爆发。先用九幽毒瘴压制恢复、万象噬魂铺开持续伤害，再用黄泉五毒快速压低目标血线。",
    },
    {
        "profession": "wuyao",
        "id": "wanxiangshihun",
        "role": "12秒持续伤害",
        "usage": "适合长战斗与Boss战，先挂12秒持续毒伤，再补减疗和即时爆发。它不会降低治疗，也不会替代黄泉五毒的瞬间压血。",
    },
    {
        "profession": "wuyao",
        "id": "jiuyouduzhang",
        "role": "12秒治疗压制",
        "usage": "专门针对高恢复敌人、治疗队伍和Boss回复阶段。它只降低目标受到的治疗，不直接扣血；面对没有恢复能力的目标，应把法力留给伤害技能。",
    },
    {
        "profession": "yinggui",
        "id": "wuyingjuemie",
        "role": "高倍率刺杀爆发",
        "usage": "定位为影鬼的高倍率刺杀，施放时必须装备主手武器。先用六道障目压低命中、开启九幽鬼步，再抓住12秒规避窗口完成突袭。",
    },
    {
        "profession": "yinggui",
        "id": "jiuyouguibu",
        "role": "12秒闪避强化",
        "usage": "用于规避敌方集中攻击，与六道障目组合可形成短暂生存窗口。鬼步提高闪避等级，但并非无敌，面对高闪避穿透的主动物理技能和固定效果仍需谨慎。",
    },
    {
        "profession": "yinggui",
        "id": "liudaozhangmu",
        "role": "12秒命中压制",
        "usage": "降低目标命中，可同时保护自己和正在承伤的队友。面对法术必中、固定效果或不依赖命中的能力时收益有限，也不会直接降低敌人伤害数值。",
    },
    {
        "profession": "fangshi",
        "id": "taixulingyun",
        "role": "风系单体爆发",
        "usage": "补足召唤与治疗方士的主动爆发，适合在虎灵进攻或三灵共鸣形成安全窗口后使用。它只攻击当前目标，不会替代灵兽的持续作战。",
    },
    {
        "profession": "fangshi",
        "id": "wanlingchaosheng",
        "role": "同房间队伍大治疗",
        "usage": "施放时必定治疗自己；有队伍时，只额外治疗同房间且仍存活的队友。未组队时就是强力自疗，离开房间的队员和死亡角色都不会被治疗。",
    },
    {
        "profession": "fangshi",
        "id": "sixiangfengjin",
        "role": "12秒物攻压制",
        "usage": "针对物理Boss和高攻玩家，制造12秒减攻保护窗口。它降低的是物理攻击，对纯法术目标收益较低，也不会让目标停止行动。",
    },
    {
        "profession": "zhenyue",
        "id": "wanshanchaogong",
        "role": "15秒同房队伍巨盾",
        "usage": "适合在Boss爆发或队伍血线危险前预先展开。它只保护施法者与同房间、同队伍、存活成员，使用独立守护槽，不覆盖其他职业增益；额度耗尽或到时立即结束。",
    },
    {
        "profession": "zhenyue",
        "id": "buzhouzhenji",
        "role": "600%仇恨物理重击",
        "usage": "用于建立长期首仇并补充坦克输出。高仇恨倍率并不等于六倍最终伤害，仍需有效目标、法力、主手武器和冷却；死亡或离房目标不参与仇恨比较。",
    },
    {
        "profession": "zhenyue",
        "id": "tiandichengbi",
        "role": "18秒可耗尽个人巨盾",
        "usage": "用于坦克自己承接高压阶段。它吸收的是有限额度伤害，不回复已经损失的生命，也不提供无敌、复活或永久反射；应与队伍盾错峰使用。",
    },
    {
        "profession": "tianxiang",
        "id": "xinghezhuiluo",
        "role": "消耗星痕的火系爆发",
        "usage": "定位为天象的隐藏决胜技，第一段基础伤害3000至3800。它消耗至多三层服务端星痕；普通PVE每层提高10%，玩家和Boss每层提高8%。50秒冷却和十五秒星痕时限要求先积蓄、再选择安全窗口引爆。",
    },
    {
        "profession": "tianxiang",
        "id": "zhoutianjingzhi",
        "role": "8秒命中压制控制",
        "usage": "第一段在8秒内降低18点命中，适合覆盖敌方爆发窗口。效果需要通过控制命中与抵抗判定，不永久叠加，也不会让目标完全停止行动；90秒冷却要求谨慎选择目标。",
    },
    {
        "profession": "tianxiang",
        "id": "wanxiangxingbi",
        "role": "15秒可耗尽个人星壁",
        "usage": "第一段吸收3800+智力×3点伤害，并至少形成8%最大生命护盾，用于给积蓄星痕争取时间。它只有有限额度与15秒时限，不回血、不复活、不免疫；75秒冷却决定它不能覆盖每轮普通战斗。",
    },
    {
        "profession": "lingyi",
        "id": "cixinpudu",
        "role": "同房同队大治疗",
        "usage": "用于队伍多人同时掉血的高压窗口。它只治疗施法者与同房间、同逻辑区、同队伍的存活人物，单目标最多恢复其25%生命上限；未组队时就是有上限的强力自疗，不治疗路人也不复活。",
    },
    {
        "profession": "lingyi",
        "id": "huimingtianlu",
        "role": "药契强化智能急救",
        "usage": "自动选择合法目标中生命比例最低者，并消耗全部药契；每层药契提高15%治疗，最多三层，最终单次治疗仍不超过目标40%生命上限。适合先以普通治疗积契，再救治濒危队友。",
    },
    {
        "profession": "lingyi",
        "id": "wanmuxinchun",
        "role": "群体治疗与逐人净化",
        "usage": "治疗同房同队存活人物并为每名受益目标净化一项负面状态，优先持续伤害，再处理减疗/诅咒、控制与70级诅咒。每名目标治疗上限25%，75秒冷却要求留给复杂团队危机。",
    },
    {
        "profession": "lingyi",
        "id": "liuhehuichun",
        "role": "药契强化全队治疗与净化",
        "usage": "治疗自己与同房、同逻辑区、同队的全部存活队友，并为每人净化一项负面状态。施放时消耗全部药契，每层增强15%，每人单次最高恢复35%生命；75秒冷却使它成为团队危机的压轴手段。",
    },
    {
        "profession": "wuxiang",
        "id": "wuxiangguixu",
        "role": "无相心法极效·短时全属性爆发",
        "usage": "主动激发心法，使无相获得最高项 50% 加成其他两系的额外效果叠加到 60%；适合 Boss 关键阶段爆发。120 秒冷却确保它只在战斗高潮使用。",
    },
    {
        "profession": "wuxiang",
        "id": "wuxianghunyuan",
        "role": "双倍暴击物理连击",
        "usage": "无相版连击强化，单段伤害低于剑仙的剑意类爆发但附带双倍暴击概率；80 级解锁后可在常规轮转中作为爆发技能。",
    },
    {
        "profession": "wuxiang",
        "id": "wuxiangwuji",
        "role": "群体回血 + 净化",
        "usage": "覆盖同房同队的回血并附带按优先级解一项负面；治疗强度低于灵医的六合回春但胜在无相单角色补位万金油。",
    },
]

MYTHIC_THEMES = {
    "jianxian": "剑域攻守",
    "yushi": "雷霆护法",
    "zhuxian": "剑煞斩杀",
    "kuangyao": "血战修罗",
    "wuyao": "黄泉毒御",
    "yinggui": "鬼步绝杀",
    "fangshi": "三灵济世",
    "zhenyue": "万山守御",
    "tianxiang": "万象星轨",
    "lingyi": "百草回春",
    "wuxiang": "无相万象",
}

PROF_BY_ID = {item["id"]: item for item in PROFESSIONS}


def parse_mythic_details() -> list[dict[str, object]]:
    """Read all mythic skill files and preserve their five exact stages."""
    result: list[dict[str, object]] = []
    for config in MYTHIC_SKILLS:
        skill_id = str(config["id"])
        source = (ROOT / "gamelib/single/skills" / skill_id).read_text(
            encoding="utf-8"
        )
        name_match = re.search(r'name_cn\s*=\s*"([^"]+)"', source)
        desc_match = re.search(r'desc\s*=\s*"([^"]+)"', source)
        cooldown_match = re.search(r"s_delayTime\s*=\s*(\d+)", source)
        type_match = re.search(r's_skill_type\s*=\s*"([^"]+)"', source)
        curse_match = re.search(r's_curse_type\s*=\s*"([^"]+)"', source)
        skill_type = type_match.group(1) if type_match else ""
        curse_type = curse_match.group(1) if curse_match else ""
        raw_cooldown = int(cooldown_match.group(1)) if cooldown_match else 0
        cooldown = mythic_runtime_cooldown(skill_type, raw_cooldown)
        stage_rows: list[list[str]] = []
        for stage in range(1, 6):
            level_match = re.search(
                rf"performs_level_limit\[{stage}\]\s*=\s*(\d+)", source
            )
            stage_match = re.search(
                rf'performs_desc\[{stage}\]\s*=\s*"([^"]+)"', source
            )
            if not level_match or not stage_match:
                raise RuntimeError(f"Missing stage {stage} in mythic skill {skill_id}")
            stage_desc = stage_match.group(1)
            if skill_type == "phy" or skill_type not in {
                "dot", "curse", "buff", "heal", "taunt", "team_guard"
            }:
                stage_desc += f"；总攻势按{135 + stage * 5}%结算"
            elif skill_type == "dot" and skill_id != "xuehailieshang":
                stage_desc += f"；每节拍至少继承{5 + stage}%自身攻势，玩家与首领有封顶"
            elif skill_type in {"heal", "team_guard"} or (
                skill_type == "buff" and curse_type == "absorb"
            ):
                stage_desc += f"；高属性时至少按生命上限{6 + stage * 2}%生效"
            elif skill_type in {"buff", "curse"} and curse_type in {"attack", "defend"}:
                stage_desc += f"；高属性时至少影响当前属性{18 + stage * 4}%"
            stage_rows.append([str(stage), level_match.group(1), stage_desc])
        result.append(
            {
                **config,
                "name": name_match.group(1) if name_match else skill_id,
                "desc": desc_match.group(1) if desc_match else "",
                "cooldown": cooldown,
                "runtime": mythic_runtime_summary(skill_type, curse_type, skill_id),
                "stages": stage_rows,
            }
        )
    return result


class SkillGuideDocTemplate(GuideDocTemplate):
    def _on_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("仙道全职业技能专册")
        canvas.setAuthor("Xiand Project")
        if doc.page > 1:
            canvas.setStrokeColor(LINE)
            canvas.setLineWidth(0.4)
            canvas.line(
                LEFT_MARGIN,
                PAGE_H - 11 * mm,
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 11 * mm,
            )
            canvas.setFont("XiandBody", 7.5)
            canvas.setFillColor(MUTED)
            canvas.drawString(
                LEFT_MARGIN, PAGE_H - 8.5 * mm, "仙道全职业技能专册"
            )
            canvas.drawRightString(
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 8.5 * mm,
                "一百零一式隐藏传承详解",
            )
            canvas.line(LEFT_MARGIN, 10 * mm, PAGE_W - RIGHT_MARGIN, 10 * mm)
            canvas.drawCentredString(PAGE_W / 2, 6.5 * mm, f"- {doc.page} -")
        canvas.restoreState()


def add_cover(
    story: list,
    guide: HandbookBuilder,
    styles: dict[str, ParagraphStyle],
    branch: str,
    commit: str,
    build_date: str,
    skill_count: int,
    book_count: int,
) -> None:
    story.append(Spacer(1, 16 * mm))
    icon_paths = [
        ROOT / "images/human_yushi_male.png",
        ROOT / "images/human_fangshi_logo.png",
        ROOT / "images/zhenyue_logo.png",
        ROOT / "images/tianxiang_logo.png",
        ROOT / "images/lingyi_logo.png",
        ROOT / "images/wuxiang_logo.png",
    ]
    icon_table = Table(
        [[Image(str(path), width=24 * mm, height=24 * mm) for path in icon_paths]],
        colWidths=[24 * mm] * 5,
        hAlign="CENTER",
    )
    icon_table.setStyle(
        TableStyle(
            [
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2 * mm),
            ]
        )
    )
    story.extend([icon_table, Spacer(1, 8 * mm)])
    story.append(Paragraph("仙道全职业技能专册", styles["CoverTitle"]))
    story.append(
        Paragraph(
			f"十职业技能全索引 · 31式旧世神技 + 70式太古传承 · {build_date}版",
            styles["CoverSub"],
        )
    )
    story.append(Spacer(1, 10 * mm))
    cover_box = Table(
        [
            [
                Paragraph(
                    f"当前代码共收录 {skill_count} 个职业技能对象、{book_count} 条职业技能书配置。<br/>"
                    "从技能书获得、背包学习，到熟练度成长与实战连招，一册查清。<br/>"
                    "旧池保留31本可流通神技；新池每职业7本，共70本拾取即账号绑定的太古传承。<br/>"
                    "等级、法力、伤害、治疗、控制时长与冷却均取自当前技能对象。",
                    ParagraphStyle(
                        "SkillCoverBox",
                        parent=styles["Body"],
                        fontName="XiandBold",
                        fontSize=10,
                        leading=17,
                        alignment=TA_CENTER,
                        textColor=INK,
                    ),
                )
            ]
        ],
        colWidths=[145 * mm],
        hAlign="CENTER",
    )
    cover_box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), GOLD_LIGHT),
                ("BOX", (0, 0), (-1, -1), 1.0, GOLD),
                ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
                ("LEFTPADDING", (0, 0), (-1, -1), 6 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6 * mm),
            ]
        )
    )
    story.extend([cover_box, Spacer(1, 17 * mm)])
    story.append(
        Paragraph(
            f"分支：{html.escape(branch)}　提交基线：{html.escape(commit)}　生成日期：{build_date}",
            ParagraphStyle(
                "SkillCoverMeta",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=MUTED,
            ),
        )
    )
    story.append(
        Paragraph(
            "说明：技能书每日轮换、库存与活动价格可能调整，以服务器实时界面为准；技能效果以本文生成时的代码为准。",
            ParagraphStyle(
                "SkillCoverNote",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=RED,
            ),
        )
    )
    guide.md.extend(
        [
            "# 仙道全职业技能专册",
            "",
			f"十职业技能全索引 · 31式旧世神技 + 70式太古传承 · {build_date}版",
            "",
            f"- 分支：`{branch}`",
            f"- 提交基线：`{commit}`",
            f"- 生成日期：{build_date}",
            f"- 数据规模：{skill_count} 个职业技能对象，{book_count} 条职业技能书配置",
            "",
            "> 本专册依据当前仓库代码生成：旧池31本保持可流通；新池每职业7本，共70本拾取即账号绑定。",
            "",
        ]
    )
    guide.pagebreak()


def add_toc(story: list, styles: dict[str, ParagraphStyle]) -> None:
    story.append(Paragraph("目录", styles["H1"]))
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle(
            "SkillTOC1",
            fontName="XiandBold",
            fontSize=9.5,
            leading=15,
            textColor=NAVY,
            spaceAfter=1.5 * mm,
        ),
        ParagraphStyle(
            "SkillTOC2",
            fontName="XiandBody",
            fontSize=8.3,
            leading=12,
            leftIndent=6 * mm,
            textColor=INK,
            spaceAfter=0.8 * mm,
        ),
    ]
    story.extend([toc, PageBreak()])


def build_skill_guide() -> None:
    register_fonts()
    styles = build_styles()
    books = parse_books()
    skills = parse_skills()
    mythics = parse_mythic_details()
    ancients = parse_ancient_skills()
    books_by_prof: dict[str, list[dict[str, object]]] = defaultdict(list)
    skills_by_prof: dict[str, list[dict[str, object]]] = defaultdict(list)
    mythics_by_prof: dict[str, list[dict[str, object]]] = defaultdict(list)
    for book in books:
        books_by_prof[str(book["profession"])].append(book)
    for skill in skills:
        skills_by_prof[str(skill["profession"])].append(skill)
    for mythic in mythics:
        mythics_by_prof[str(mythic["profession"])].append(mythic)

    branch = git_value("rev-parse", "--abbrev-ref", "HEAD")
    commit = git_value("rev-parse", "--short=10", "HEAD")
    build_date = dt.date.today().isoformat()
    doc = SkillGuideDocTemplate(
        str(PDF_PATH),
        styles,
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="仙道全职业技能专册",
        author="Xiand Project",
    )
    story: list = []
    guide = HandbookBuilder(story, styles)

    add_cover(
        story,
        guide,
        styles,
        branch,
        commit,
        build_date,
        len(skills),
        len(books) + len(mythics) + len(ancients),
    )
    add_toc(story, styles)

    guide.h1("1. 技能学习与成长规则")
    guide.callout(
        "买到技能书不等于学会",
        "购买或捡到技能书后，必须打开背包，找到对应书并点击“学习”。系统会在读取时检查人物等级和职业；成功后才能在技能列表中看到并使用。",
    )
    guide.table(
        ["步骤", "玩家动作", "系统检查", "结果"],
        [
            ["1. 获得书", "商店购买、任务奖励或怪物掉落", "背包容量与物品归属", "技能书进入背包或落在地面"],
            ["2. 点击学习", "背包中点击技能书的“学习”", "人物等级、职业、是否已学", "通过后写入人物技能"],
            ["3. 主动使用", "在技能列表中点击技能", "法力、冷却、目标与战斗状态", "执行伤害、治疗、控制或增益"],
            ["4. 提升阶段", "持续实战积累熟练度", "下一阶段人物等级门槛", "技能阶段提升并解锁更高数值"],
        ],
        [0.8, 1.6, 1.7, 1.65],
    )
    guide.bullets(
        [
            "普通技能书主要在职业技能书商店购买；60级以上高级书按职业每天独立轮换2本。",
            "方士、镇越、天象与灵医多数技能配置5段；老职业很多技能保留10段，但以技能对象实际配置为准。",
            "旧31本隐藏大神技能只需获得并成功学习1本，后续80/100/120/140/160级阶段依靠熟练度成长。",
            "旧隐藏书可继续交易、寄送或存入仓库；新70本太古书拾取即账号绑定，禁止所有跨人物流通。",
        ]
    )
    guide.callout(
        "技能与职业助手公平边界",
        "方士、镇越、天象和灵医的学习、手动技能、召唤、治疗、嘲讽、护盾、星痕与药契循环永久免费。VIP职业助手只在PVE自动执行人物已经掌握的能力，照常检查法力、冷却、装备、目标和行动回合；面对玩家或玩家召唤物会拒绝自动施放。会员到期只暂停自动化，不删除技能或策略配置。",
    )
    guide.callout(
        "拿到隐藏书后的最短路径",
        "先确认人物达到80级且职业匹配 -> 在背包点击“学习” -> 到技能列表确认第一段 -> 准备主手武器、目标和法力 -> 实战积累熟练度，并在100/120/140/160级继续提升阶段。",
        "gold",
    )

    guide.h1("2. 十职业技能定位速览")
    guide.h2("2.1 物理、法术与概率结算基线")
    guide.table(
        ["项目", "当前规则", "实战含义"],
        [
            ["物理伤害", "A² / (A + 有效防御)；主动物理技通常在结算后×1.5", "物攻越高越能对抗高防御，但仍受防御和穿透影响"],
            ["法术伤害", "A × 400 / (400 + 有效抗性)", "法伤稳定，法抗不会再以线性相减制造异常极值"],
            ["物理/法术穿透", "作为独立无视防御伤害，单次最多取原始攻击的60%", "高防御下仍能稳定输出，但极端旧装备数值不会无限放大"],
            ["命中/闪避", "普通命中最高99%，闪避最高75%", "双方始终保留小概率反转空间"],
            ["闪避穿透", "普攻最高40%，主动物理技能最高60%", "60%是穿透上限，不是60%必中，更不是绝对必中"],
            ["暴击/韧性", "暴击基础150%；韧性只削减额外50%部分", "暴击伤害最低等于该次未暴击伤害"],
        ],
        [1.0, 2.8, 2.4],
        compact=True,
    )
    guide.callout(
        "平衡调整原则",
        "物理系通过递减防御、主动物理技能加成和分档闪避穿透改善高属性版本体验；法系继续受抗性公式制约。旧31式神技已统一接入总攻势倍率、最大生命保底或当前属性百分比，并保留PVP/Boss硬上限；没有采用无条件必中或无限比例伤害。",
        "gold",
    )
    guide.h2("2.2 十职业定位与隐藏传承")
    overview_rows = []
    for profession in PROFESSIONS:
        profession_id = profession["id"]
        hidden_names = " / ".join(
            str(item["name"]) for item in mythics_by_prof[profession_id]
        )
        if not hidden_names:
            hidden_names = "当前无隐藏大神书"
        overview_rows.append(
            [
                profession["name"],
                profession["faction"],
                profession["role"],
                profession["identity"],
                hidden_names,
            ]
        )
    guide.table(
        ["职业", "阵营", "定位", "技能特色", "隐藏大神传承"],
        overview_rows,
        [0.65, 0.65, 1.35, 2.3, 1.65],
        compact=True,
    )
    guide.callout(
        "十脉神传，各有胜场",
        "剑仙重攻守转换，羽士重控制与护盾，诛仙重暴击斩杀，狂妖重流血强攻，巫妖重毒伤减疗，影鬼重命中博弈，方士重召唤治疗，镇越重仇恨与队伍守护，天象重元素星痕与受控引爆，灵医重智能救急、群疗净化与药契节奏。十套传承使用相同的获得与成长门槛，但战斗解法互不相同。",
        "gold",
    )

    guide.h1("3. 十职业技能与技能书全索引")
    guide.paragraph(
        "下列内容由当前技能对象与技能书目录自动生成。普通书显示商店价格，高级书显示每日职业轮换；隐藏书不进入任何商店，因此只出现在技能对象与隐藏神技章节。",
        small=True,
    )
    for index, profession in enumerate(PROFESSIONS, start=1):
        profession_id = str(profession["id"])
        guide.h2(f"3.{index} {profession['name']}技能路线")
        guide.callout(
            f"{profession['name']}定位",
            f"{profession['role']}。{profession['identity']}",
        )
        normal_books = book_rows(books_by_prof[profession_id], advanced=False)
        advanced_books = book_rows(books_by_prof[profession_id], advanced=True)
        if normal_books:
            guide.h3("普通技能书")
            guide.table(
                ["等级", "技能书", "书ID", "价格", "入口"],
                normal_books,
                [0.55, 1.4, 1.35, 1.2, 1.25],
                compact=True,
            )
        if advanced_books:
            guide.h3("60级以上每日轮换书")
            guide.table(
                ["等级", "技能书", "书ID", "价格", "入口"],
                advanced_books,
                [0.55, 1.4, 1.35, 1.2, 1.25],
                compact=True,
            )
        guide.h3("技能对象全表")
        guide.table(
            ["技能 / ID", "形态", "类型", "等级阶段", "冷却", "效果摘要"],
            skill_rows(skills_by_prof[profession_id]),
            [1.35, 0.48, 0.8, 1.0, 0.62, 2.05],
            compact=True,
        )
        if profession_id in mythics_by_prof:
            hidden_count = len(mythics_by_prof[profession_id])
            guide.paragraph(
                f"本职业的{hidden_count}本隐藏大神书不在上述商店表中，完整阶段数值见第4章。",
                small=True,
            )

    guide.h1("4. 三十一式隐藏神技实战全解")
    guide.h2("4.1 掉落、归属与学习规则")
    guide.table(
        ["规则项", "当前实现"],
        [
            ["资格怪物", "被击杀怪物的实际等级必须达到70级；不看玩家等级或地图名称"],
            ["总掉率", "每只合格怪物31/100000；命中后从31本中等概率选1本"],
            ["单本长期均值", "约1/100000；短期可能长期不出，也可能连续掉落"],
            ["掷骰次数", "单人、团队普通怪、团队Boss均按每只怪物恰好掷1次；队员人数不放大掉率"],
            ["商店限制", "31本均不进入普通书商店、每日高级书商店或师门教学"],
            ["地面归属", "个人或队伍保护120秒；未拾取物品5分钟后清理"],
            ["流通", "允许拾取、丢弃、交易、寄送与仓库存放；学习时才严格检查职业"],
            ["学习要求", "人物80级且职业匹配；重复学习不消耗书"],
            ["审计", "每次成功掉落写入 log/hidden_skill_drop.log"],
        ],
        [1.05, 4.4],
    )
    guide.callout(
        "概率换算",
        "31本共享31/100000总掉率，不是每本都按31/100000独立判断。因为命中后三十一选一，所以单本长期平均仍约为1/100000。",
        "gold",
    )

    guide.h2("4.2 三十一本神技横向比较")
    guide.table(
        ["职业", "技能", "定位", "冷却", "80级第一段", "160级第五段"],
        [
            [
                PROF_BY_ID[str(item["profession"])]["name"],
                item["name"],
                item["role"],
                f"{item['cooldown']}秒",
                item["stages"][0][2],
                item["stages"][4][2],
            ]
            for item in mythics
        ],
        [0.55, 0.95, 1.1, 0.58, 2.0, 2.0],
        compact=True,
    )

    section_number = 3
    for profession_id in [
        "jianxian", "yushi", "zhuxian", "kuangyao", "wuyao", "yinggui", "fangshi", "zhenyue", "tianxiang", "lingyi"
    ]:
        profession = PROF_BY_ID[profession_id]
        skill_count_cn = "四" if profession_id == "lingyi" else "三"
        if profession_id == "wuxiang":
            skill_count_cn = "三"
        guide.h2(
            f"4.{section_number} {profession['name']}{skill_count_cn}大神技 - {MYTHIC_THEMES[profession_id]}"
        )
        for mythic in mythics_by_prof[profession_id]:
            guide.h3(f"{mythic['name']} ({mythic['id']})")
            guide.paragraph(f"{mythic['desc']}。{mythic['usage']}")
            guide.table(
                ["技能阶段", "人物等级门槛", "该阶段实际效果"],
                mythic["stages"],
                [0.8, 1.15, 4.0],
            )
            guide.paragraph(
                f"实战冷却：{mythic['cooldown']}秒。{mythic['runtime']}。学习书要求：人物80级、职业为{profession['name']}。",
                small=True,
            )
        if profession_id == "jianxian":
            guide.callout(
                "剑仙推荐循环",
                "破阵剑意降低敌人防御 -> 太清剑域覆盖危险窗口 -> 万剑归宗集中爆发。剑域提高的是防御，不等同于羽士的伤害吸收盾。",
            )
        elif profession_id == "yushi":
            guide.callout(
                "羽士推荐循环",
                "冰魄缠身降低敌人攻击频率 -> 太乙玄光覆盖危险窗口 -> 九天雷引完成爆发。三技分别负责控制、生存和输出，不会把羽士变成无冷却炮台。",
            )
        elif profession_id == "zhuxian":
            guide.callout(
                "诛仙推荐循环",
                "无影封喉先挂持续伤害 -> 天煞剑意开启暴击窗口 -> 诛天无界完成斩杀。三技都偏进攻，需自行把握生存位置。",
            )
        elif profession_id == "kuangyao":
            guide.callout(
                "狂妖推荐循环",
                "血海裂伤先制造流血 -> 修罗狂意提高物攻 -> 血魔噬界正面重击。狂意不提供防御，低血量时不要强行贪完整连招。",
            )
            guide.callout(
                "狂妖最新精确边界",
                "致残重伤保留旧固定伤害下限，并按狂妖自身最大生命成长，十段完整持续约为2%至5%；普通怪、玩家、Boss的目标生命保护上限分别为10%、5%、2.5%。血海裂伤整段对普通目标约为目标最大生命10.8%至14.4%，Boss最多3%。持续伤害不叠加，按剩余总伤害保留更强效果。",
                "gold",
            )
        elif profession_id == "wuyao":
            guide.callout(
                "巫妖推荐循环",
                "九幽毒瘴压制治疗 -> 万象噬魂挂12秒持续伤害 -> 黄泉五毒补即时爆发。面对无治疗目标时，可把减疗留给更关键的回复阶段。",
            )
        elif profession_id == "yinggui":
            guide.callout(
                "影鬼推荐循环",
                "六道障目降低敌人命中 -> 九幽鬼步提高自身闪避 -> 无影绝灭抓住窗口刺杀。双重规避仍不是绝对免伤。",
            )
        elif profession_id == "fangshi":
            guide.callout(
                "方士推荐循环",
                "物理强敌先用四象封禁减攻；队伍掉血时用万灵朝生；安全窗口用太虚灵陨补爆发。治疗、控制与输出不能在同一冷却里反复使用。",
            )
        elif profession_id == "zhenyue":
            guide.callout(
                "镇越推荐循环",
                "敌人未以自己为首要目标时先用地震吼或高仇恨攻击；队伍将承压时展开万山朝拱；自己的危险窗口再开天地成壁，并用不周震击维持长期仇恨。护盾必须错峰，不能当作治疗或无敌。",
            )
        elif profession_id == "tianxiang":
            guide.callout(
                "天象推荐循环",
                "先用周天静止压低危险目标命中，或用万象星壁覆盖积蓄窗口；交替施放已学火、冰、风攻击法术积至三星，再用星河坠落引爆。星痕最多三层、十五秒到期，换房、脱战、死亡和掉线都会清空。",
            )
        else:
            guide.callout(
                "灵医推荐循环",
                "先以回春、清心、灵愈或甘霖维持队伍并凝成至多三层药契；危急单体用回命天露急救，多人同时受伤用慈心普渡，复合危机以六合回春消耗药契全队治疗净化。药雾天罗的仙、妖、中立玩家目标可在百草助手分别开关，队友好友与路人仍永久保护。",
            )
        section_number += 1

    guide.h2("4.13 旧隐藏书常见问题")
    guide.table(
        ["问题", "答案"],
        [
            ["70级玩家为什么没掉？", "资格看怪物实际等级70+，而且单本长期均值仅约1/100000；达到资格不等于必掉。"],
            ["物理神技为什么点了没伤害？", "剑仙、诛仙、狂妖、影鬼、镇越的物理神技必须先装备主手武器。"],
            ["别的职业捡到怎么办？", "可以交易、寄送或存仓库，但不能跨职业学习。"],
            ["为什么80级只看到第一段？", "一本书负责解锁技能；后续阶段仍需熟练度和100/120/140/160级门槛。"],
            ["重复点击会吞书吗？", "已经学会时不会消耗隐藏书。"],
            ["组队人数越多越容易掉吗？", "不会。每只合格怪物只掷1次隐藏掉落，队员人数不会放大概率。"],
            ["书掉在地上能放多久？", "个人或队伍享有120秒归属保护；无人拾取时，物品会在5分钟后清理。"],
            ["万灵朝生没组队会怎样？", "只治疗施法者自己；不会治疗路人，也不会复活死亡队友。"],
            ["九幽毒瘴会直接扣血吗？", "不会，它降低目标受到的治疗；直接伤害由黄泉五毒和万象噬魂承担。"],
            ["太乙玄光是回血吗？", "不是，它在20秒内提供固定额度的伤害吸收盾。"],
            ["主动物理技能现在必中吗？", "不是。技能跳过普攻命中判定，但仍可能被闪避；闪避穿透最高60%，保留反制空间。"],
            ["修罗狂意是攻击翻4.8倍吗？", "不是。五段分别提高20%/30%/40%/50%/60%总物攻，持续12秒。"],
            ["血海裂伤12秒会掉24%吗？", "不会。普通目标整段约10.8%-14.4%，Boss整段最多约3%，冷却90秒。"],
            ["多个持续伤害可以叠加吗？", "不能。目标仍只有一个持续伤害槽；系统比较剩余总伤害，弱效果不能覆盖强效果，等强效果可以刷新。"],
            ["万山朝拱会覆盖队友Buff吗？", "不会。它使用独立队伍守护槽，只保护同房间存活队友；弱盾也不会覆盖剩余值更高的强盾。"],
            ["不周震击是六倍伤害吗？", "不是。600%是仇恨倍率，伤害仍按技能附加值、武器、攻击、防御和穿透正常结算。"],
            ["天地成壁是无敌吗？", "不是。它只有固定吸收额度和18秒时限，额度耗尽后剩余伤害照常生效。"],
            ["天象星痕可以一直存着吗？", "不能。最多3层、15秒；换房、脱战、死亡或掉线都会清空，客户端也不能伪造层数。"],
            ["星河坠落三层就是固定加30%吗？", "普通PVE每层+10%、三层+30%；玩家和Boss每层+8%、三层最多+24%。"],
            ["周天静止能让目标完全不动吗？", "不能。它只在8秒内降低命中，仍需控制命中/抵抗判定，且有90秒冷却。"],
            ["灵医隐藏群疗会治疗路人吗？", "不会。只治疗自己与同房、同逻辑区、同队伍的存活人物；未组队时只治疗自己。"],
            ["回命天露会无限抬血吗？", "不会。药契最多3层、每层+15%，并且单次治疗最高不超过目标40%生命上限。"],
            ["万木新春一次会清掉所有状态吗？", "不会。每名合法目标每次只按优先级净化一项负面状态。"],
            ["六合回春会治疗全图吗？", "不会。只治疗自己和同房、同逻辑区、同队存活队友，消耗全部药契，单人上限35%。"],
            ["药雾天罗会伤害队友或路人吗？", "不会。队友、好友、同账号角色及其召唤物始终排除；仙、妖、中立玩家可分别开关，PVP仍只命中已参战目标。"],
            ["百炼复苏的“5个100级技能”怎么算？", "灵医技能为五段制，第五段就是100%掌握。任意5/8/12门白名单技能满段，每日自动复苏次数为1/2/3。"],
        ],
        [1.7, 4.0],
    )

    guide.h1("5. 七十式太古绑定传承")
    guide.callout(
        "十职业各七式，越强越稀有",
        "太古传承使用独立掉落池：实际等级90级以上怪物才有资格；70式总权重390、分母125000000，总概率约为旧31本隐藏池的1/100。七个品阶权重依次为12/9/7/5/3/2/1。",
        "gold",
    )
    guide.table(
        ["职业", "太古传承", "品阶色", "技能类型", "固定冷却"],
        [
            [
                PROF_BY_ID[str(item["profession"])]["name"],
                f'{item["name"]} ({item["id"]})',
                str(item["tier_color"]),
                str(item["type"]),
                f'{item["cooldown"]}秒',
            ]
            for item in ancients
        ],
        [0.55, 2.0, 0.55, 1.0, 0.65],
        compact=True,
    )
    guide.table(
        ["规则", "太古传承实现"],
        [
            ["拾取归属", "首次拾取绑定注册账号；已绑定书不能由其他账号拾取"],
            ["禁止流通", "不可丢弃、交易、赠送、个人仓库存放或共享宝库存放"],
            ["学习门槛", "人物90级且职业匹配；阶段门槛90/115/140/165/190"],
            ["视觉标记", "技能名按品阶使用七种特殊色；施放时播放太古专属动画"],
            ["同房可见", "人物和灵宠释放技能都会向同房、同逻辑区可见玩家广播UI显化；广播不改变战斗数值"],
            ["兼容旧池", "旧31本隐藏书的掉率、交易、寄送、仓库和学习规则完全不变"],
        ],
        [1.0, 4.5],
    )

    guide.h1("6. 灵宠天生技能与主人技能拓印")
    guide.table(
        ["技能类型", "获得与使用", "材料与安全边界"],
        [
            ["天生技能", "每种山海异兽获得时自带守护、疗愈、强攻、灵息或迅捷定位的专属技能", "不掉技能书；灵纹组用1灵纹符按确定顺序轮换，不会随机洗坏"],
            ["主人技能拓印", "宠物20级并穿灵核后，可从当前角色已学的主动攻击或治疗技能中选一项", "首次免费；替换旧拓印消耗1灵纹符；被动、管理、路径类技能不可学"],
            ["战斗结算", "拓印改变宠物协战的攻击或治疗表现，战斗小窗显示“拓印·技能名”", "只复用技能名与攻击/治疗定位；数值按宠物属性、冷却和PVE/PVP硬上限重算"],
            ["鸾鸟·回生羽", "隐藏鸾鸟协战时，主人真正死亡前自动复活，恢复15%生命与10%法力", "账号每日1次；灵医复苏优先；切磋/自杀/跨房/禁战不消耗；不能通过拓印或合成复制"],
            ["灵纹符来源", "每周平复3次万灵裂隙后，三选一奖励可领2枚灵纹符", "不在普通怪物技能书池掉落；更换前会服务端再次校验宠物、灵核和材料"],
        ],
        [1.0, 3.0, 2.0],
        compact=True,
    )
    guide.callout(
        "灵核与遗忘",
        "灵核承载当前拓印；已有拓印时不能直接卸下灵核。先遗忘拓印技能，才能更换或卸下灵核。",
        "gold",
    )

    guide.h1("7. 数据来源与版本声明")
    guide.bullets(
        [
            "职业技能对象与五段数值：gamelib/single/skills/",
            "普通与每日轮换技能书：gamelib/data/can_buy_book_list.csv",
            "隐藏书物品及学习限制：gamelib/clone/item/book/",
            "隐藏书掉落池与概率：gamelib/single/daemons/itemsd.pike",
            "太古技能目录、品阶与独立掉率：gamelib/single/daemons/ancient_skilld.pike",
            "太古书绑定与禁流通：gamelib/inherit/ancient_hidden_book.pike",
            "单人、团队与Boss掉落归属：gamelib/inherit/npc.pike",
            "技能学习与重复书处理：lowlib/mudlib/inherit/feature/readed.pike",
            "技能实战与熟练度：lowlib/wapmud2/inherit/feature/fight.pike",
            "命中、闪避与暴击边界：lowlib/mudlib/inherit/feature/char.pike",
            "物理/法术平衡回归：test_unit/test_combat_balance.pike",
            "隐藏技能运行时回归：test_unit/test_hidden_mythic_skills.pike",
            "太古70技能与经济安全回归：test_unit/test_ancient_hidden_skills.pike、test_unit/test_rare_economy_safety.pike",
            "方士/镇越/天象/灵医职业助手：gamelib/single/daemons/professionvipd.pike、gamelib/cmds/profession_assistant.pike",
            "职业助手公平边界回归：test_unit/test_profession_vip_assistant.pike",
            "天象星痕、技能与共享系统回归：test_unit/test_tianxiang_profession.pike",
            "灵医治疗、净化、药契、药雾群攻、百炼复苏与共享系统回归：test_unit/test_lingyi_profession.pike",
            "灵宠经验、装备、灵核拓印与PVP压缩：gamelib/single/daemons/_pet_mod/ 与test_unit/test_shanhai_pet_system.pike",
            "Vue真实操作与发呆时钟边界：test_unit/test_idle_kick_system.pike",
        ]
    )
    guide.callout(
        "版本声明",
        f"本文生成于{build_date}，分支{branch}，提交基线{commit}。若后续技能数值或掉率发生调整，请重新运行 docs/build_xiand_skill_guide.py 生成专册。",
        "gold",
    )

    MD_PATH.write_text("\n".join(guide.md).rstrip() + "\n", encoding="utf-8")
    doc.multiBuild(story)
    DESKTOP_PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PDF_PATH, DESKTOP_PDF_PATH)


if __name__ == "__main__":
    build_skill_guide()
