#!/usr/bin/env python3
"""Build the standalone Xiand team-composition PvE boss guide.

Covers: hardmode bosses (归墟魔君 / 万象妖皇), threat mechanics, team
composition, trial merit exchange, and failure/retry flow.
"""

from __future__ import annotations

import datetime as dt
import os
import subprocess
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents

from build_xiand_profession_guide import (
    GOLD,
    GuideDocTemplate,
    NAVY,
    RED,
    register_fonts,
    ROOT,
    TEAL,
)
BLUE = colors.HexColor("#2B6CB0")
GREEN = colors.HexColor("#276749")


def git_value(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, cwd=ROOT
    )
    return result.stdout.strip()


def build_styles():
    styles = getSampleStyleSheet()
    body = ParagraphStyle(
        "BodyCN",
        parent=styles["Normal"],
        fontName="XiandBody",
        fontSize=10.5,
        leading=16,
        spaceAfter=4,
    )
    h1 = ParagraphStyle(
        "H1CN",
        parent=styles["Heading1"],
        fontName="XiandBody",
        fontSize=18,
        leading=26,
        spaceBefore=18,
        spaceAfter=10,
        textColor=NAVY,
    )
    h2 = ParagraphStyle(
        "H2CN",
        parent=styles["Heading2"],
        fontName="XiandBody",
        fontSize=14,
        leading=20,
        spaceBefore=12,
        spaceAfter=6,
        textColor=BLUE,
    )
    h3 = ParagraphStyle(
        "H3CN",
        parent=styles["Heading3"],
        fontName="XiandBody",
        fontSize=12,
        leading=16,
        spaceBefore=8,
        spaceAfter=4,
        textColor=TEAL,
    )
    small = ParagraphStyle(
        "SmallCN",
        parent=body,
        fontSize=9,
        leading=13,
        textColor=colors.grey,
    )
    callout = ParagraphStyle(
        "Callout",
        parent=body,
        fontSize=10,
        leading=15,
        leftIndent=12,
        rightIndent=12,
        spaceBefore=6,
        spaceAfter=6,
        borderWidth=1,
        borderColor=colors.grey,
        borderPadding=6,
        backColor=colors.whitesmoke,
    )
    return {
        "body": body,
        "h1": h1,
        "h2": h2,
        "h3": h3,
        "small": small,
        "callout": callout,
    }


