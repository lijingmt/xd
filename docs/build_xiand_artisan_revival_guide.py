#!/usr/bin/env python3
"""Build the player-facing Xiand artisan revival guide as Markdown and PDF."""

from __future__ import annotations

import datetime as dt
import html
import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    Frame,
    Image,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

from build_xiand_profession_guide import (
    BOTTOM_MARGIN,
    CONTENT_W,
    GOLD,
    GOLD_LIGHT,
    INK,
    LEFT_MARGIN,
    LINE,
    MUTED,
    NAVY,
    PAGE_H,
    PAGE_W,
    RIGHT_MARGIN,
    ROOT,
    TEAL,
    TEAL_LIGHT,
    TOP_MARGIN,
    GuideDocTemplate,
    HandbookBuilder,
    build_styles,
    git_value,
    register_fonts,
)


DOCS = ROOT / "docs"
PDF_PATH = DOCS / "xiand-artisan-revival-guide.pdf"
MD_PATH = DOCS / "xiand-artisan-revival-guide.md"
OUTPUT_PDF_PATH = ROOT / "output/pdf/xiand-artisan-revival-guide.pdf"


class ArtisanGuideDoc(GuideDocTemplate):
    """Shared handbook layout with artisan-specific running heads."""

    def __init__(self, filename: str, styles: dict[str, ParagraphStyle], **kwargs):
        super().__init__(filename, styles, **kwargs)
        frame = Frame(
            LEFT_MARGIN,
            BOTTOM_MARGIN,
            CONTENT_W,
            PAGE_H - TOP_MARGIN - BOTTOM_MARGIN,
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
        )
        self.pageTemplates = []
        self.addPageTemplates(
            PageTemplate(id="artisan", frames=[frame], onPage=self._on_artisan_page)
        )

    def _on_artisan_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("仙道百工复兴 - 新锻造玩家手册")
        canvas.setAuthor("Xiand Project")
        canvas.setSubject("采集、配方、材料囊、批量制造与百工大师成长说明")
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
                LEFT_MARGIN, PAGE_H - 8.5 * mm, "仙道百工复兴 - 新锻造玩家手册"
            )
            canvas.drawRightString(
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 8.5 * mm,
                "采集 · 制造 · 大师升阶",
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
) -> None:
    story.append(Spacer(1, 18 * mm))
    icon_paths = [
        ROOT / "images/logo.png",
        ROOT / "images/human_logo.png",
        ROOT / "images/human_fangshi_logo.png",
    ]
    icons = [Image(str(path), width=22 * mm, height=22 * mm) for path in icon_paths]
    icon_table = Table([icons], colWidths=[30 * mm] * 3, hAlign="CENTER")
    icon_table.setStyle(
        TableStyle(
            [
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    story.append(icon_table)
    story.append(Spacer(1, 9 * mm))
    story.append(Paragraph("仙道百工复兴", styles["CoverTitle"]))
    story.append(
        Paragraph(
            "新锻造玩家手册 · 从第一块矿石到高阶大师装备",
            styles["CoverSub"],
        )
    )
    story.append(Spacer(1, 10 * mm))

    craft_cells = []
    for title, subtitle, tint in [
        ("采矿", "矿石与宝石", "#E8F1F8"),
        ("采药", "草药与灵材", "#EAF7F1"),
        ("锻造", "武器与重装", "#FFF1E8"),
        ("炼丹", "属性与补给", "#F4EDFF"),
        ("裁缝", "布衣与法装", "#FFF7DF"),
        ("制甲", "皮甲与护具", "#EEF2E5"),
    ]:
        craft_cells.append(
            Table(
                [[Paragraph(f"<b>{title}</b><br/>{subtitle}", styles["Body"])]],
                colWidths=[46 * mm],
                style=TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(tint)),
                        ("BOX", (0, 0), (-1, -1), 0.6, LINE),
                        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                        ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
                    ]
                ),
            )
        )
    craft_table = Table(
        [craft_cells[:3], craft_cells[3:]],
        colWidths=[50 * mm] * 3,
        hAlign="CENTER",
    )
    craft_table.setStyle(
        TableStyle(
            [
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 2 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 2 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2 * mm),
            ]
        )
    )
    story.append(craft_table)
    story.append(Spacer(1, 13 * mm))
    story.append(
        Paragraph(
            "基础手艺全部可学　｜　材料自动入囊　｜　409张历史配方复活<br/>"
            "装备批量制造　｜　炼丹百颗一炉　｜　80级起大师升阶",
            ParagraphStyle(
                "ArtisanCoverBox",
                parent=styles["Body"],
                fontName="XiandBold",
                fontSize=10,
                leading=17,
                alignment=TA_CENTER,
                textColor=INK,
                backColor=TEAL_LIGHT,
                borderColor=TEAL,
                borderWidth=0.8,
                borderPadding=5 * mm,
            ),
        )
    )
    story.append(Spacer(1, 15 * mm))
    story.append(
        Paragraph(
            f"发布分支：{html.escape(branch)}　内容基线：{html.escape(commit)}　生成日期：{build_date}",
            ParagraphStyle(
                "ArtisanCoverMeta",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=MUTED,
            ),
        )
    )
    guide.md.extend(
        [
            "# 仙道百工复兴 - 新锻造玩家手册",
            "",
            "从第一块矿石到高阶大师装备。",
            "",
            f"- 发布分支：`{branch}`",
            f"- 内容基线：`{commit}`",
            f"- 生成日期：{build_date}",
            "",
        ]
    )
    story.append(PageBreak())


