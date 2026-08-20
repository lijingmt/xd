#!/usr/bin/env python3
"""Build the standalone S1 hidden-profession Zhaoming player guide."""

from __future__ import annotations

import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import Image, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from build_illusion_s1_player_guide import (
    DESKTOP,
    GOLD,
    INK,
    LINE,
    MOON,
    MOON_LIGHT,
    MUTED,
    NAVY,
    OUTPUT,
    ROOT,
    add_bullets,
    add_table,
    register_fonts,
    styles,
)


GUIDE_PDF = OUTPUT / "仙道_S1隐藏职业照命完整指南.pdf"


def page_decor(canvas, doc) -> None:
    canvas.saveState()
    canvas.setTitle("仙道·S1隐藏职业照命完整指南")
    canvas.setAuthor("Xiand Project")
    canvas.setSubject("S1照命解锁、七卷四十九难、传承技能与寰极专属套装")
    if doc.page > 1:
        canvas.setStrokeColor(LINE)
        canvas.line(17 * mm, A4[1] - 11 * mm, A4[0] - 17 * mm, A4[1] - 11 * mm)
        canvas.setFont("XiandBody", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(17 * mm, A4[1] - 8.5 * mm, "仙道·S1隐藏职业照命完整指南")
        canvas.drawRightString(A4[0] - 17 * mm, A4[1] - 8.5 * mm, "五职照命 · 七卷四十九难")
        canvas.line(17 * mm, 10 * mm, A4[0] - 17 * mm, 10 * mm)
        canvas.drawCentredString(A4[0] / 2, 6.5 * mm, f"— {doc.page} —")
    canvas.restoreState()


def callout(text: str, style: ParagraphStyle) -> Table:
    box = Table([[Paragraph(text, style)]], colWidths=[155 * mm])
    box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), MOON_LIGHT),
        ("BOX", (0, 0), (-1, -1), 0.9, MOON),
        ("LEFTPADDING", (0, 0), (-1, -1), 6 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
    ]))
    return box