def build_guide():
    register_fonts()
    styles = build_styles()

    branch = git_value("rev-parse", "--abbrev-ref", "HEAD")
    commit = git_value("rev-parse", "--short=10", "HEAD")
    today = dt.date.today().strftime("%Y-%m-%d")

    story = []

    # Cover
    story.append(Spacer(1, 60 * mm))
    story.append(
        Paragraph(
            '仙道团队配合 PvE 硬 Boss 试炼指南',
            ParagraphStyle(
                "Cover",
                fontName="XiandBody",
                fontSize=26,
                leading=36,
                alignment=TA_CENTER,
                textColor=NAVY,
            ),
        )
    )
    story.append(Spacer(1, 10 * mm))
    story.append(
        Paragraph(
            "归墟魔君 · 万象妖皇 · 试炼武勋兑换",
            ParagraphStyle(
                "Subtitle",
                fontName="XiandBody",
                fontSize=14,
                leading=20,
                alignment=TA_CENTER,
                textColor=colors.grey,
            ),
        )
    )
    story.append(Spacer(1, 40 * mm))
    story.append(
        Paragraph(
            f"分支：{branch}　提交基线：{commit}　生成日期：{today}",
            ParagraphStyle(
                "Meta",
                fontName="XiandBody",
                fontSize=9,
                leading=13,
                alignment=TA_CENTER,
                textColor=colors.grey,
            ),
        )
    )
    story.append(PageBreak())

    # 1. Overview
    story.append(Paragraph("1. 什么是团队硬 Boss？", styles["h1"]))
    story.append(
        Paragraph(
            "团队硬 Boss 是面向 3 人以上队伍的高难度 PVE 内容。Boss 的伤害极高"
            "（非坦克职业一击即死），必须依赖镇越坦克拉住仇恨、灵医持续治疗、"
            "输出职业在安全位置攻击才能击杀。击杀后掉落「试炼武勋」，"
            "可找试炼仙官兑换高级装备、经验丹和隐藏传承。",
            styles["body"],
        )
    )
    story.append(
        Paragraph(
            "<b>核心设计意图</b>：让各职业的定位真正发挥——坦克扛、治疗刷、"
            "输出打。Boss 按威胁表选攻击目标（已存在于引擎中），"
            "谁仇恨高就打谁。坦克必须持续嘲讽稳仇，治疗不能过量刷血"
            "（否则 OT 被秒），输出不能无脑爆发。",
            styles["callout"],
        )
    )

    # 2. Two Bosses
    story.append(Paragraph("2. 两个硬 Boss", styles["h1"]))

    story.append(Paragraph("2.1 归墟魔君", styles["h2"]))
    story.append(
        Table(
            [
                ["属性", "数值", "说明"],
                ["位置", "归墟境", "羽化村广场西北方向"],
                ["HP", "500,000", "约需 3-5 分钟团队输出"],
                ["力量", "5,500", "纯物理攻击型 Boss"],
                ["普通攻击", "4,000-6,000", "非坦克挨一下就死"],
                ["必杀技", "归墟魔击", "3 级阶段，物理 4000-6000"],
                ["攻击间隔", "4 秒", "比普通怪（2 秒）慢一倍"],
                ["最小队伍", "3 人", "少于 3 人 Boss 直接离场"],
                ["重生时间", "30 分钟", "被击杀后 30 分钟在原位重生"],
                ["武勋掉落", "5 个/人", "每个同房同队存活成员各得"],
            ],
            colWidths=[30 * mm, 35 * mm, 85 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ]
            ),
        )
    )

    story.append(Paragraph("2.2 万象妖皇", styles["h2"]))
    story.append(
        Table(
            [
                ["属性", "数值", "说明"],
                ["位置", "万象林", "从仙镇广场东北方向"],
                ["HP", "400,000", "比魔君略低但混合伤害"],
                ["力量", "3,500", "混合物理/法术攻击"],
                ["智力", "2,200", "法术伤害也很高"],
                ["普通攻击", "2,800-6,000", "物法混合，盾不好扛"],
                ["必杀技", "万象侵蚀", "附带持续伤害，需灵医净化"],
                ["攻击间隔", "3 秒", "比魔君更快"],
                ["最小队伍", "3 人", "同上"],
                ["重生时间", "30 分钟", "同上"],
                ["武勋掉落", "4 个/人", "比魔君少 1 个"],
            ],
            colWidths=[30 * mm, 35 * mm, 85 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ]
            ),
        )
    )

    # 3. Team Composition
    story.append(PageBreak())
    story.append(Paragraph("3. 推荐队伍配置", styles["h1"]))
    story.append(
        Paragraph(
            "硬 Boss 的伤害设计为「非坦克一击必死」。以下配置是经过数值"
            "验算的最小可行团队。",
            styles["body"],
        )
    )
    story.append(
        Table(
            [
                ["角色", "推荐职业", "职责", "关键技能"],
                [
                    "坦克",
                    "镇越",
                    "拉住 Boss 仇恨，承受所有攻击",
                    "地震吼（强制 first_target）、山河壁（队伍护盾）、"
                    "玄铁盾（个人护盾）",
                ],
                [
                    "治疗",
                    "灵医",
                    "持续治疗坦克，群疗净化全队",
                    "甘霖（群疗）、回春（智能单疗）、清心（净化）、"
                    "六合回春（大招群疗+净化）",
                ],
                [
                    "输出",
                    "剑仙/羽士/诛仙",
                    "在坦克拉住仇恨后全力输出",
                    "注意仇恨不能超过坦克；Boss 转头=死",
                ],
                [
                    "输出/补位",
                    "太极（可选）",
                    "输出+复活保险",
                    "生生不息（5 分钟自复活）、复阴（复活倒地队友）",
                ],
            ],
            colWidths=[18 * mm, 28 * mm, 50 * mm, 64 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), TEAL),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ]
            ),
        )
    )
    story.append(
        Paragraph(
            "<b>为什么必须 3 人？</b>：Boss 有 team_required 标志，"
            "每次攻击前检查 first_target 的同房同队存活人数。"
            "少于 3 人时 Boss reset 仇恨并离场，提示"
            "「硬 Boss 需 3 人以上队伍挑战」。",
            styles["callout"],
        )
    )

    # 4. Threat Mechanics
    story.append(Paragraph("4. 仇恨机制详解", styles["h1"]))
    story.append(
        Paragraph(
            "Boss 使用引擎已有的威胁表（threat table）选择攻击目标。"
            "每次 attack() 调用 get_target()，选当前威胁最高的存活目标。",
            styles["body"],
        )
    )
    story.append(
        Table(
            [
                ["行为", "仇恨影响", "比例", "实战含义"],
                [
                    "物理伤害",
                    "伤害值 × hate_multiplier / 100",
                    "1:1（普通技能）至 6:1（不周震击）",
                    "DPS 输出越高越容易抢仇",
                ],
                [
                    "灵医群疗",
                    "总治疗量 × 10",
                    "10:1",
                    "灵医过量群疗会 OT 被秒",
                ],
                [
                    "自疗（方士/无相/太极）",
                    "治疗量 / 5",
                    "5:1",
                    "自疗量大会拉仇",
                ],
                [
                    "地震吼（镇越嘲讽）",
                    "force_target：当前最高仇 + 固定值",
                    "强制最高",
                    "坦克必须定期嘲讽稳仇",
                ],
                [
                    "镇越技能 hate_multiplier",
                    "岳击 180%、横山击 400%、巨岳破 220%",
                    "比 DPS 高",
                    "正常输出循环中坦克仇恨 > DPS",
                ],
            ],
            colWidths=[35 * mm, 45 * mm, 25 * mm, 55 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), RED),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ]
            ),
        )
    )

    # 5. Trial Merit Exchange
    story.append(PageBreak())
    story.append(Paragraph("5. 试炼武勋兑换", styles["h1"]))
    story.append(
        Paragraph(
            "试炼仙官位于两侧广场（羽化村/从仙镇）。Boss 击杀后"
            "每个同房同队存活成员必得武勋（归墟魔君 5 个、万象妖皇 4 个）。"
            "武勋绑定不可交易。",
            styles["body"],
        )
    )
    story.append(
        Table(
            [
                ["武勋", "兑换内容", "约需 Boss 击杀次数", "价值评估"],
                ["10", "金币×10,000", "2-3 次", "等价 30 分钟挂机收入"],
                ["30", "奥法长袍（基础版）", "6-8 次", "白板装备，过渡用"],
                ["50", "【特】幻神丹×5", "10-13 次", "5 小时 +60% 经验加成"],
                ["80", "伏魔战甲（基础版）", "16-20 次", "白板装备，过渡用"],
                ["100", "金币×5,000", "20-25 次", "灵兽饲料购买资金"],
                ["200", "冰凌头饰（基础版）", "40-50 次", "白板装备，过渡用"],
                ["500", "太极/无相隐藏书随机 1 本", "100-125 次", "全游戏最稀有技能保底渠道"],
            ],
            colWidths=[15 * mm, 45 * mm, 35 * mm, 55 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), GOLD),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ]
            ),
        )
    )
    story.append(
        Paragraph(
            "<b>平衡说明</b>：装备奖励为基础模板（无随机属性），弱于正常打怪掉落。"
            "隐藏书兑换耗时（~28 小时组队）远超挂机掉落（~5 小时），"
            "是保底渠道而非捷径。不会冲击游戏经济和装备体系。",
            styles["callout"],
        )
    )

    # 6. Failure & Retry
    story.append(Paragraph("6. 失败与重试", styles["h1"]))
    story.append(
        Table(
            [
                ["场景", "结果", "应对"],
                [
                    "坦克倒下",
                    "Boss 转打第二仇恨（通常 DPS/治疗），大概率秒杀",
                    "太极·复阴可立即复活坦克；无太极则全队需逃跑",
                ],
                [
                    "治疗 OT 被秒",
                    "坦克断奶，下一轮攻击大概率倒",
                    "治疗注意控蓝、控量；群疗不要满血刷",
                ],
                [
                    "DPS 抢仇被秒",
                    "Boss 转打 DPS 一击必杀",
                    "DPS 开局等 3 秒让坦克建立仇恨后再输出",
                ],
                [
                    "全队倒下",
                    "Boss 重置仇恨，30 分钟后重生",
                    "变鬼魂回到复活点，重新组队再来",
                ],
                [
                    "人数不足 3 人",
                    "Boss 直接离场（不攻击）",
                    "组满 3 人后再进入 Boss 房间",
                ],
            ],
            colWidths=[30 * mm, 55 * mm, 65 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), RED),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ]
            ),
        )
    )

    # 7. Strategy
    story.append(PageBreak())
    story.append(Paragraph("7. 实战策略", styles["h1"]))

    story.append(Paragraph("7.1 开怪", styles["h2"]))
    story.append(
        Paragraph(
            "1. 全队进入 Boss 房间<br/>"
            "2. 镇越先手地震吼（强制 first_target）<br/>"
            "3. 等 2-3 秒让镇越建立基础仇恨（普通攻击 + 岳击）<br/>"
            "4. 灵医开始回春（单疗，不要群疗）<br/>"
            "5. DPS 开始输出（控制节奏，不要爆发）<br/>"
            "6. 镇越每 15-18 秒补一次地震吼",
            styles["body"],
        )
    )

    story.append(Paragraph("7.2 循环", styles["h2"]))
    story.append(
        Paragraph(
            "坦克：地震吼 → 岳击 → 横山击 → 山河壁（队伍盾）→ 地震吼 → ...<br/>"
            "灵医：回春（智能单疗坦克）→ 甘霖（群疗）→ 清心（净化 DOT）→ ...<br/>"
            "DPS：正常输出循环，注意血量，危险时自疗但别过量（5:1 仇恨）<br/>"
            "太极：正常输出 + 监控队友血量，有人倒下立即 taiji_fuyin 复活",
            styles["body"],
        )
    )

    story.append(Paragraph("7.3 关键时间点", styles["h2"]))
    story.append(
        Table(
            [
                ["时间", "事件", "应对"],
                ["0-10 秒", "坦克建立仇恨", "DPS 停手等待"],
                ["10-30 秒", "稳定循环", "正常输出 + 治疗"],
                ["每 20 秒", "归墟魔君必杀技", "山河壁提前覆盖"],
                ["每 25 秒", "万象妖皇 DOT", "灵医清心净化"],
                ["30 秒后", "Boss 狂暴（如有）", "全力输出"],
                ["有人倒下", "太极·复阴", "taiji_fuyin <队友名>"],
                ["全队倒下", "战斗结束", "Boss 30 分钟后重生"],
            ],
            colWidths=[25 * mm, 45 * mm, 80 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "XiandBody"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BACKGROUND", (0, 0), (-1, 0), GREEN),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.whitesmoke]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ]
            ),
        )
    )

    # Build PDF
    pdf_path = ROOT / "docs" / "xiand-team-pve-boss-guide.pdf"
    doc = GuideDocTemplate(str(pdf_path), styles)
    doc.build(story)
    print(f"Generated {pdf_path}")

    # Also copy to Desktop for convenience
    desktop = Path.home() / "Desktop" / "仙道团队PvE硬Boss试炼指南.pdf"
    try:
        import shutil
        shutil.copy2(pdf_path, desktop)
        print(f"Also copied to {desktop}")
    except Exception:
        pass


if __name__ == "__main__":
    build_guide()