def add_progression_strip(story: list, styles: dict[str, ParagraphStyle]) -> None:
    cells: list = []
    stages = [
        ("1", "学习手艺", "每门10金"),
        ("2", "采集材料", "自动入囊"),
        ("3", "阅读配方", "永久掌握"),
        ("4", "批量制造", "积累熟练度"),
        ("5", "选择大师", "210熟练度"),
        ("6", "高阶升阶", "80级起"),
    ]
    for number, title, subtitle in stages:
        cells.append(
            Paragraph(
                f'<font color="#0F766E"><b>{number}</b></font><br/><b>{title}</b><br/>'
                f'<font color="#64748B">{subtitle}</font>',
                ParagraphStyle(
                    f"ArtisanStage{number}",
                    parent=styles["Small"],
                    alignment=TA_CENTER,
                    leading=12,
                ),
            )
        )
    strip = Table([cells], colWidths=[CONTENT_W / 6] * 6, hAlign="CENTER")
    strip.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                ("BOX", (0, 0), (-1, -1), 0.7, TEAL),
                ("INNERGRID", (0, 0), (-1, -1), 0.35, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
            ]
        )
    )
    story.extend([strip, Spacer(1, 4 * mm)])


def build_guide() -> None:
    register_fonts()
    styles = build_styles()
    branch = git_value("rev-parse", "--abbrev-ref", "HEAD")
    commit = git_value("rev-parse", "--short=10", "HEAD")
    build_date = dt.date.today().isoformat()

    doc = ArtisanGuideDoc(
        str(PDF_PATH),
        styles,
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="仙道百工复兴 - 新锻造玩家手册",
        author="Xiand Project",
    )
    story: list = []
    guide = HandbookBuilder(story, styles)
    add_cover(story, guide, styles, branch, commit, build_date)

    guide.h1("1. 一分钟看懂百工复兴")
    guide.paragraph(
        "百工复兴把采矿、采药、锻造、炼丹、裁缝和制甲重新连成一条长期成长线。玩家不再只是等怪物随机掉装备，而是可以收集材料、掌握配方、批量制造，并在高等级阶段打造与人物等级匹配的装备。"
    )
    add_progression_strip(story, styles)
    guide.callout(
        "最快开始方式",
        "打开“我的技能”进入“百工坊”，学习需要的基础手艺。六门都可以学习，每门10金，不再受旧版最多两门的限制。",
    )
    guide.h2("1.1 玩家真正得到的收益")
    guide.bullets(
        [
            "采矿和采药默认自动进入材料囊，挂机采集不再快速塞满包袱。",
            "装备一次可制造1、5、10件，服务端单次上限20件；炼丹每炉最多100颗。",
            "409张历史配方重新接通，旧材料、旧书和旧熟练度继续有价值。",
            "制造提供稳定的装备来源，随机品质与匠心保底又保留长期追求。",
            "80级以后的大师升阶让高等级玩家可以把65级以上配方延伸到当前阶段。",
        ]
    )
    guide.h2("1.2 不会发生什么")
    guide.bullets(
        [
            "大师专精本身不会直接给角色增加攻击、生命或防御。",
            "升阶制造不会复制Boss装备的独有效果，Boss与副本依然不可替代。",
            "旧人物不需要迁档，也不需要重新学习已经掌握的配方。",
        ]
    )

    guide.pagebreak()
    guide.h1("2. 六门手艺如何分工")
    guide.table(
        ["手艺", "主要产出", "适合玩家", "核心收益"],
        [
            ["采矿", "矿石、金属、宝石", "挂机采集、锻造供给", "材料自动入囊，支撑武器和重装制造"],
            ["采药", "草药、灵材", "挂机采集、炼丹供给", "减少背包压力，形成稳定丹药原料"],
            ["锻造", "主手、副手、双手武器与重装", "物理系、武器收藏者", "制造武器并开放高阶通用武器路线"],
            ["炼丹", "属性、辅助、伤害、防御与补给丹", "挂机、PVE和持续补给", "单炉最多100颗，94/95号补给配方重新可用"],
            ["裁缝", "布帽、法袍、护腕、鞋等", "法系与布衣路线", "批量制作轻装，支持大师升阶"],
            ["制甲", "皮帽、皮甲、手套、鞋等", "敏捷与皮甲路线", "批量制作护具，支持大师升阶"],
        ],
        [0.8, 1.6, 1.45, 2.25],
    )
    guide.h2("2.1 材料囊")
    guide.paragraph(
        "材料囊是一套与包袱并行的安全存储。野外采集默认直接入囊；制造时系统会把材料囊和包袱中的同名材料合并计算，因此玩家不必先手工取出。"
    )
    guide.table(
        ["操作", "位置", "效果"],
        [
            ["查看", "百工坊 - 材料囊", "按材料名称显示数量，并提供取1份、10份或全部取出"],
            ["一键收纳", "材料囊页面", "把包袱里的百工原料全部收入材料囊并立即保存"],
            ["自动入囊", "材料囊页面开关", "开启后采矿、采药所得原料不占包袱格"],
            ["制作扣料", "所有制造页面", "优先扣材料囊，不足部分再从包袱补齐"],
        ],
        [1.0, 1.5, 3.6],
    )
    guide.callout(
        "安全边界",
        "材料囊只接受服务器材料目录中的可堆叠原料。取出、制造和保存任何一步失败时，数量不会凭空增加或消失。",
        "gold",
    )

    guide.pagebreak()
    guide.h1("3. 配方、批量制造与熟练度")
    guide.h2("3.1 配方是制造资格")
    guide.paragraph(
        "获得配方书后阅读，配方会永久登记在对应手艺分类中。制造时服务端会重新验证已学标记、熟练度、材料、人物等级与批量上限，直接伪造按钮参数不会得到物品。"
    )
    guide.table(
        ["手艺", "配方总数", "已经接通的分类", "最高历史模板"],
        [
            ["锻造", "140", "主手、副手、双手、防具、高阶通用武器", "70级"],
            ["炼丹", "95", "一般、特殊、属性、辅助、伤害、防御、补给", "50级"],
            ["裁缝", "87", "头、胸、腕、手、腿、脚", "70级"],
            ["制甲", "87", "头、胸、腕、手、腿、脚", "70级"],
            ["合计", "409", "全部逐张验证分类、产物与正数材料", "大师可继续升阶"],
        ],
        [1.0, 0.85, 3.0, 1.25],
    )
    guide.h2("3.2 批量制造")
    guide.table(
        ["制造类型", "常用按钮", "服务端上限", "熟练度推进"],
        [
            ["普通装备", "1 / 5 / 10件", "20件", "每成功制造1件计1次"],
            ["高阶装备", "1 / 5件", "5件", "每成功制造1件计1次"],
            ["炼丹", "输入1至100颗", "100颗", "每成功炼制1颗计1次"],
        ],
        [1.4, 1.5, 1.2, 2.0],
    )
    guide.h2("3.3 新熟练度节奏")
    guide.paragraph(
        "每级需要的操作次数为“1 + 当前熟练度 ÷ 10”。1至4级不再出现旧版需要次数为零的问题，熟练度最高仍为300。旧公式留下的较大部分进度会先折算，不会在第一次制造时被清空。"
    )
    guide.table(
        ["当前熟练度", "升下一级所需操作", "阶段意义"],
        [
            ["1", "1", "快速理解制造流程"],
            ["50", "6", "形成稳定采集与制作循环"],
            ["100", "11", "中阶配方积累"],
            ["210", "22", "解锁大师专精资格"],
            ["299", "30", "接近300熟练度上限"],
        ],
        [1.2, 1.6, 3.3],
    )

    guide.pagebreak()
    guide.h1("4. 百工大师与高阶装备")
    guide.paragraph(
        "锻造、炼丹、裁缝或制甲达到210熟练度后，可以选择其中一门作为大师专精。首次选择免费；切换专精需要等待7天并支付100金，避免玩家随时切换获得所有最优收益。"
    )
    guide.table(
        ["大师规则", "当前数值", "设计目的"],
        [
            ["资格门槛", "对应手艺210熟练度", "先完成长期制造积累"],
            ["专精数量", "同时1门", "保留玩家分工和市场交换"],
            ["首次选择", "免费", "不惩罚第一次路线选择"],
            ["切换", "7天冷却 + 100金", "限制短期套利并回收金币"],
            ["品质幸运", "5至20，最高20", "小幅改善品质，不突破属性规则"],
            ["匠心保底", "连续30次动态品质制造", "给长期制造明确的最低回报"],
        ],
        [1.25, 1.65, 3.2],
    )
    guide.h2("4.1 高阶制作条件")
    guide.bullets(
        [
            "人物至少80级，目标等级从80开始，每20级一阶。",
            "只能升阶自己已经学会的65级以上配方。",
            "目标等级不能超过人物当前等级；VIP突破后的真实人物等级同样适用。",
            "高阶制作每次最多5件，不使用普通宝石或魔线的临时幸运选择。",
            "高阶产物按目标等级生成随机品质，并标记为百工来源。",
        ]
    )
    guide.h2("4.2 材料倍率")
    guide.table(
        ["目标等级", "基础材料倍率", "可操作人物等级"],
        [
            ["80", "2倍", "80级及以上"],
            ["100", "3倍", "100级及以上"],
            ["120", "3倍", "120级及以上"],
            ["140", "4倍", "140级及以上"],
            ["160", "4倍", "160级及以上"],
            ["180", "5倍", "180级及以上"],
        ],
        [1.3, 1.7, 3.0],
    )
    guide.callout(
        "炼丹大师的区别",
        "炼丹大师不生成高阶装备，核心优势是百颗批量炼制、补给类配方与品质成长体系中的专精身份。",
        "gold",
    )

    guide.pagebreak()
    guide.h1("5. 120级锻造实例")
    guide.paragraph(
        "下面以已经掌握70级“飓风短剑”配方的120级锻造大师为例，展示一次完整的高阶制造。"
    )
    guide.table(
        ["步骤", "玩家操作", "系统检查与结果"],
        [
            ["1", "把锻造练到210", "百工坊开放锻造大师选择"],
            ["2", "阅读飓风短剑配方", "登记锻造配方137号，模板等级70"],
            ["3", "选择锻造大师", "首次免费，记录7天切换冷却"],
            ["4", "进入高阶制作并选择120级", "确认人物等级不低于120，配方等级不低于65"],
            ["5", "准备三倍原料", "晶钨金60、晶钒铁75、青月石30"],
            ["6", "点击制作1件或5件", "产物先进入包袱，材料再扣除，最后保存人物"],
            ["7", "查看随机品质产物", "得到120级百工来源飓风短剑；累计熟练度与匠心进度"],
        ],
        [0.65, 2.25, 3.35],
    )
    guide.h2("5.1 为什么先给产物、再扣材料")
    guide.paragraph(
        "这不是让玩家免费制造，而是为了保证事务安全。服务器先确认产物能够生成并进入包袱，再扣除材料并保存；只要保存失败，就删除新产物、恢复材料、熟练度、匠心进度和强化材料选择。"
    )
    guide.h2("5.2 品质与保底如何理解")
    guide.bullets(
        [
            "人物原有幸运仍参与普通动态装备品质计算。",
            "当前大师额外获得5 + 熟练度÷20的品质幸运，最高20。",
            "动态品质连续29次没有达到高品质时，第30次触发匠心保底。",
            "保底只改善随机品质，不复制Boss独有效果，也不绕过穿戴等级。",
        ]
    )

    guide.pagebreak()
    guide.h1("6. 玩家策略、经济与常见问题")
    guide.h2("6.1 三种推荐路线")
    guide.table(
        ["路线", "推荐组合", "适合玩法", "长期目标"],
        [
            ["自给自足", "采矿 + 锻造 + 炼丹", "挂机、单人PVE", "自己准备武器与常用药"],
            ["材料商人", "采矿 + 采药 + 材料囊", "长时间挂机采集", "积累稀有材料，与制造玩家交换"],
            ["专业匠人", "六门全学 + 单一大师", "配方收藏与批量制造", "冲击300熟练度、品质装备与稳定供货"],
        ],
        [1.15, 1.8, 1.6, 2.1],
    )
    guide.h2("6.2 对游戏经济的作用")
    guide.bullets(
        [
            "低级原料通过熟练度和批量制造持续消耗，不再只有新手期用途。",
            "65级以上配方成为高级制造入口，配方收藏获得长期价值。",
            "单一大师与7天切换限制保留匠人分工，而不是人人随时制作全部最优装备。",
            "高阶材料倍率随等级提高，防止高级装备成本过低。",
            "Boss独有效果不可复制，制造、打怪、副本和交易能够同时存在。",
        ]
    )
    guide.h2("6.3 常见问题")
    guide.table(
        ["问题", "答案"],
        [
            ["材料在材料囊里，制造前要取出来吗？", "不用。制造会自动合并材料囊和包袱数量。"],
            ["为什么包袱满了不能从材料囊取出？", "取出会创建独立的大堆叠，需要至少一个空包袱格；材料留在囊中仍可直接制造。"],
            ["能同时学习锻造、炼丹、裁缝和制甲吗？", "可以。基础手艺全部可学，但大师专精同时只能选择一门。"],
            ["大师选错了怎么办？", "首次选择后等待7天，可支付100金切换；切换失败不会扣款。"],
            ["为什么70级配方能做120级装备？", "只有大师、人物达到120级且配方模板不低于65级时，才能选择120级升阶。"],
            ["升阶能复制Boss神器的特殊效果吗？", "不能。升阶只复用装备种类并生成随机属性，Boss独有效果仍来自对应玩法。"],
            ["制造时掉线会复制装备吗？", "百工写操作走核心串行队列，并在保存失败时回滚产物和材料。"],
        ],
        [2.2, 4.1],
        compact=True,
    )
    guide.callout(
        "一句话总结",
        "百工复兴让采集有去处、配方有价值、制造有追求、高等级有延伸，同时保留Boss、副本和玩家交易的不可替代性。",
    )

    guide.pagebreak()
    guide.h1("7. 验证与版本说明")
    guide.paragraph(
        "本手册依据当前服务器代码、409张制造配方和百工专项测试生成。数值调整时应同步更新生成器并重新导出PDF。"
    )
    guide.table(
        ["验证范围", "当前结果"],
        [
            ["配方目录", "锻造140 + 炼丹95 + 裁缝87 + 制甲87，共409张逐项验证"],
            ["真实操作", "基础手艺学习、混合扣料、批量装备、批量炼丹和120级大师装备真实执行"],
            ["输入安全", "伪造技能、伪造配方、非法路径、零数、负数和超限批量均由服务端拒绝"],
            ["旧档兼容", "旧熟练度与已学配方保留，94/95号补给配方和125至140号通用武器分类补齐"],
            ["并发与存档", "artisan与viceskill写命令保持核心串行，保存失败执行完整回滚"],
            ["自动测试", "百工专项22/22；全量TestUnit 59通过、0失败、4项条件跳过"],
        ],
        [1.5, 4.8],
    )
    guide.h2("7.1 权威实现位置")
    guide.table(
        ["文件", "用途"],
        [
            ["gamelib/single/daemons/artisand.pike", "材料囊、熟练度、大师、制造事务和回滚"],
            ["gamelib/data/material/*.csv", "409张配方的产物、等级、熟练度和材料"],
            ["gamelib/cmds/artisan*.pike", "百工坊、材料囊和高阶制作玩家入口"],
            ["test_unit/test_artisan_revival.pike", "真实制造、旧档、安全与编译专项回归"],
            ["docs/artisan-revival.md", "技术设计、兼容策略与十轮审核记录"],
        ],
        [3.0, 3.2],
    )
    guide.callout(
        "版本声明",
        f"本文生成于{build_date}，发布分支{branch}，内容基线{commit}。玩家最终获得的材料、品质与装备属性以游戏内实时结果为准。",
        "gold",
    )

    MD_PATH.write_text("\n".join(guide.md).rstrip() + "\n", encoding="utf-8")
    doc.multiBuild(story)
    OUTPUT_PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PDF_PATH, OUTPUT_PDF_PATH)


if __name__ == "__main__":
    build_guide()
