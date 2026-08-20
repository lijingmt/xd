#!/usr/bin/env python3
"""Build the standalone S1 player guide and append it to the master handbook."""

from __future__ import annotations

import datetime as dt
import shutil
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from build_xiand_profession_guide import register_fonts


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf"
GUIDE_PDF = OUTPUT / "仙道_新月幻境S1玩家指南.pdf"
MASTER_PDF = OUTPUT / "仙道玩家资料大全-新月版本.pdf"
DESKTOP = Path.home() / "Desktop"
INK = colors.HexColor("#18212F")
MUTED = colors.HexColor("#596579")
NAVY = colors.HexColor("#183B5B")
MOON = colors.HexColor("#5267B2")
MOON_LIGHT = colors.HexColor("#EEF1FF")
GOLD = colors.HexColor("#A56616")
LINE = colors.HexColor("#D7DCE7")


def styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "S1Title", parent=base["Title"], fontName="XiandBold",
            fontSize=26, leading=33, alignment=TA_CENTER, textColor=NAVY,
            spaceAfter=5 * mm, wordWrap="CJK",
        ),
        "subtitle": ParagraphStyle(
            "S1Subtitle", parent=base["BodyText"], fontName="XiandBody",
            fontSize=11, leading=17, alignment=TA_CENTER, textColor=MOON,
            spaceAfter=4 * mm, wordWrap="CJK",
        ),
        "h1": ParagraphStyle(
            "S1H1", parent=base["Heading1"], fontName="XiandBold",
            fontSize=17, leading=22, textColor=NAVY, spaceBefore=4 * mm,
            spaceAfter=3 * mm, wordWrap="CJK",
        ),
        "h2": ParagraphStyle(
            "S1H2", parent=base["Heading2"], fontName="XiandBold",
            fontSize=12.5, leading=17, textColor=MOON, spaceBefore=3 * mm,
            spaceAfter=2 * mm, wordWrap="CJK",
        ),
        "body": ParagraphStyle(
            "S1Body", parent=base["BodyText"], fontName="XiandBody",
            fontSize=9.2, leading=14.5, textColor=INK, spaceAfter=2.4 * mm,
            wordWrap="CJK",
        ),
        "small": ParagraphStyle(
            "S1Small", parent=base["BodyText"], fontName="XiandBody",
            fontSize=7.6, leading=11, textColor=MUTED, spaceAfter=1.5 * mm,
            wordWrap="CJK",
        ),
        "bullet": ParagraphStyle(
            "S1Bullet", parent=base["BodyText"], fontName="XiandBody",
            fontSize=9, leading=14, leftIndent=5 * mm, firstLineIndent=-3 * mm,
            textColor=INK, spaceAfter=1.5 * mm, wordWrap="CJK",
        ),
        "table": ParagraphStyle(
            "S1Table", parent=base["BodyText"], fontName="XiandBody",
            fontSize=7.5, leading=10.5, textColor=INK, wordWrap="CJK",
        ),
        "table_head": ParagraphStyle(
            "S1TableHead", parent=base["BodyText"], fontName="XiandBold",
            fontSize=7.5, leading=10.5, textColor=colors.white,
            wordWrap="CJK",
        ),
    }


def add_bullets(story: list, style: ParagraphStyle, items: list[str]) -> None:
    for item in items:
        story.append(Paragraph("• " + item, style))


def add_table(story: list, style_map: dict[str, ParagraphStyle],
              rows: list[list[str]], widths: list[float]) -> None:
    data = []
    for row_index, row in enumerate(rows):
        style = style_map["table_head"] if row_index == 0 else style_map["table"]
        data.append([Paragraph(cell, style) for cell in row])
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, -1), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.45, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 1.8 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 1.8 * mm),
    ]))
    story.append(table)
    story.append(Spacer(1, 3 * mm))


