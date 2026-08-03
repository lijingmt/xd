#!/usr/bin/env python3
"""Build the current Xiand game introduction as Markdown and PDF."""

from __future__ import annotations

import datetime as dt
import html
import os
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
from reportlab.platypus.tableofcontents import TableOfContents

from build_xiand_profession_guide import (
    BOTTOM_MARGIN,
    CONTENT_W,
    GOLD,
    INK,
    LEFT_MARGIN,
    LINE,
    MUTED,
    NAVY,
    PAGE_H,
    PAGE_W,
    PROFESSIONS,
    RIGHT_MARGIN,
    TEAL,
    TEAL_LIGHT,
    TOP_MARGIN,
    GuideDocTemplate,
    HandbookBuilder,
    build_styles,
    git_value,
    parse_books,
    parse_skills,
    register_fonts,
)


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
PDF_PATH = DOCS / "xiand-game-introduction.pdf"
MD_PATH = DOCS / "xiand-game-introduction.md"
DESKTOP_PDF_PATH = Path.home() / "Desktop" / "仙道游戏全景介绍-2026最新版.pdf"


class GameIntroductionDoc(GuideDocTemplate):
    """Use the shared handbook layout with game-introduction running heads."""

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
            PageTemplate(id="game-introduction", frames=[frame], onPage=self._on_game_page)
        )

    def _on_game_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("仙道游戏全景介绍")
        canvas.setAuthor("Xiand Project")
        canvas.setSubject("仙道游戏世界、职业、成长与最新系统介绍")
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
            canvas.drawString(LEFT_MARGIN, PAGE_H - 8.5 * mm, "仙道游戏全景介绍")
            canvas.drawRightString(
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 8.5 * mm,
                "十职业 · 山海万灵 · 多人物账号",
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
        ROOT / "images/human_logo.png",
        ROOT / "images/human_fangshi_logo.png",
        ROOT / "images/zhenyue_logo.png",
        ROOT / "images/tianxiang_logo.png",
        ROOT / "images/lingyi_logo.png",
    ]
    icon_cells = [
        Image(str(path), width=18 * mm, height=18 * mm) for path in icon_paths
    ]
    icon_table = Table([icon_cells], colWidths=[22 * mm] * len(icon_cells), hAlign="CENTER")
    icon_table.setStyle(
        TableStyle(
            [
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2 * mm),
            ]
        )
    )
    story.append(icon_table)
    story.append(Spacer(1, 7 * mm))
    story.append(Paragraph("仙道游戏全景介绍", styles["CoverTitle"]))
    story.append(
        Paragraph(
            "十职业并行成长 · 山海万灵陪伴 · 组队与长期收藏",
            styles["CoverSub"],
        )
    )
    story.append(Spacer(1, 9 * mm))
    cover_box = Table(
        [
            [
                Paragraph(
                    f"十个职业 / {skill_count} 个职业技能对象 / {book_count} 条职业技能书配置<br/>"
                    "装备、锻造、家园、帮派、任务、副本、动态怪与隐藏传承<br/>"
                    "山海经异兽图鉴、万灵裂隙、三宠论道、多人物档案与共享宝库",
                    ParagraphStyle(
                        "GameIntroCoverBox",
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
        colWidths=[148 * mm],
        hAlign="CENTER",
    )
    cover_box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), TEAL_LIGHT),
                ("BOX", (0, 0), (-1, -1), 1.0, TEAL),
                ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
                ("LEFTPADDING", (0, 0), (-1, -1), 6 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6 * mm),
            ]
        )
    )
    story.append(cover_box)
    story.append(Spacer(1, 15 * mm))
    story.append(
        Paragraph(
            f"分支：{html.escape(branch)}　内容基线：{html.escape(commit)}　生成日期：{build_date}",
            ParagraphStyle(
                "GameIntroCoverMeta",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=MUTED,
            ),
        )
    )
    story.append(
        Paragraph(
            "本介绍依据当前 main 代码、配置与测试文档生成；活动、库存和运营数值以游戏内实时显示为准。",
            ParagraphStyle(
                "GameIntroCoverNote",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=colors.HexColor("#B42318"),
            ),
        )
    )
    guide.md.extend(
        [
            "# 仙道游戏全景介绍",
            "",
            "十职业并行成长 · 山海万灵陪伴 · 组队与长期收藏",
            "",
            f"- 分支：`{branch}`",
            f"- 内容基线：`{commit}`",
            f"- 生成日期：{build_date}",
            f"- 数据规模：10 个职业，{skill_count} 个职业技能对象，{book_count} 条职业技能书配置，15 种公开山海异兽 + 1 只隐藏鸾鸟",
            "",
            "> 本介绍依据当前 main 代码、配置与测试文档生成；活动、库存和运营数值以游戏内实时显示为准。",
            "",
        ]
    )