def build_guide() -> None:
    register_fonts()
    style = styles()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    story: list = []
    cover = ROOT / "images" / "illusion_s1" / "story" / "chapters" / "chapter_081.png"
    story.extend([
        Spacer(1, 8 * mm),
        Paragraph("仙道·新月幻境 S1", style["subtitle"]),
        Paragraph("隐藏职业·照命", style["title"]),
        Paragraph("完整玩家指南｜五职照命 · 七卷四十九难", style["subtitle"]),
        Image(str(cover), width=94 * mm, height=94 * mm),
        Spacer(1, 6 * mm),
        callout(
            "五段不同职业的人生，照见第六条只属于你的命。<br/>"
            "照命不是充值直购职业：先以五个不同 S1 职业完成八十一章并达到 120 级，再由照命本人重走主线、通过四十九难，取回七项传承与十件寰极套装。",
            style["body"],
        ),
        Spacer(1, 7 * mm),
        Paragraph("规则基线：2026-08-20｜运营状态以游戏内实时显示为准", style["small"]),
        PageBreak(),
        Paragraph("1. 解锁照命：先走完五段人生", style["h1"]),
        Paragraph(
            "同一个注册账号必须在正在运行的 S1 中，用五个不同职业分别完成九卷八十一章，并把这五个人物都练到 120 级。"
            "同职业重复人物只计算一次；只有等级、职业和服务端通关凭证同时成立，才计入 1/5。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["检查项", "必须满足", "不能替代的情况"],
        ["职业数量", "5 个不同 S1 职业", "五个同职业人物只算一个"],
        ["主线进度", "每人完整领取第 81 章", "只到终章地图或只击败首领不算"],
        ["人物等级", "五人都达到 Lv120", "通关但 Lv119 仍不计入"],
        ["赛季身份", "同一账号、同一期 S1", "永恒人物或未来赛季记录不能混入"],
    ], [34 * mm, 54 * mm, 75 * mm])
    story.append(Paragraph("创建规则", style["h2"]))
    add_bullets(story, style["bullet"], [
        "照命只能在当期幻境创建，永恒服没有直接创建入口。",
        "同一注册账号在同一期 S1 最多创建一个照命。",
        "照命资格本身不额外收费，但仍占用一个已购买的 S1 人物栏位；当前每格 100 碎玉。",
        "必须从人物中心创建照命专属栏位，旧 JSP 或旧职业命令不能把已有职业改造成照命。",
    ])
    story.append(callout(
        "两段式前置：五个职业解锁“创建资格” → 新建照命 → 照命本人完成八十一章并达到 Lv120 → 开启七卷四十九难。",
        ParagraphStyle("ZhaomingGate", parent=style["body"], fontName="XiandBold", textColor=GOLD),
    ))

    story.extend([
        PageBreak(),
        Paragraph("2. 职业定位与七项传承", style["h1"]),
        Paragraph(
            "照命出生即掌握入门心诀【命】照命诀。它以物理为骨、风法与火法为支线，是能够跨系组合的传承职业；"
            "它并不复制所有旧职业的最强能力，伤害、法力、等级和冷却仍由现有战斗系统统一结算。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["卷", "技能", "类型 / 冷却", "传承含义"],
        ["一", "命痕剑", "物理 / 3秒", "以剑痕追索被抹去的名字"],
        ["二", "无声印", "风法 / 5秒", "把未说出口的承诺凝为灵印"],
        ["三", "空经照", "风法 / 6秒", "以无字经页反照敌方命门"],
        ["四", "碎镜月", "物理 / 5秒", "让每一面破镜映出同一记剑光"],
        ["五", "有情血", "物理 / 7秒", "拒绝以遗忘换取不死"],
        ["六", "还命火", "火法 / 7秒", "把被夺走的昨日化作命火"],
        ["七", "人定人间", "物理 / 9秒", "不求不死，只求此生由自己落笔"],
    ], [15 * mm, 30 * mm, 35 * mm, 83 * mm])
    story.append(Paragraph(
        "每卷第七难完成并成功领取后，才会领悟该卷技能。每个传承技能可成长至五级，等级门槛为 Lv1 / 25 / 50 / 80 / 110；"
        "领取失败不会提前写入技能，重试成功后才结算。",
        style["body"],
    ))
    story.append(Image(
        str(ROOT / "images" / "illusion_s1" / "story" / "volume_07.png"),
        width=72 * mm, height=72 * mm,
    ))
    story.append(Paragraph("第七卷·人间定命：四十九难的最终传承。", style["small"]))

    story.extend([
        PageBreak(),
        Paragraph("3. 七卷四十九难", style["h1"]),
        Paragraph(
            "四十九难严格顺序推进。每卷七难：前五难真实狩猎，第六难真实探索，第七难真实击败卷末首领。"
            "狩猎数量随卷数和难数逐步增加，不能提前刷未来目标，也不能用异地同名怪代替。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["卷 / 难数", "狩猎目标", "探索地点", "卷末首领"],
        ["一·照雪问名 1–7", "逐光月灵", "南瞻生死祠", "南瞻司寿使"],
        ["二·雾誓同生 8–14", "雾纹月狼", "雾林半药营", "雾誓守关者"],
        ["三·空经见我 15–21", "镜丝月蛛", "西牛空经殿", "西牛空经尊者"],
        ["四·碎镜照心 22–28", "折星石卫", "镜湖沉月渊", "沉月镜主"],
        ["五·不老有情 29–35", "古城星魇", "北俱冻龄宫", "北俱冻龄王"],
        ["六·雪审还名 36–42", "渊花异兽", "冻宫雪审殿", "冻宫雪审使"],
        ["七·人间定命 43–49", "渊花异兽", "新月归真台", "S1归真月主"],
    ], [43 * mm, 35 * mm, 43 * mm, 42 * mm])
    story.append(Paragraph("最短操作路线", style["h2"]))
    add_bullets(story, style["bullet"], [
        "从“幻境任务”进入“照命专属·七卷四十九难”。",
        "狩猎难：一键前往 → 挂机至本难完成 → 达标自动停机 → 领取并继续。",
        "探索难：一键前往指定剧情点；真实到达并成功保存后才能领取。",
        "首领难：一键前往 → 查找并挑战首领；只列出当前房间的真实合法首领。",
        "任何一难没有成功保存时，页面会保留当前难，玩家可以安全重试。",
    ])
    story.append(callout(
        "装备里程碑：第 5 / 10 / 15 / 20 / 25 / 30 / 35 / 40 / 45 / 49 难。<br/>技能里程碑：第 7 / 14 / 21 / 28 / 35 / 42 / 49 难。",
        style["body"],
    ))

    story.extend([
        PageBreak(),
        Paragraph("4. 寰极·照命十件套", style["h1"]),
        Paragraph(
            "四十九难会固定发放十个不同部位，不靠随机抽取：照世命剑、观命冠、载命衣、执命手、回命腕、渡命裤、踏命履、刻命戒、系命镯、藏命佩。"
            "全部装备均为账号绑定的照命专属寰极套装。",
            style["body"],
        ),
    ])
    add_table(story, style, [
        ["穿戴数", "共鸣方向", "玩家需要注意"],
        ["2 件", "全属性", "必须同收藏、同职业、同主题且部位不同"],
        ["4 件", "全法术抗性", "混入其他品质收藏会分别计数"],
        ["6 件", "暴击率", "绑定归属必须与当前账号一致"],
        ["8 件", "每秒生命恢复", "损坏、卸下或重复部位不计入"],
        ["10 件", "更高全属性", "激活六阶【套装】五命同辉"],
    ], [27 * mm, 45 * mm, 91 * mm])
    story.append(Paragraph("套装技能·五命同辉", style["h2"]))
    story.append(Paragraph(
        "五段完整幻境人生汇成一击，只在照命十件寰极套装完整穿戴时出现。寰极对应六阶，技能造成约 3470 点物理基础伤害、消耗法力 390 点；"
        "最终实战结果仍受人物属性、目标防御、挑战难度和核心战斗公式影响。",
        style["body"],
    ))
    story.append(Paragraph("存档与防复制", style["h2"]))
    add_bullets(story, style["bullet"], [
        "每难先提交人物唯一档案，再确认奖励；保存失败时不消耗领取资格。",
        "同一只 NPC 的重复死亡通知最多推进一次，同一难不能重复领奖。",
        "十件奖励按固定里程碑和固定部位发放，断线重试不会换成另一件。",
        "账号绑定、职业校验、不同部位和完整穿戴四层条件共同防止借装激活。",
    ])

    story.extend([
        PageBreak(),
        Paragraph("5. 回归规则与玩家速查", style["h1"]),
        Paragraph(
            "S1 运行期间，照命与四十九难都属于幻境世界。管理员正式关闭 S1 后，照命会随自己的唯一人物档案、已学技能和已得装备安全回归永恒世界；"
            "回归不是复制人物，也不会允许永恒服直接再创建一个照命。当前四十九难要求 S1 处于活动状态，建议在关服结算前完成未领取试炼。",
            style["body"],
        ),
        Paragraph("七步完成路线", style["h2"]),
    ])
    add_bullets(story, style["bullet"], [
        "① 人物中心查看照命进度。",
        "② 五个不同 S1 职业分别通关八十一章并达到 Lv120。",
        "③ 准备一个未使用的 S1 人物栏位，创建唯一照命。",
        "④ 照命本人再通关八十一章并达到 Lv120。",
        "⑤ 进入七卷四十九难，严格按唯一下一步推进。",
        "⑥ 在十个装备里程碑与七个卷末领取奖励。",
        "⑦ 集齐并穿上十件寰极套装，激活【五命同辉】。",
    ])
    story.append(Paragraph("常见问题", style["h2"]))
    faq = [
        ("五个剑仙能解锁吗？", "不能；同职业重复人物只算一个。"),
        ("五人都 120 级但没有通关呢？", "不能；服务端八十一章完成凭证与等级缺一不可。"),
        ("解锁后为什么四十九难仍未开启？", "照命本人还要完成八十一章并达到 120 级。"),
        ("照命资格需要额外付费吗？", "资格不额外收费，但照命仍需占一个已购买的 S1 人物栏位。"),
        ("能创建第二个照命吗？", "不能；同一账号同一期 S1 最多一个。"),
        ("掉线或保存失败会吞奖励吗？", "不会；未成功提交时当前一难保留，可重新领取。"),
    ]
    for question, answer in faq:
        story.append(Paragraph(question, ParagraphStyle(
            "ZhaomingQuestion", parent=style["body"], fontName="XiandBold",
            textColor=NAVY, spaceAfter=0.5 * mm,
        )))
        story.append(Paragraph(answer, style["body"]))
    story.append(Spacer(1, 3 * mm))
    story.append(Paragraph(
        "照命的核心不是捷径，而是把五段已经走完的人生，重新照成一条只属于自己的命。",
        ParagraphStyle(
            "ZhaomingClosing", parent=style["body"], fontName="XiandBold",
            textColor=GOLD, alignment=TA_CENTER, borderColor=GOLD,
            borderWidth=0.7, borderPadding=4 * mm,
            backColor=colors.HexColor("#FFF8E8"),
        ),
    ))

    doc = SimpleDocTemplate(
        str(GUIDE_PDF), pagesize=A4, leftMargin=17 * mm,
        rightMargin=17 * mm, topMargin=16 * mm, bottomMargin=15 * mm,
        title="仙道·S1隐藏职业照命完整指南", author="Xiand Project",
    )
    doc.build(story, onFirstPage=page_decor, onLaterPages=page_decor)


def main() -> None:
    build_guide()
    DESKTOP.mkdir(parents=True, exist_ok=True)
    shutil.copy2(GUIDE_PDF, DESKTOP / GUIDE_PDF.name)
    print(GUIDE_PDF)
    print(DESKTOP / GUIDE_PDF.name)


if __name__ == "__main__":
    main()
