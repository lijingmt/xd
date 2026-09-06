#!/usr/bin/env python3
"""Build the Sep 6 wuxin profession update announcement PDF."""
from __future__ import annotations
import datetime as dt
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table, TableStyle,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))

DOCS = Path(__file__).resolve().parent
PDF_PATH = DOCS / "xiand-player-update-20260906.pdf"
DESKTOP_PDF = Path.home() / "Desktop" / "仙道9月6日无心职业更新公告.pdf"
BUILD_DATE = dt.date(2026, 9, 6)

INK = colors.HexColor("#1a2430")
GOLD = colors.HexColor("#8a6d2f")
HEAD_BG = colors.HexColor("#4a2d52")
CARD_BG = colors.HexColor("#f8f5f8")
CARD_BORDER = colors.HexColor("#d4c8d4")

styles = {
    "title": ParagraphStyle("title", fontName="STSong-Light", fontSize=22,
                             leading=28, textColor=INK, alignment=TA_CENTER,
                             spaceAfter=4 * mm),
    "subtitle": ParagraphStyle("subtitle", fontName="STSong-Light", fontSize=11,
                                leading=16, textColor=GOLD, alignment=TA_CENTER,
                                spaceAfter=8 * mm),
    "h2": ParagraphStyle("h2", fontName="STSong-Light", fontSize=14,
                          leading=20, textColor=HEAD_BG, spaceBefore=6 * mm,
                          spaceAfter=3 * mm),
    "body": ParagraphStyle("body", fontName="STSong-Light", fontSize=10,
                            leading=15, textColor=INK, spaceAfter=2 * mm),
    "bullet": ParagraphStyle("bullet", fontName="STSong-Light", fontSize=10,
                              leading=15, textColor=INK, leftIndent=6 * mm,
                              spaceAfter=1.5 * mm),
    "cell": ParagraphStyle("cell", fontName="STSong-Light", fontSize=9.5,
                            leading=14, textColor=INK),
    "note": ParagraphStyle("note", fontName="STSong-Light", fontSize=9,
                            leading=13, textColor=GOLD, spaceBefore=4 * mm),
}

story = []
story.append(Paragraph("仙道 · 无心职业登场", styles["title"]))
story.append(Paragraph("账号终极隐藏职业 · 心渊套装 · 400级上限 · 挂机不掉线", styles["subtitle"]))
story.append(Paragraph(
    "亲爱的仙友：隐藏职业进阶链迎来终章——照命之上是无极，无极之上是无心。"
    "本次更新同时带来伤害透明化、掉线自动恢复挂机、APP一键全角色登录等重大改进。"
, styles["body"]))
story.append(Spacer(1, 4 * mm))

# ===== 1. Wuxin intro =====
story.append(Paragraph("一、账号终极隐藏职业：无心", styles["h2"]))
story.append(Paragraph(
    "无心是仙道世界的终极隐藏职业，立于照命→无极进阶链的顶端。"
    "无心诀心法让最高属性的85%加持另外两系（太极为65%），"
    "19个专属技能全部以无极为蓝本强化一倍，且只对怪物生效——"
    "对玩家战斗维持无极水准，PVP绝对公平。"
, styles["body"]))
story.append(Paragraph("•  心法：无心诀 85%（全游戏最高，太极65%、无相50%）", styles["bullet"]))
story.append(Paragraph("•  技能：19个专属技能，对怪物伤害翻倍（消耗法力×1.5）", styles["bullet"]))
story.append(Paragraph("•  成长：三系对称 16+3.2/级，隐藏职业链+30%惯例", styles["bullet"]))
story.append(Paragraph("•  里程碑：无心达到300级时，解锁账号下所有角色的400级上限", styles["bullet"]))

unlock_data = [
    [Paragraph("职业", styles["cell"]), Paragraph("解锁条件", styles["cell"]),
     Paragraph("费用", styles["cell"])],
    [Paragraph("无极", styles["cell"]),
     Paragraph("账号下照命角色达300级", styles["cell"]),
     Paragraph("10,000 碎玉", styles["cell"])],
    [Paragraph("无心", styles["cell"]),
     Paragraph("账号下无极角色通关全部八档个人挑战难度", styles["cell"]),
     Paragraph("20,000 碎玉", styles["cell"])],
]
unlock = Table(unlock_data, colWidths=[25 * mm, 100 * mm, 30 * mm])
unlock.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONTNAME", (0, 0), (-1, -1), "STSong-Light"),
    ("FONTSIZE", (0, 0), (-1, -1), 9.5),
    ("BACKGROUND", (0, 1), (-1, -1), CARD_BG),
    ("GRID", (0, 0), (-1, -1), 0.5, CARD_BORDER),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
]))
story.append(unlock)
story.append(Spacer(1, 3 * mm))
story.append(Paragraph(
    "提示：无极角色每次登录会自动检测难度通关状态，达标即解锁无心购买资格。"
    "费用从账号共享碎玉钱包扣除，重复购买自动退款。"
, styles["note"]))