def page_decor(canvas, doc) -> None:
    canvas.saveState()
    canvas.setTitle("仙道·新月幻境 S1 玩家指南")
    canvas.setAuthor("Xiand Project")
    canvas.setSubject("新月幻境S1人物、任务、难度、奖励与回归规则")
    if doc.page > 1:
        canvas.setStrokeColor(LINE)
        canvas.line(17 * mm, A4[1] - 11 * mm, A4[0] - 17 * mm, A4[1] - 11 * mm)
        canvas.setFont("XiandBody", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(17 * mm, A4[1] - 8.5 * mm, "仙道·新月幻境 S1 玩家指南")
        canvas.drawRightString(A4[0] - 17 * mm, A4[1] - 8.5 * mm, "九卷八十一章 · 新月长生劫")
        canvas.line(17 * mm, 10 * mm, A4[0] - 17 * mm, 10 * mm)
        canvas.drawCentredString(A4[0] / 2, 6.5 * mm, f"— {doc.page} —")
    canvas.restoreState()


def build_guide() -> None:
    register_fonts()
    style = styles()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    story: list = []
    cover = ROOT / "images" / "illusion_s1" / "story" / "chapters" / "chapter_001.png"
    story.extend([
        Spacer(1, 8 * mm),
        Paragraph("仙道·新月幻境 S1", style["title"]),
        Paragraph("玩家指南｜九卷八十一章原创长篇赛季", style["subtitle"]),
        Image(str(cover), width=92 * mm, height=92 * mm),
        Spacer(1, 6 * mm),
    ])
    intro = Table([[Paragraph(
        "从被逐出师门的无籍客，到直面掌管姓名、记忆与寿数的长生秩序。<br/>"
        "你创建的是一份独立幻境人物档案；任务、装备和选择会在管理员结束 S1 后，随这一个人物安全回归永恒服。",
        style["body"],
    )]], colWidths=[155 * mm])
    intro.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), MOON_LIGHT),
        ("BOX", (0, 0), (-1, -1), 0.9, MOON),
        ("LEFTPADDING", (0, 0), (-1, -1), 6 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
    ]))
    story.extend([
        intro, Spacer(1, 8 * mm),
        Paragraph("当前规则基线：2026-08-20", style["small"]),
        Paragraph("活动开关与运营状态以游戏内实时显示为准。", style["small"]),
        PageBreak(),
        Paragraph("1. 开始 S1：资格、人物与费用", style["h1"]),
        Paragraph(
            "S1 资格登记本身免费，但每一个 S1 人物都需要一个本期栏位。"
            "人物中心会先显示本期状态，再显示当前栏位数和共享充值余额。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["项目", "费用 / 上限", "玩家会看到什么"],
        ["登记 S1 资格", "0 碎玉", "仅登记本期资格，不赠送人物栏位"],
        ["创建一个 S1 人物", "100 碎玉 / 1 格", "每个人物都占一个已付费栏位"],
        ["批量购买", "500 碎玉 / 5 格", "一次增加 5 个本期栏位，不代表无限人物"],
        ["账号人物总量", "最多 30 份档案", "永恒与幻境人物共同占用总档案数"],
    ], [35 * mm, 42 * mm, 86 * mm])
    add_bullets(story, style["bullet"], [
        "创建人物时先选择永恒服或 S1，再选择姓名、性别、职业与头像。只有第一次创建需要填写；已有完整资料的人物不会反复弹窗。",
        "S1 角色和永恒角色都使用各自唯一的普通人物存档，不生成镜像副本。",
		"人物中心可将非默认、已离线人物移入管理员可恢复的安全归档；需重验账号密码并输入完整人物 ID，已购栏位不退款。",
        "S1 不开放家园，也不接入永恒服共享仓库、共享宠物、拍卖、跨世界赠送或交易；账号共享充值余额仍可正常购买会员和商城服务。",
    ])
    story.append(Paragraph("隐藏职业人物额度", style["h2"]))
    add_table(story, style, [
        ["职业", "默认上限", "已购上限显示", "下一格价格", "绝对上限"],
        ["无相", "3 个", "已创建 / 当前已购上限", "5000 起，每格 +5000", "10 个"],
        ["太极", "2 个", "已创建 / 当前已购上限", "5000 起，每格 +5000", "10 个"],
    ], [25 * mm, 27 * mm, 49 * mm, 42 * mm, 24 * mm])
    story.append(Paragraph(
        "购买只扩大该职业的创建数量，不会绕过无相、太极自身解锁条件。"
        "创建 S1 人物仍需另占一个 100 碎玉的本期栏位。已购职业额度永久保留，不因赛季结束清空，也不退款。",
        style["body"],
    ))

    story.extend([
        PageBreak(),
        Paragraph("2. 《新月长生劫》怎么玩", style["h1"]),
        Paragraph(
            "主线共九卷八十一章。你从南瞻逐徒出发，逐步穿过四洲残境，追查长生方为何以姓名、记忆和寿数为代价。"
            "任务必须顺序完成，不能通过重复登录、未来章节击杀或直接点击奖励跳章。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["任务类型", "最省心的操作", "完成判定"],
        ["狩猎小怪", "一键前往 → 挂机至本章完成", "只计算本章、指定地图与指定怪物"],
        ["剧情首领", "一键前往 → 直接挑战本章首领", "必须真实击败当前首领"],
        ["探索", "一键前往并触发探索", "到达指定剧情点并写入进度"],
        ["关键剧情", "阅读残响或完成剧情战斗", "服务端核验章节顺序与地点"],
        ["领取章节", "目标全满后点“领取并继续”", "先保存奖励，再进入下一章"],
    ], [30 * mm, 65 * mm, 68 * mm])
    story.append(Paragraph("三条命途", style["h2"]))
    add_bullets(story, style["bullet"], [
        "寻星：在真实剧情地点寻找三枚月印，偏探索与秘密。",
        "破阵：依次挑战三名路线首领，偏个人战斗。",
        "同心：完成同房、有效参战的队伍协作，偏社交配合。",
        "第二十三章前选定，本期不能随意改线；终章会因命途不同呈现不同终幕。",
    ])
    story.append(Image(
        str(ROOT / "images" / "illusion_s1" / "story" / "volume_05.png"),
        width=78 * mm, height=78 * mm,
    ))
    story.append(Paragraph("第五卷九章分镜母图；游戏内每章使用独立适配图。", style["small"]))

    story.extend([
        PageBreak(),
        Paragraph("3. 成长、套装与挑战难度", style["h1"]),
        Paragraph(
            "第一至六十九章逐级推进，后十二章进入终局。章节经验会帮助正常完成任务的人达到下一章最低要求，"
            "不会覆盖玩家已经获得的经验，也不会改动永恒服核心伤害公式。",
            style["body"],
        ),
        Paragraph("十件新月套装", style["h2"]),
    ])
    add_bullets(story, style["bullet"], [
        "第 9、18、27、36、45、54、63、72、81 章合计发放本职业十个不同部位。",
        "同收藏、同职业、同主题且不同部位才计入 2/4/6/8/10 件共鸣。",
        "奖励账号绑定、重复领取幂等；保存失败会撤回本次奖励，避免复制装备。",
        "赛季结束后，人物与自己身上的任务装备一起回归永恒服。",
    ])
    story.append(Paragraph("八档个人挑战", style["h2"]))
    add_table(story, style, [
        ["难度", "PVE 输出", "承伤", "套装权重", "挂机上限"],
        ["基础", "100%", "100%", "100%", "24 小时"],
        ["问道", "95%", "108%", "112%", "16 小时"],
        ["凝真", "90%", "118%", "125%", "14 小时"],
        ["破境", "85%", "130%", "140%", "12 小时"],
        ["通玄", "80%", "145%", "160%", "10 小时"],
        ["登仙", "75%", "162%", "185%", "8 小时"],
        ["凌霄", "70%", "182%", "215%", "6 小时"],
        ["天劫", "65%", "205%", "250%", "4 小时"],
    ], [31 * mm, 31 * mm, 31 * mm, 38 * mm, 32 * mm])
    story.append(Paragraph(
        "挑战难度只作用于个人 PVE 和个人掉落资格，不把玩家分到不同地图。不同难度的人仍能见面、聊天和组队，PVP 公式不变。"
        "切换必须在主城或幻境入口、脱战且停止挂机后进行。",
        style["body"],
    ))

    story.extend([
        PageBreak(),
        Paragraph("4. 社交、Worker 与世界隔离", style["h1"]),
    ])
    add_bullets(story, style["bullet"], [
        "同一个具体房间始终由一个 Worker 负责，因此同房玩家一定能互相看到、组队、聊天与战斗。",
        "不同剧情地图、猎场和副本实例会分散到多个 Worker，热门世界不会机械地只占一个进程。",
        "难度不是分区条件；永恒服和 S1 共享整组 Worker 的算力，但共享资产仍按世界身份严格隔离。",
        "跨 Worker 移动只迁移同一份人物运行状态；人物存档、背包、装备、BUFF、队伍身份和副本归属不得复制。",
    ])
    story.append(Paragraph("5. S1 结束后会发生什么", style["h1"]))
    add_bullets(story, style["bullet"], [
        "S1 当前没有自然结束日期；管理员保持开启时会一直运行。",
        "管理员正式关闭后，在线人物进入安全保存与结算；离线人物在下次登录时完成同一流程。",
        "回归只改变人物的世界状态，不复制、合并或重置人物档案。",
        "已关闭的 S1 故事和地图会以“永恒回响”保留；排行榜冻结，已领奖励不能重刷。",
        "未来 S2 需要新任务、新装备完成开发验收后再人工开启，不会自动复制 S1。",
    ])
    story.append(Paragraph("6. 常见问题", style["h1"]))
    faq = [
        ("登记资格后为什么还不能创建？", "资格与人物栏位分开；请确认已购买至少一个 100 碎玉的 S1 人物栏位，且 S1 当前处于开放创建状态。"),
        ("为什么同职业提示达到上限？", "无相默认 3 个、太极默认 2 个。人物中心会显示当前已购上限；额度用满后可购买下一格，最高 10 个。"),
		("删除人物后会退栏位费用吗？", "不会。删除是将非默认人物移入可恢复归档并释放活动栏位，已购买的 S1 栏位与隐藏职业额度不退款。"),
        ("任务怪打了不计数怎么办？", "只认当前章、指定地点和指定怪物。请从“幻境任务”的唯一下一步进入，不要在未来章节地图提前刷。"),
        ("不同难度还能一起玩吗？", "可以。难度属于个人规则，不会分房间或分 Worker。组队掉落资格按有效参战者的最低难度计算。"),
        ("赛季装备能提前放进永恒共享仓库吗？", "不能。进行中保持世界隔离；赛季结束后人物本人和所持物品一起回归。"),
    ]
    for question, answer in faq:
        story.append(Paragraph(question, style["h2"]))
        story.append(Paragraph(answer, style["body"]))
    story.append(Spacer(1, 4 * mm))
    story.append(Paragraph(
        "建议玩家始终从人物中心进入 S1，并使用任务页给出的“一键前往 / 挂机至完成 / 挑战首领 / 领取并继续”。"
        "这条路径最短，也能保证每一步都由服务器核验。",
        ParagraphStyle(
            "S1Closing", parent=style["body"], fontName="XiandBold",
            textColor=GOLD, alignment=TA_CENTER, borderColor=GOLD,
            borderWidth=0.7, borderPadding=4 * mm, backColor=colors.HexColor("#FFF8E8"),
        ),
    ))

    doc = SimpleDocTemplate(
        str(GUIDE_PDF), pagesize=A4, leftMargin=17 * mm,
        rightMargin=17 * mm, topMargin=16 * mm, bottomMargin=15 * mm,
        title="仙道·新月幻境 S1 玩家指南", author="Xiand Project",
    )
    doc.build(story, onFirstPage=page_decor, onLaterPages=page_decor)


def merge_master() -> None:
    source = PdfReader(str(MASTER_PDF))
    metadata = source.metadata or {}
    base_pages = int(metadata.get("/XiandBasePages", len(source.pages)))
    if base_pages <= 0 or base_pages > len(source.pages):
        base_pages = len(source.pages)
    supplement = PdfReader(str(GUIDE_PDF))
    writer = PdfWriter()
    for page in source.pages[:base_pages]:
        writer.add_page(page)
    s1_start = len(writer.pages)
    for page in supplement.pages:
        writer.add_page(page)
    writer.add_outline_item("新月幻境 S1 玩家指南", s1_start)
    writer.add_metadata({
        "/Title": "仙道玩家资料大全 - 新月版本",
        "/Author": "Xiand Project",
        "/Subject": "仙道新月版本玩家综合资料（含S1幻境指南）",
        "/XiandBasePages": str(base_pages),
        "/S1UpdatedAt": dt.date.today().isoformat(),
    })
    temporary = MASTER_PDF.with_suffix(".pdf.tmp")
    with temporary.open("wb") as stream:
        writer.write(stream)
    temporary.replace(MASTER_PDF)


def main() -> None:
    build_guide()
    merge_master()
    DESKTOP.mkdir(parents=True, exist_ok=True)
    shutil.copy2(GUIDE_PDF, DESKTOP / GUIDE_PDF.name)
    shutil.copy2(MASTER_PDF, DESKTOP / MASTER_PDF.name)
    print(GUIDE_PDF)
    print(MASTER_PDF)


if __name__ == "__main__":
    main()