def build_game_introduction() -> None:
    register_fonts()
    styles = build_styles()
    skills = parse_skills()
    books = parse_books()
    branch = os.environ.get(
        "XIAND_DOC_RELEASE_BRANCH",
        git_value("rev-parse", "--abbrev-ref", "HEAD"),
    )
    commit = git_value("rev-parse", "--short=10", "HEAD")
    build_date = dt.date.today().isoformat()

    doc = GameIntroductionDoc(
        str(PDF_PATH),
        styles,
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="仙道游戏全景介绍",
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
        len(books),
    )
    guide.pagebreak()

    story.append(
        Paragraph(
            "目录",
            ParagraphStyle("GameIntroTOCTitle", parent=styles["H1"]),
        )
    )
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle(
            "GameIntroTOC1",
            fontName="XiandBold",
            fontSize=9.5,
            leading=15,
            textColor=NAVY,
            spaceAfter=1.5 * mm,
        ),
        ParagraphStyle(
            "GameIntroTOC2",
            fontName="XiandBody",
            fontSize=8.3,
            leading=12,
            leftIndent=6 * mm,
            textColor=INK,
            spaceAfter=0.8 * mm,
        ),
    ]
    story.append(toc)
    story.append(PageBreak())

    guide.h1("1. 仙道是什么")
    guide.callout(
        "一句话介绍",
        "仙道是一款以中文文字世界为核心、融合现代 Vue 界面的长期成长 MUD。玩家在仙、人、妖与中立道路之间选择职业，通过任务、技能熟练度、装备打造、组队挑战、家园经营和山海异兽收藏，形成自己的修行路线。",
        "gold",
    )
    guide.paragraph(
        "游戏保留文字 MUD 的想象空间、自由探索和服务器权威规则，同时加入战斗小窗、技能动画、响应式布局、智能挂机和多人物管理，让手机、平板与电脑浏览器都能顺畅游玩。"
    )
    guide.table(
        ["核心支柱", "玩家获得的体验", "代表系统"],
        [
            ["职业差异", "坦克、治疗、召唤、法术、物理爆发和持续伤害都有独立循环", "十职业、职业任务、隐藏技能"],
            ["长期成长", "人物、技能、装备、宠物与家园均有可持续目标", "熟练度、境界装备、锻造、万灵谱"],
            ["组队协作", "职业互补但不强制固定铁三角", "队伍、Boss、万灵裂隙、团队治疗"],
            ["公平切磋", "人物 PVP 与标准化宠物论道并行", "友情切磋、快速决胜、三宠论道"],
            ["账号传承", "一个注册账号可体验多个职业并安全共享部分资源", "多人物档案、共享宝库、共享充值余额"],
            ["现代易用", "保留深度但减少重复操作与信息遮挡", "新手引导、自动穿戴、智能挂机、战斗动画"],
        ],
        [1.0, 2.5, 2.0],
    )

    guide.h2("1.1 一次完整的成长循环")
    guide.table(
        ["阶段", "主要目标", "开始体验的特色"],
        [
            ["1-20级", "选职业、完成真实动作引导、学习基础技能、穿戴第一套装备", "20级职业任务、15级万灵初契、组队与仓库"],
            ["21-59级", "建立职业循环、积累技能熟练度、锻造与更新装备", "副本、帮派、家园、宝石、熔炼"],
            ["60-79级", "追逐每日高级书、职业任务链与70级动态怪", "高阶职业能力、境界装备、隐藏书资格怪"],
            ["80-120级", "培养隐藏神技、挑战团队内容与完善收藏", "隐藏大神技能、裂隙周目标、三宠论道"],
            ["120级后", "按自己的投入选择会员突破与长期赛季目标", "VIP分级上限、未来终局地图、收藏展示"],
        ],
        [1.0, 2.7, 2.1],
    )

    guide.h1("2. 世界、阵营与十个职业")
    guide.paragraph(
        "仙道当前拥有十个完整职业。六个经典职业分别属于人类与妖魔阵营；方士、镇越、天象、灵医属于中立阵营，可使用中立公共设施并形成召唤、坦克、法师、治疗的完整组队结构。"
    )
    guide.table(
        ["职业", "阵营", "战斗定位", "最鲜明的特色"],
        [
            [p["name"], p["faction"], p["role"], p["identity"]]
            for p in PROFESSIONS
        ],
        [0.65, 0.65, 1.5, 3.0],
        compact=True,
    )
    guide.h2("2.1 四个中立职业")
    guide.table(
        ["职业", "队伍价值", "单人体验", "专属机制"],
        [
            ["方士", "召唤压场、团队治疗与共鸣", "虎灵输出、鹤灵恢复、龟灵承伤", "三灵同时存在、三灵合一"],
            ["镇越", "稳定仇恨、团队护盾、正面承伤", "高生命防御与反震", "独立可耗尽护盾、可靠嘲讽"],
            ["天象", "法术输出、法抗压制与爆发窗口", "火冰风多元素循环", "最多三层星痕与受控引爆"],
            ["灵医", "智能单疗、群疗、净化与救急", "未组队时所有治疗回到自己", "药契、房间群攻、百炼复苏"],
        ],
        [0.7, 1.8, 1.8, 2.0],
    )

    guide.h2("2.2 创建人物不会错过什么")
    guide.bullets(
        [
            "进入世界后获得本职业起手技能、桃木剑与基础防具；自动穿戴助手只补空位，不覆盖玩家已有装备。",
            "20步新手引导要求玩家真实完成移动、战斗、穿衣、学技能、任务与地图等动作；每一步完成后直接弹窗结算。",
            "技能书购买后必须在背包点击学习；服务器再次检查职业、等级、前置技能与重复学习。",
            "老账号和旧人物存档保持原路径与原成长数据，不要求批量迁移。",
        ]
    )

    guide.h1("3. 战斗、技能与职业成长")
    guide.paragraph(
        "战斗以服务器结算为准。物理、法术、命中、闪避、暴击、韧性、穿透、护盾、持续伤害和治疗压制都拥有明确边界，前端动画只呈现结果，不改变数值。"
    )
    guide.table(
        ["系统", "当前规则摘要", "体验目标"],
        [
            ["物理伤害", "非线性防御结算；物理穿透提供有上限的无视防御伤害", "避免高防御让物理系完全失效"],
            ["法术伤害", "按有效抗性衰减；法术穿透提供有上限的无视防御伤害", "保持稳定输出又保留抗性价值"],
            ["命中/闪避", "普通命中最高99%，闪避最高75%；物理技能闪避穿透最高60%", "双方始终留有反制空间"],
            ["护盾", "多个护盾依次吸收，额度耗尽后剩余伤害继续传递", "队伍保护可读、可预测"],
            ["持续伤害", "全局保留一个强效果槽，按剩余总伤害比较和刷新", "防止弱效果覆盖强效果或无限叠加"],
            ["治疗", "只作用于合法存活目标，并受最高90%治疗压制", "不跨房、不治疗路人、不复活死亡目标"],
        ],
        [1.0, 3.0, 1.8],
        compact=True,
    )
    guide.h2("3.1 技能书与熟练度")
    guide.bullets(
        [
            "普通技能书构成1-50级职业骨架；60级后每日职业商店独立轮换高级书。",
            "成功施放技能才有机会增长熟练度，失败施放、资源不足或非法目标不会获得进度。",
            "十职业合计拥有31本极稀有隐藏大神技能书，只从实际等级70级以上怪物的资格池掉落，不在商店出售。",
            "隐藏技能按80/100/120/140/160级阶段成长，确保获得神技后仍有长期培养空间。",
        ]
    )
    guide.h2("3.2 组队与 PVP")
    guide.table(
        ["玩法", "核心规则", "安全边界"],
        [
            ["普通组队", "邀请、接受、同房协作；2/3/4/5人共享120%/140%/160%/200%经验池", "只计同房同区在线队员；加成会在经验消息中明示"],
            ["友情切磋", "人物属性、装备和技能真实参与", "胜负不应复制物品或绕过死亡与掉落规则"],
            ["长战快速决胜", "达到长战门槛后基于当前状态模拟最多1000回合", "使用保守数值、确定性边界和完整技能资源限制"],
            ["三宠论道", "三局两胜且全部标准化，只比较阵容、定位与灵属", "不改变人物血法、装备、物品、红名或死亡状态"],
        ],
        [1.0, 2.7, 2.2],
    )

    guide.h1("4. 装备、掉落与经济循环")
    guide.table(
        ["来源", "可获得内容", "长期价值"],
        [
            ["普通怪/Boss", "职业可穿装备、材料、宝石与极低概率隐藏书", "练级同时积累换装与稀有追求"],
            ["锻造", "按等级、部位与配方制作装备", "将采集资源转化为确定成长"],
            ["熔炼", "两件合格装备合成新产物，特殊组合可命中固定配方", "回收旧装备并追求高阶产物"],
            ["宝石与转化", "凹槽、主属性、攻击防御、穿透与特殊词条", "为长期装备进行定向优化"],
            ["玉石购买", "购买时可自动打碎与兑换已有玉石形态", "减少反复手工兑换步骤"],
            ["共享宝库", "同一注册账号下的人物仓库与账号宝库直接互转", "不同职业之间安全传承装备"],
        ],
        [1.0, 2.5, 2.2],
    )
    guide.h2("4.1 高阶装备境界")
    guide.paragraph(
        "71级以上动态掉落会进入欲界、色界、无色界、离三界、破虚境、渡劫境等装备境界。境界影响名字前缀与属性倍率，玩家仍需结合职业限制、主属性、装备位和真实技能循环判断价值。"
    )
    guide.callout(
        "自动清包的底线",
        "挂机出售、存仓或销毁永远保护穿戴物、任务物、技能书、玉石、补给、唯一物品、不可交易物、高品质和特殊来源物品；VIP只增加便利程度，不放宽安全保护。",
    )

    guide.h1("5. 山海万灵：面向全部职业的宠物系统")
    guide.callout(
        "不是方士召唤物",
        "山海万灵是账号级收藏与确定性养成系统。它不克隆 NPC、不占方士虎鹤龟名额、不进入仇恨表，也不参与三灵共鸣；PVE完整成长，人物PVP采用压缩成长、回合充能、每场两次且禁止补刀。",
        "gold",
    )
    guide.paragraph(
        "首批收录当康、鹿蜀、文鳐鱼、毕方、狰、孟极、讙、九尾狐、狡、乘黄、天狗、夔、英招、穷奇、应龙十五种异兽。名称和文化意象参考中国古籍，技能、数值、灵纹组合、裂隙剧情与视觉演绎均为仙道原创设计。"
    )
    guide.table(
        ["模块", "怎么玩", "为什么值得长期参与"],
        [
            ["万灵初契", "15级从当康、鹿蜀、文鳐鱼中选择一只；其余可用30灵印稳定兑换", "没有不可逆的强弱选择"],
            ["成长助手", "按账号状态动态推荐初契、出战、寻迹、培养、装备、拓印、升星、羁绊、裂隙等下一步", "首页显示首要目标，完整页最多三项且可一键直达"],
            ["图鉴培养", "宠物最高60级、十星、五阶羁绊；真实PVE战斗自动获得宠物经验并连续升级", "收集、升级、升星、进化、异色和组合展示"],
            ["灵宠装备", "独立兽铠/灵饰/灵核三槽；初契三件套免费，5灵印凝炼后穿戴或分解", "不占人物背包；一件不能被两宠共用"],
            ["灵技拓印", "宠物20级并穿灵核后，可学习主人已会的一项主动攻击或治疗技能", "首次免费，替换1灵纹符；按宠物属性和安全上限重算"],
            ["PVE协战", "按灵纹冷却触发伤害、恢复或守护效果，完整培养成长但不能造成最后一击", "在战斗小窗中持续陪伴，但不取代职业输出"],
            ["PVP御灵", "4—6个有效战斗节拍充能，每场最多2次；额外成长仅折算20%且不能补刀", "养成有存在感，但不会凭宠物碾压人物职业体系"],
            ["隐藏鸾鸟", "70级以上首领极低概率完整掉落，500次合格首领保底；未获得时不显示图鉴", "回生羽账号每日1次，复活主人并恢复15%生命/10%法力；灵医复苏优先"],
            ["今日寻迹", "协战伙伴击败三只等级合适的真实NPC后领取独立材料", "每天一个短目标，不占人物背包"],
            ["万灵裂隙", "3-5名不同注册账号玩家协作，12轮内完成破阵、守御、疗愈、封印和缚灵", "周轮替异兽、团队分工、完整灵卵与保底"],
            ["三宠论道", "双方各三只宠物，标准化三局两胜", "公平研究阵容，不被人物等级、装备或VIP压制"],
        ],
        [1.0, 3.0, 2.1],
        compact=True,
    )
    guide.h2("5.1 战斗中的陪伴感")
    guide.bullets(
        [
            "战斗小窗常驻显示当前伙伴的等级、星级、进化、战力，以及PVE冷却或PVP充能和本场次数。",
            "触发协战时按灵属播放宠物跃入、技能光效、伤害或治疗飘字，并写入独立战斗日志。",
            "事件使用唯一编号去重，不会因轮询、切换人物或重复响应反复播放。",
            "同一只协战宠物升级时显示灵光跃迁成长卡；连续跨级合并显示，换宠和首次登录不会误触发。",
            "关闭视觉特效或系统启用减少动态效果后，动画会自动收敛，规则结算保持一致。",
        ]
    )

    guide.h1("6. PVE内容、地图与长期挑战")
    guide.table(
        ["内容", "开放/规则", "追求"],
        [
            ["每日修行", "签到、同阶除魔、施法、任务、灵宠与采集组成真实目标；20/50/80/100点领取宝箱", "每天都有明确下一步，VIP不增加次数"],
            ["任务与职业链", "普通任务填补升级间隔；中立职业拥有20级与53级连续职业任务", "技能书、专属挂件、职业故事"],
            ["副本", "注册副本通常关闭动态缩放，特殊区域可保留动态规则", "团队挑战、稳定路线与独立奖励"],
            ["固定练级图", "1-69级怪物等级连续，自动寻路选择安全目标", "平稳升级且避免地图断档"],
            ["动态怪", "70级后按人物等级与难度生成，含精英和Boss概率", "境界装备与隐藏技能书资格"],
            ["九霄界境", "990级开放五张互联地图，基础怪为999级，安全边界1000级", "为未来终局和管理验证预留"],
            ["万灵裂隙", "每周轮替异兽，3-5人跨职业协作", "宠物收藏、周目标与社交组队"],
        ],
        [1.0, 3.0, 2.0],
    )
    guide.callout(
        "空图不会原地卡住",
        "智能挂机会在当前区域巡游；没有安全目标、怪物刷新中或地图已清空时，会主动切换到适合人物等级且可到达的练级地图。",
    )

    guide.h1("7. 社交、家园与世界分区")
    guide.table(
        ["系统", "主要体验", "兼容与安全设计"],
        [
            ["队伍", "邀请、弹窗确认、同房战斗与职业协作", "邀请有时效；跨房、跨逻辑区和死亡状态严格过滤"],
            ["帮派", "成员、排行、协作与长期组织", "沿用既有帮派数据和权限"],
            ["家园", "住房、种养、功能房、店铺和旧守宅宠物", "老家园数据原样兼容；合区冲突使用多维位置"],
            ["意见反馈", "设置中提交建议并查看审核状态", "采纳后只奖励一次100碎玉，离线也能安全补发"],
            ["逻辑分区", "同一进程可配置隔离新区或合并区", "隔离区互不可见、不可组队或PK；配置可逆"],
            ["合区", "无需改人物档案即可恢复跨区可见和共同玩法", "家园独占位置通过区维度保留，不覆盖老数据"],
        ],
        [1.0, 2.5, 2.4],
        compact=True,
    )

    guide.h1("8. 一个账号，多种职业")
    guide.callout(
        "兼容老账号",
        "老账号仍可使用原人物ID和原密码直接登录，不迁移、不改名、不改变原存档路径。只有第一次建立第二个人物或使用共享资源时，才按需创建账号级附属文件。",
        "gold",
    )
    guide.table(
        ["能力", "当前规则", "防复制/防越权边界"],
        [
            ["多人物档案", "一个注册账号最多10个人物，每个职业独立等级、技能、装备、背包、任务和家园", "人物仍是独立标准存档，账号索引原子写入"],
            ["同时在线", "默认允许同账号最多5个人物在线，可用配置热切回1", "相同人物永远只有一个对象；同账号命令串行"],
            ["共享宝库", "个人仓库与账号宝库按永久物品ID直接互转", "pending托管、重启对账、同ID全局只存在一份"],
            ["共享充值", "现金充值余额和累计充值权益属于注册账号", "人物免费所得玉石不迁移；消费串行且有事务流水"],
            ["角色选择", "账号中心显示职业摘要与共享余额", "随机账号令牌只允许选择归属人物，不能执行游戏命令"],
            ["密码修改", "账号下全部人物统一原子修改", "任一步失败就不替换，旧令牌和密码缓存同步撤销"],
        ],
        [1.0, 3.1, 2.1],
        compact=True,
    )
    guide.h2("8.1 什么共享，什么不共享")
    guide.table(
        ["共享", "保持人物独立"],
        [
            ["注册密码、人物索引、账号共享宝库、现金充值余额、累计充值权益、山海万灵图鉴和材料", "等级、职业技能、穿戴装备、背包、个人仓库、任务、社交、家园、免费玉石和人物战斗状态"],
        ],
        [1.0, 1.0],
    )

    guide.h1("9. 智能挂机与现代界面")
    guide.table(
        ["体验", "游戏如何处理", "玩家仍然掌握什么"],
        [
            ["自动战斗", "根据职业、已学阶段、法力、冷却、武器与目标选择技能，失败时回退普通攻击", "技能模式、路线、补给与是否启用"],
            ["智能寻路", "寻找匹配等级怪物，空图时巡游或切图", "指定区域、手动移动和立即停止"],
            ["补给休整", "按阈值吃药、回蓝和休息；选择饮品后显示勾选状态", "药品选择、阈值与背包准备"],
            ["拾取清包", "安全拾取；按VIP档位自动出售、存仓或销毁可处理物品", "类别、品质、保留数量、名称保护"],
            ["战斗小窗", "位于底部菜单上方，显示真实敌名、血法、状态、宠物和技能动画", "折叠、视觉特效、字体与动态效果"],
            ["响应式界面", "按钮、间距和字体适配手机、平板、电脑浏览器", "字体大小、快捷入口和设置"],
        ],
        [1.0, 3.1, 2.0],
        compact=True,
    )
    guide.h2("9.1 挂机时长")
    guide.table(
        ["身份", "每日时长", "逐级便利"],
        [
            ["普通", "8小时", "战斗、寻路、补给、巡游、采集与原料出售"],
            ["VIP1 水晶", "10小时", "白装处理、每次1组"],
            ["VIP2 黄金", "12小时", "优良装处理、每次2组、类别选择"],
            ["VIP3 白金", "14小时", "精制装处理、每次4组、材料保留量"],
            ["VIP4 钻石", "16小时", "每次8组、名称保护与处理优先级"],
        ],
        [1.2, 1.0, 3.4],
    )

    guide.h1("10. VIP与公平商业化边界")
    guide.paragraph(
        "仙道把核心职业能力与付费便利分开：所有技能、治疗、召唤、护盾、嘲讽、星痕和宠物基础玩法都能手动使用；会员提供更长挂机、分级自动化、等级突破和展示便利，不直接出售PVP必中、宠物属性或隐藏技能掉率。"
    )
    guide.table(
        ["身份", "有效期人物上限", "自动化定位"],
        [
            ["普通", "120", "核心玩法完整，手动技能与每日8小时挂机"],
            ["VIP1 水晶", "140", "监测提醒与基础清包"],
            ["VIP2 黄金", "160", "PVE职业助手开始按真实资源自动执行"],
            ["VIP3 白金", "180", "队伍救急、职业策略与更细清包"],
            ["VIP4 钻石", "200", "最高16小时与完整便利配置"],
        ],
        [1.2, 1.3, 3.4],
    )
    guide.bullets(
        [
            "VIP过期不会降低已有等级，只会停止继续突破当前有效身份的上限。",
            "职业助手只在PVE工作，面对玩家及玩家召唤物会拒绝自动施放。",
            "山海宠物不出售PVP属性、额外裂隙伤害、额外有奖对手或暗增概率。",
            "客户端按钮不能修改价格、库存、会员期限或奖励；服务器会重新校验并要求关键操作二次确认。",
        ]
    )

    guide.h1("11. 新玩家第一天建议")
    guide.table(
        ["顺序", "建议动作", "完成标志"],
        [
            ["1", "选择最想体验的职业，不必先追求所谓最强", "获得起手技能和基础装备"],
            ["2", "跟随20步新手引导真实操作", "每一步出现完成弹窗并自动领奖"],
            ["3", "打开职业技能书商店并在背包学习", "myskills能看到新技能"],
            ["4", "开启智能挂机前配置红蓝药、阈值和安全拾取", "能自动打怪、休整并在空图切换"],
            ["5", "15级完成万灵初契并设置协战伙伴", "战斗小窗显示宠物与协战冷却"],
            ["6", "20级完成职业任务，加入队伍体验定位", "取得专属奖励并理解职业循环"],
            ["7", "把第一件长期装备作为锻造、宝石和仓库练习", "理解穿戴限制与物品保护"],
            ["8", "查看今日修行、反馈、帮派、家园与宠物入口", "找到升级之外的长期目标"],
        ],
        [0.55, 3.2, 2.0],
    )

    guide.h1("12. 常见问题")
    guide.table(
        ["问题", "答案"],
        [
            ["买完技能书为什么技能页没有？", "购买只把书放入背包；还要点击书上的学习，并满足职业、等级和前置条件。"],
            ["没组队时治疗谁？", "方士和灵医的合法治疗会回到自己；不会治疗同房间路人。"],
            ["宠物会抢方士召唤位置吗？", "不会。万灵是数据型协战，和虎灵、鹤灵、龟灵是两套独立系统。"],
            ["宠物能在人物PVP中帮打吗？", "可以有限参与：每场最多2次，额外养成只折算20%，伤害有生命比例硬上限且不能补刀；三宠论道仍是独立标准化玩法。"],
            ["宠物装备在哪里掉落？", "当前不直接掉装备。首只宠物免费领初契三件套；高品质装备用5灵印凝炼，灵印可从寻迹、裂隙和论道获得。"],
            ["宠物如何学主人技能？", "达到20级、穿上灵核，再从宠物详情进入灵技拓印。只能选当前角色真实学会的主动攻击或治疗技能；首次免费。"],
            ["宠物下一步该做什么？", "打开万灵谱查看成长助手。它会按限时奖励、日课和养成阶段排序，提供直接操作按钮；助手只读，不会擅自消耗材料。"],
            ["组队经验加成消失了吗？", "没有。2/3/4/5名有效同房队员共享120%/140%/160%/200%经验池，再按人数分配；当前版本会在每次经验结果中明示池加成。"],
            ["同账号人物会共享装备和玉石吗？", "装备只有主动转入共享宝库后才共享；免费玉石属于人物，现金充值余额属于注册账号。"],
            ["同一个账号能同时玩几个职业？", "当前默认最多5个人物同时在线，运营可热配置为1-10；相同人物永远不能重复上线。"],
            ["挂机提示有怪却不攻击怎么办？", "当前会重新检查安全目标、恢复被动态化的低级怪，并在空图或无合适目标时主动切图。"],
            ["120级后为什么不再升级？", "普通上限为120；有效VIP1至VIP4分别开放140、160、180、200级。"],
            ["九霄地图为什么看得见却进不去？", "九霄界境从990级开放，目前主要是未来终局和管理验证内容。"],
            ["反馈被采纳后如何领奖？", "管理员采纳后固定发放一次100碎玉；离线或暂时保存失败会在下次登录补发。"],
            ["每日目标必须全部做完吗？", "不必。签到、同阶除魔、施法和完成任务可到80点；再完成灵宠协战或采集中的一项即可达到100点。"],
        ],
        [2.0, 3.6],
        compact=True,
    )

    guide.pagebreak()
    guide.h1("13. 文档边界与继续查阅")
    guide.paragraph(
        "本介绍面向玩家说明当前整体体验。需要精确等级、技能书价格、全部技能对象、装备境界与方士/镇越/天象/灵医里程碑时，请继续查阅仓库中的《仙道全职业技能与装备成长手册》和《仙道全职业技能指南》。"
    )
    guide.table(
        ["文档", "适合查询"],
        [
            ["xiand-all-professions-progression-guide.pdf", "从创建到高阶的职业、技能、装备、任务、地图与公共系统"],
            ["xiand-all-professions-skill-guide.pdf", "十职业全部技能、隐藏技能、书籍来源与学习条件"],
            ["shanhai-wanling-system.md", "宠物持久化、协战、裂隙、论道、公平性和运维边界"],
            ["multi-character-account.md", "多人物档案、共享宝库、共享充值和并发登录安全"],
            ["daily-retention-loop.md", "签到、每日目标、活跃奖励、跨日与多人物公平边界"],
        ],
        [2.4, 3.2],
    )
    guide.callout(
        "版本声明",
        f"本文生成于 {build_date}，分支 {branch}，内容基线 {commit}。活动、每日轮换、库存、价格和运营开放范围以服务器当日界面为准。",
        "gold",
    )

    MD_PATH.write_text("\n".join(guide.md).rstrip() + "\n", encoding="utf-8")
    doc.multiBuild(story)
    DESKTOP_PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PDF_PATH, DESKTOP_PDF_PATH)


if __name__ == "__main__":
    build_game_introduction()