# ===== 2. Xinyuan suit =====
story.append(Paragraph("二、专属隐藏套装：心渊", styles["h2"]))
story.append(Paragraph(
    "无心专属十件套「心渊」——无心渡尽万难后凝成的战衣，仅无心职业可穿"
    "（要求300级），不可交易不可赠送。获取方式："
, styles["body"]))
story.append(Paragraph("•  首领击杀：队伍中有无心角色时，每次首领战8%概率掉落一件缺失部位", styles["bullet"]))
story.append(Paragraph("•  天衡绝境：取得前二名，结算时20%概率获得一件", styles["bullet"]))
story.append(Paragraph("•  九曜镇渊：守关成功，结算时20%概率获得一件", styles["bullet"]))
story.append(Paragraph("•  同部位不重复发放（背包和已穿戴都算），十件慢慢集齐", styles["bullet"]))
suit_data = [
    [Paragraph("部位", styles["cell"]), Paragraph("属性", styles["cell"])],
    [Paragraph("心渊剑（主手）", styles["cell"]),
     Paragraph("力量/敏捷/智力 +1500，攻击 +1500，攻速 +30", styles["cell"])],
    [Paragraph("心渊冠/袍/裤/手/履/腕", styles["cell"]),
     Paragraph("三系各 +1200，防御 900-1200", styles["cell"])],
    [Paragraph("心渊戒/链/镯", styles["cell"]),
     Paragraph("三系各 +1200，攻击 +300", styles["cell"])],
]
suit = Table(suit_data, colWidths=[50 * mm, 105 * mm])
suit.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONTNAME", (0, 0), (-1, -1), "STSong-Light"),
    ("FONTSIZE", (0, 0), (-1, -1), 9.5),
    ("BACKGROUND", (0, 1), (-1, -1), CARD_BG),
    ("GRID", (0, 0), (-1, -1), 0.5, CARD_BORDER),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
]))
story.append(suit)
story.append(Spacer(1, 3 * mm))

# ===== 3. Level 400 =====
story.append(Paragraph("三、400级上限解锁", styles["h2"]))
story.append(Paragraph(
    "当无心达到300级，账号下所有角色的等级上限从300提升至400。"
    "301-400级经验走既有的陡峭曲线，升级之路依然漫长而充实。"
    "这是账号级别的永久解锁，无需任何额外付费。"
, styles["body"]))

# ===== 4. QoL =====
story.append(Paragraph("四、伤害透明化与便利功能", styles["h2"]))
story.append(Paragraph(
    "战斗伤害数字即怪物实际扣血，并标注当前个人难度系数"
    "（如【难度·破境 输出25%】），数值明明白白。"
, styles["body"]))
qol_data = [
    [Paragraph("功能", styles["cell"]), Paragraph("说明", styles["cell"])],
    [Paragraph("挂机自动恢复", styles["cell"]),
     Paragraph("掉线/服务器重启后重新进入，自动恢复之前的挂机状态", styles["cell"])],
    [Paragraph("APP全部登录", styles["cell"]),
     Paragraph("一键登录账号下所有角色并自动挂机（子菜单可选开/关挂机）", styles["cell"])],
    [Paragraph("APP主题", styles["cell"]),
     Paragraph("夜晚/白天/鎏金三套主题，白天模式全界面适配", styles["cell"])],
    [Paragraph("充值提示", styles["cell"]),
     Paragraph("APP首页宝石按钮常亮发光，首充特惠提示", styles["cell"])],
    [Paragraph("稳定性", styles["cell"]),
     Paragraph("队伍解散异常、活动结束卡屏、登录崩溃等问题已修复", styles["cell"])],
]
qol = Table(qol_data, colWidths=[35 * mm, 120 * mm])
qol.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONTNAME", (0, 0), (-1, -1), "STSong-Light"),
    ("FONTSIZE", (0, 0), (-1, -1), 9.5),
    ("BACKGROUND", (0, 1), (-1, -1), CARD_BG),
    ("GRID", (0, 0), (-1, -1), 0.5, CARD_BORDER),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
]))
story.append(qol)
story.append(Spacer(1, 3 * mm))

story.append(Paragraph(
    "无心的强度是给通关全部难度的终极玩家的勋章：对怪物双倍带来极致的"
    "PVE效率，对玩家完全公平。祝各位仙友早日照命三百、无极破境、无心归一。"
, styles["note"]))
story.append(Paragraph(
    f"— 仙道运营组 · {BUILD_DATE.strftime('%Y年%m月%d日')} —"
, styles["note"]))

doc = BaseDocTemplate(
    str(PDF_PATH), pagesize=A4,
    leftMargin=18 * mm, rightMargin=18 * mm,
    topMargin=16 * mm, bottomMargin=16 * mm,
    title="仙道9月6日无心职业更新公告",
    author="仙道运营组",
)
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
doc.addPageTemplates([PageTemplate(id="page", frames=[frame])])
doc.build(story)

import shutil
DESKTOP_PDF.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(PDF_PATH, DESKTOP_PDF)
print(f"PDF: {PDF_PATH}")
print(f"Desktop: {DESKTOP_PDF}")
