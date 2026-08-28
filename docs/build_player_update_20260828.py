#!/usr/bin/env python3
"""Build the Aug 28 player-facing update announcement PDF."""
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
PDF_PATH = DOCS / "xiand-player-update-20260828.pdf"
DESKTOP_PDF = Path.home() / "Desktop" / "仙道8月28日更新公告.pdf"
BUILD_DATE = dt.date(2026, 8, 28)

INK = colors.HexColor("#1a2430")
GOLD = colors.HexColor("#8a6d2f")
HEAD_BG = colors.HexColor("#5a1a2a")
CARD_BG = colors.HexColor("#f8f4f4")
CARD_BORDER = colors.HexColor("#d8c4c8")

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
    "note": ParagraphStyle("note", fontName="STSong-Light", fontSize=9,
                            leading=13, textColor=colors.HexColor("#6a5a5a"),
                            spaceAfter=2 * mm),
    "cell": ParagraphStyle("cell", fontName="STSong-Light", fontSize=9.5,
                            leading=13, textColor=INK),
}

story = []
story.append(Paragraph("仙道 · 8月28日大版本更新", styles["title"]))
story.append(Paragraph("神太古血饮传承 · 照命群攻群疗 · 赛季背包解卡 · 施法动画", styles["subtitle"]))
story.append(Paragraph(
    "亲爱的仙友：本次更新带来全职业第八阶隐藏传承「神太古」、照命职业的群攻与群疗、"
    "赛季背包清理通道、炼化稳定性修复，以及全服可见的施法动画。以下是完整变化说明。"
, styles["body"]))
story.append(Spacer(1, 4 * mm))

# ===== 1. Shen-Taigu =====
story.append(Paragraph("一、全职业第八阶隐藏传承「神太古」", styles["h2"]))
story.append(Paragraph(
    "太古传承之上的终极一阶：高伤害并按实际伤害吸血回血，全服血月广播。"
, styles["body"]))
story.append(Paragraph("•  十职业各一本：神曜一剑 / 神羽天翔 / 神灭诛天 / 神狂血月 / 神幽夺命 / 神煞影啸 / 神灵虚召 / 神山镇岳 / 神辉星坠 / 神幽寒霜", styles["bullet"]))
story.append(Paragraph("•  血饮效果：伤害为太古曲线的1.5倍，并按实际造成伤害的50%回复自身生命（过量伤害不放大）", styles["bullet"]))
story.append(Paragraph("•  长冷却定位：有效冷却75秒，一击血饮", styles["bullet"]))
story.append(Paragraph("•  掉落条件：仅120级以上Boss，且击杀者个人难度第六档起；第七档掉率更高（约1/1250万，第六档约1/3125万）", styles["bullet"]))
story.append(Paragraph("•  账号绑定：拾取即绑定，不可交易、赠送或入库", styles["bullet"]))
story.append(Paragraph("•  全服播报：施放时全服在线玩家可见血月全屏动画（幻境与永恒服互不干扰）", styles["bullet"]))
story.append(Spacer(1, 2 * mm))

# ===== 2. Zhaoming =====
story.append(Paragraph("二、照命职业加强：群攻与群疗", styles["h2"]))
story.append(Paragraph("•  新增群攻【碎镜千影】：横扫同房间敌人，目标数随技能阶段2→10", styles["bullet"]))
story.append(Paragraph("•  新增群疗【命火同燃】：治疗同房间同队所有人，五阶80→880", styles["bullet"]))
story.append(Paragraph("•  新建照命角色开局即拥有；老照命角色打开四十九难入口时自动补齐", styles["bullet"]))

# ===== 3. Season inventory =====
story.append(Paragraph("三、赛季背包解卡", styles["h2"]))
story.append(Paragraph(
    "账号绑定的套装与太古隐藏技能书现在可以清理：在背包中对其执行摧毁，"
    "二次确认后即销毁（有审计日志可查）。交易、赠送、拍卖与仓库保护规则不变，"
    "智能清包仍不会误卖绑定装备。"
, styles["body"]))

# ===== 4. Reforge fix =====
story.append(Paragraph("四、炼化与制造修复", styles["h2"]))
story.append(Paragraph(
    "修复了一个长期隐患：当随机词条组合与一件不同稀有度的旧装备文件同名时，"
    "炼化/洗炼/制造会静默失败。现在会正确覆盖重生成，越洗越强的保底规则不变。"
, styles["body"]))

# ===== 5. Animations =====
story.append(Paragraph("五、施法动画全面上线", styles["h2"]))
story.append(Paragraph("•  所有技能释放都会向同房间玩家广播施法动画（剑气/法术/召唤/治疗等20余种）", styles["bullet"]))
story.append(Paragraph("•  神太古专属血月动画：房间级双搏动血月 + 全服全屏血月横幅", styles["bullet"]))
story.append(Paragraph("•  修复动画标签偶尔显示乱码字符的问题", styles["bullet"]))
story.append(Paragraph("•  尊重系统“减弱动态效果”设置与战斗特效开关", styles["bullet"]))

story.append(Spacer(1, 3 * mm))
story.append(Paragraph(
    "提示：神太古传承极其稀有，建议在第七档个人难度下挑战120级以上Boss。"
    "登录页面与游戏内公告可随时查看本说明。"
, styles["note"]))
story.append(Paragraph(
    f"— 仙道运营组 · {BUILD_DATE.strftime('%Y年%m月%d日')} —"
, styles["note"]))

doc = BaseDocTemplate(
    str(PDF_PATH), pagesize=A4,
    leftMargin=18 * mm, rightMargin=18 * mm,
    topMargin=16 * mm, bottomMargin=16 * mm,
    title="仙道8月28日更新公告",
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
