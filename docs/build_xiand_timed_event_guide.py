#!/usr/bin/env python3
"""Build the standalone Xiand timed PVP/PVE event handbook."""

from __future__ import annotations

import datetime as dt
import html
import json
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
    RED,
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


PDF_PATH = DOCS / "xiand-timed-pvp-pve-event-guide.pdf"
MD_PATH = DOCS / "xiand-timed-pvp-pve-event-guide.md"
OUTPUT_PDF_PATH = ROOT / "output/pdf/xiand-timed-pvp-pve-event-guide.pdf"
DESKTOP_PDF_PATH = Path.home() / "Desktop" / "仙道限时PVE与PVP活动手册.pdf"
CONFIG_PATH = ROOT / "gamelib/etc/timed_events.json"


class TimedEventGuideDoc(GuideDocTemplate):
    """Shared handbook layout with event-specific running heads."""

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
            PageTemplate(id="timed-event", frames=[frame], onPage=self._on_event_page)
        )

    def _on_event_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("仙道限时PVE与PVP活动手册")
        canvas.setAuthor("Xiand Project")
        canvas.setSubject("天衡绝境与九曜镇渊玩家规则及运营说明")
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
                LEFT_MARGIN, PAGE_H - 8.5 * mm, "仙道限时PVE与PVP活动手册"
            )
            canvas.drawRightString(
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 8.5 * mm,
                "天衡绝境 · 九曜镇渊",
            )
            canvas.line(LEFT_MARGIN, 10 * mm, PAGE_W - RIGHT_MARGIN, 10 * mm)
            canvas.drawCentredString(PAGE_W / 2, 6.5 * mm, f"- {doc.page} -")
        canvas.restoreState()


def event_time(hour: int, minute: int, offset_seconds: int = 0) -> str:
    total = hour * 3600 + minute * 60 + offset_seconds
    total %= 24 * 3600
    return f"{total // 3600:02d}:{total % 3600 // 60:02d}"


def format_duration(seconds: int) -> str:
    if seconds % 3600 == 0:
        return f"{seconds // 3600}小时"
    if seconds >= 3600:
        return f"{seconds // 3600}小时{seconds % 3600 // 60}分钟"
    return f"{seconds // 60}分钟"


def reward_values(level: int, multiplier: int) -> tuple[int, int]:
    base_exp = level * level * 3 + 500
    base_money = level * 200 + 1000
    return base_exp * multiplier, base_money * multiplier


def add_cover(
    story: list,
    guide: HandbookBuilder,
    styles: dict[str, ParagraphStyle],
    branch: str,
    commit: str,
    build_date: str,
) -> None:
    story.append(Spacer(1, 14 * mm))
    logo_path = ROOT / "images/logo.png"
    if logo_path.exists():
        story.append(Image(str(logo_path), width=28 * mm, height=28 * mm, hAlign="CENTER"))
        story.append(Spacer(1, 6 * mm))
    story.append(Paragraph("仙道限时 PVE 与 PVP 活动手册", styles["CoverTitle"]))
    story.append(
        Paragraph(
            "天衡绝境 · 随机镜域生存赛　｜　九曜镇渊 · 九宫封脉协作战",
            styles["CoverSub"],
        )
    )
    story.append(Spacer(1, 10 * mm))
    cover_rows = [
        ["PVP", "每日20:00集结", "随机1v1 · 一次落败结算 · 三种战势"],
        ["PVE", "每日21:00集结", "九宫追猎 · 协力封脉 · 动态巡游首领"],
    ]
    data = [
        [
            Paragraph("玩法", styles["TableHead"]),
            Paragraph("北京时间", styles["TableHead"]),
            Paragraph("核心体验", styles["TableHead"]),
        ]
    ]
    for row in cover_rows:
        data.append([Paragraph(html.escape(cell), styles["Body"]) for cell in row])
    cover_table = Table(
        data,
        colWidths=[24 * mm, 43 * mm, 91 * mm],
        hAlign="CENTER",
    )
    cover_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("BACKGROUND", (0, 1), (-1, 1), colors.HexColor("#FFF4F1")),
                ("BACKGROUND", (0, 2), (-1, 2), TEAL_LIGHT),
                ("GRID", (0, 0), (-1, -1), 0.5, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (0, 0), (1, -1), "CENTER"),
                ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
            ]
        )
    )
    story.append(cover_table)
    story.append(Spacer(1, 16 * mm))
    meta_style = ParagraphStyle(
        "TimedEventCoverMeta",
        parent=styles["Small"],
        alignment=TA_CENTER,
        textColor=MUTED,
    )
    story.append(
        Paragraph(
            f"发布分支：{html.escape(branch)}　内容基线：{html.escape(commit)}　生成日期：{build_date}",
            meta_style,
        )
    )
    story.append(
        Paragraph(
            "依据当前服务器代码、配置与 TestUnit 生成；实际开放状态以游戏内限时玩法页面为准。",
            ParagraphStyle(
                "TimedEventCoverNote",
                parent=meta_style,
                textColor=RED,
                spaceBefore=2 * mm,
            ),
        )
    )
    guide.md.extend(
        [
            "# 仙道限时 PVE 与 PVP 活动手册",
            "",
            "天衡绝境 · 随机镜域生存赛 | 九曜镇渊 · 九宫封脉协作战",
            "",
            f"- 发布分支：`{branch}`",
            f"- 内容基线：`{commit}`",
            f"- 生成日期：{build_date}",
            "",
            "> 本手册依据当前服务器代码、配置与 TestUnit 生成；实际开放状态以游戏内限时玩法页面为准。",
            "",
        ]
    )
    story.append(PageBreak())


def add_toc(story: list, styles: dict[str, ParagraphStyle]) -> None:
    story.append(
        Paragraph(
            "目录",
            ParagraphStyle("TimedEventTOCTitle", parent=styles["H1"]),
        )
    )
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle(
            "TimedEventTOC1",
            fontName="XiandBold",
            fontSize=9.5,
            leading=15,
            textColor=NAVY,
            spaceAfter=1.5 * mm,
        ),
        ParagraphStyle(
            "TimedEventTOC2",
            fontName="XiandBody",
            fontSize=8.3,
            leading=12,
            leftIndent=6 * mm,
            textColor=INK,
            spaceAfter=0.8 * mm,
        ),
    ]
    story.extend([toc, PageBreak()])


def build_guide() -> None:
    register_fonts()
    styles = build_styles()
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    tianheng = config["events"]["tianheng"]
    jiuyao = config["events"]["jiuyao"]
    branch = "main"
    commit = git_value("rev-parse", "--short=10", "origin/main")
    build_date = dt.date.today().isoformat()

    doc = TimedEventGuideDoc(
        str(PDF_PATH),
        styles,
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="仙道限时PVE与PVP活动手册",
        author="Xiand Project",
    )
    story: list = []
    guide = HandbookBuilder(story, styles)
    add_cover(story, guide, styles, branch, commit, build_date)
    add_toc(story, styles)

    tianheng_start = event_time(tianheng["hour"], tianheng["minute"])
    tianheng_battle = event_time(
        tianheng["hour"], tianheng["minute"], tianheng["signup_seconds"]
    )
    tianheng_end = event_time(
        tianheng["hour"],
        tianheng["minute"],
        tianheng["signup_seconds"] + tianheng["battle_seconds"],
    )
    jiuyao_start = event_time(jiuyao["hour"], jiuyao["minute"])
    jiuyao_battle = event_time(
        jiuyao["hour"], jiuyao["minute"], jiuyao["signup_seconds"]
    )
    jiuyao_end = event_time(
        jiuyao["hour"],
        jiuyao["minute"],
        jiuyao["signup_seconds"] + jiuyao["battle_seconds"],
    )

    guide.h1("1. 一页快速上手")
    guide.callout(
        "入口在哪里",
        "新Vue界面点击底部“限时玩法”，旧界面点击常用功能中的“限时玩法”；集结开始时在线玩家还会收到一次活动弹窗。也可以直接执行 timed_event 查看活动页。",
        "gold",
    )
    guide.table(
        ["玩法", "集结时间", "正式战斗", "门槛", "当天资格"],
        [
            [
                "天衡绝境（PVP）",
                f"{tianheng_start}-{tianheng_battle}",
                f"{tianheng_battle}-{tianheng_end}，最长{format_duration(tianheng['battle_seconds'])}",
                f"{tianheng['minimum_level']}级；至少{tianheng['minimum_players']}人",
                "正式开战后记为已参加；落败、认输或超时离线后不能重进",
            ],
            [
                "九曜镇渊（PVE）",
                f"{jiuyao_start}-{jiuyao_battle}",
                f"{jiuyao_battle}-{jiuyao_end}，最长{format_duration(jiuyao['battle_seconds'])}",
                f"{jiuyao['minimum_level']}级；至少{jiuyao['minimum_players']}人",
                "正式开战后记为已参加；死亡、撤离或超时离线后不能重进",
            ],
        ],
        [1.2, 1.05, 1.55, 1.15, 2.0],
        compact=True,
    )
    guide.bullets(
        [
            "全部时间按配置中的UTC+8计算，不受生产服务器所在时区影响。当前即北京时间。",
            "只有十分钟集结期可以进入；显示“已经开战”时不能中途加入。",
            "报名时必须结束当前战斗；进入后服务器会停止普通自动挂机，避免助手把人物带离玩法节奏。",
            "集结期主动退出不会消耗当天资格；正式开战后退出会立即按认输或撤离结算。",
            "两个活动资格彼此独立，同一人物同一天可以各参加一次。",
        ]
    )
    guide.h2("1.1 通用生命周期")
    guide.table(
        ["阶段", "玩家动作", "服务器行为", "能否加入"],
        [
            ["未开放", "查看规则与令牌余额", "不创建场次", "否"],
            ["集结", "报名、阅读规则；PVP选择战势", "记录安全返回点并进入独立候场房", "是"],
            ["开战", "PVP移动配对；PVE移动、封脉、迎战", "补满生命与法力并标记当天资格", "否"],
            ["结算", "查看奖励消息", "保存名次/结果，发放经验、金币和令牌", "否"],
            ["返回", "继续普通游戏", "清理战斗并返回原安全地图；无效路径回阵营广场", "否"],
        ],
        [0.75, 1.55, 2.8, 0.7],
    )

    guide.pagebreak()
    guide.h1("2. 天衡绝境：随机镜域 PVP")
    guide.paragraph(
        "天衡绝境不是同房自由混战。所有存活者先在天衡台等待，踏入任意衡门后进入随机队列；系统每次随机抽取两人，创建只属于这场决斗的镜域。外人无法进入，因此从空间结构上排除多人围攻、堵门和主观合围。"
    )
    guide.h2("2.1 从报名到冠军")
    guide.table(
        ["顺序", "发生什么", "关键边界"],
        [
            ["1", "集结期报名并选择锋势、守势或变势", "默认是变势；开战后不能更改"],
            ["2", "开战时生命、法力补满并送往天衡台", "报名不足2人则取消且不消耗资格"],
            ["3", "向任意方向移动进入随机队列", f"{tianheng['force_match_seconds']}秒不操作也会自动排队"],
            ["4", "两人进入独立镜域，以人物真实战斗系统决斗", "普通逃跑被拦截，只能继续战斗或认输"],
            ["5", "落败者立即按剩余人数结算，胜者回天衡台", "一次落败即出局，当天不能重进"],
            ["6", "最后一人获第一；到时仍多人存活则按规则排序", "极端长局仍受普通PK快速决胜机制约束"],
        ],
        [0.5, 3.0, 2.4],
    )
    guide.h2("2.2 三种战势的精确效果")
    guide.table(
        ["战势", "每轮进入镜域时", "胜出后", "适合思路"],
        [
            ["锋势", "压制对手2%最大生命；对手为守势时减半为1%；不能直接压到0", "无额外恢复", "争取起手血线优势"],
            ["守势", "恢复自己4%最大生命，不超过生命上限", "无额外恢复", "连续作战与高承伤职业"],
            ["变势", "恢复自己10%最大法力，不超过法力上限", "再恢复6%最大生命与6%最大法力", "技能循环与多轮续航"],
        ],
        [0.65, 2.55, 1.7, 1.4],
        compact=True,
    )
    guide.callout(
        "战势不改变永久属性",
        "三种战势只在本次活动的入场与胜出节点生效，不写入人物永久攻防，不提供必中、免死、额外入场或VIP专属优势。",
    )
    guide.h2("2.3 淘汰、名次与超时")
    guide.bullets(
        [
            "正常淘汰名次 = 淘汰完成后仍存活人数 + 1。例如淘汰后剩2人，该玩家就是第3名。",
            "主动认输与战斗死亡使用相同淘汰流程；奖励准备完成后立即安全送回原地图。",
            f"断线开始计时，超过{tianheng['offline_grace_seconds']}秒仍未恢复则淘汰；镜域中的在线对手按胜者处理。",
            "达到活动时限仍有多人存活时，先按胜场从高到低，再按当前生命比例从高到低排序；仍相同则以角色ID稳定决胜，保证结果可重复。",
            "查看排名会列出全部存活者的胜场，并按倒序显示已经确定的淘汰名次。",
        ]
    )

    guide.pagebreak()
    guide.h1("3. 九曜镇渊：九宫封脉 PVE")
    guide.paragraph(
        "九曜镇渊是一场路线控制与动态首领协作战。所有玩家从九曜心出发，巡渊主从玄枢台出现并沿未封闭的相邻曜脉巡游。玩家需要判断路线、封闭阵位、追击首领，并处理四个阶段依次降临的渊将。"
    )
    guide.h2("3.1 九宫地图与出生位置")
    guide.table(
        ["西", "中", "东"],
        [
            ["玄枢台 [0]\n巡渊主出生", "星槎径 [1]", "青阙门 [2]\n燎空渊将"],
            ["金衡道 [3]", "九曜心 [4]\n玩家出生 / 蚀月渊将", "赤轮道 [5]"],
            ["沧渊门 [6]\n断潮渊将", "月隐径 [7]", "天纪台 [8]\n沉山渊将"],
        ],
        [1, 1, 1],
    )
    guide.paragraph(
        "地图只允许上下左右相邻移动，不存在斜向跳格。战斗中不能移动；首领处于交战状态时不会巡游。",
        small=True,
    )
    guide.h2("3.2 封脉机制")
    guide.table(
        ["项目", "当前规则", "策略意义"],
        [
            ["响应人数", "存活1-3人时1人完成；存活4人及以上时需要2名不同玩家", "小队减员后仍可继续，不让单人场失去解法"],
            ["重复响应", "同一玩家不能为同一次未完成封脉重复注入", "阻止单人重复点击伪造双人协作"],
            ["封闭时长", f"成功后封闭{jiuyao['seal_seconds']}秒", "首领与渊将不会进入该阵位"],
            ["直接反噬", "每次成功封脉令巡渊主损失2%最大生命，但不会由这一击直接归零", "封路本身也是稳定推进手段"],
            ["围困反噬", "首领所有相邻阵位都不可进入时，每个移动周期再损失1%最大生命", "通过协作形成持续围困收益"],
            ["首领巡游", f"未交战时每{jiuyao['boss_move_seconds']}秒尝试移动到随机未封闭相邻阵位", "需要预判而非原地站桩输出"],
        ],
        [1.0, 2.8, 2.0],
        compact=True,
    )
    guide.h2("3.3 四渊将与主动追猎")
    guide.table(
        ["战局进度", "北京时间（默认配置）", "渊将", "出现位置"],
        [
            ["20%", event_time(jiuyao["hour"], jiuyao["minute"], jiuyao["signup_seconds"] + jiuyao["battle_seconds"] // 5), "沉山渊将", "天纪台 [8]"],
            ["40%", event_time(jiuyao["hour"], jiuyao["minute"], jiuyao["signup_seconds"] + jiuyao["battle_seconds"] * 2 // 5), "燎空渊将", "青阙门 [2]"],
            ["60%", event_time(jiuyao["hour"], jiuyao["minute"], jiuyao["signup_seconds"] + jiuyao["battle_seconds"] * 3 // 5), "断潮渊将", "沧渊门 [6]"],
            ["80%", event_time(jiuyao["hour"], jiuyao["minute"], jiuyao["signup_seconds"] + jiuyao["battle_seconds"] * 4 // 5), "蚀月渊将", "九曜心 [4]"],
        ],
        [0.8, 1.35, 1.5, 1.5],
    )
    guide.bullets(
        [
            "巡渊主或渊将与存活玩家处于同一阵位且自己未交战时，会随机选择一名玩家主动开战。",
            "击败渊将会增加全队镇渊进度；当前胜利条件仍是击碎巡渊主核心，不强制先杀完四将。",
            "首领强度按参赛者动态生成：生命规模随全体有效生命总量增长，攻势参考参赛者力量/智力中的较高值，避免固定等级首领被高属性版本瞬间淘汰。",
        ]
    )
    guide.h2("3.4 胜负条件")
    guide.table(
        ["结果", "触发条件", "结算对象"],
        [
            ["成功", "巡渊主死亡", "仍存活玩家获得成功奖励；已提前出局者保留参与奖励"],
            ["失败", "活动时间耗尽且仍有人存活", "存活玩家获得守关奖励；已出局者保留参与奖励"],
            ["全灭", "最后一名存活玩家也被击败或超时离线", "所有已出局玩家均按参与奖励结算"],
            ["撤离", "玩家主动点击撤离", "该玩家立即获得参与奖励，当天不能再入场"],
        ],
        [0.75, 2.4, 2.8],
    )

    guide.pagebreak()
    guide.h1("4. 奖励公式与令牌")
    guide.h2("4.1 基础公式")
    guide.table(
        ["奖励", "基础值（L为报名时角色等级）", "说明"],
        [
            ["经验", "L × L × 3 + 500", "按结算档位乘倍率，再走统一经验发放接口"],
            ["金币", "L × 200 + 1000", "按结算档位乘倍率，直接进入人物金币"],
            ["天衡令/九曜令", "按名次或结果固定", "记录在当前人物的限时玩法状态中"],
        ],
        [0.85, 2.1, 2.8],
    )
    guide.h2("4.2 各档倍率")
    guide.table(
        ["玩法结果", "经验/金币倍率", "令牌"],
        [
            ["天衡第1名", "×5", "天衡令12"],
            ["天衡第2名", "×3", "天衡令8"],
            ["天衡第3名", "×2", "天衡令5"],
            ["天衡第4名及以后", "×1", "天衡令1"],
            ["九曜成功且结算时存活", "×4", "九曜令8"],
            ["九曜超时失败但结算时存活", "×2", "九曜令2"],
            ["九曜提前出局/撤离", "×1", "九曜令1"],
        ],
        [2.3, 1.4, 1.25],
    )
    example_rows: list[list[object]] = []
    for level in (30, 60, 120):
        base_exp, base_money = reward_values(level, 1)
        pvp_exp, pvp_money = reward_values(level, 5)
        pve_exp, pve_money = reward_values(level, 4)
        example_rows.append(
            [
                level,
                f"{base_exp:,}经验 / {base_money:,}金币",
                f"{pvp_exp:,}经验 / {pvp_money:,}金币 / 12令",
                f"{pve_exp:,}经验 / {pve_money:,}金币 / 8令",
            ]
        )
    guide.h2("4.3 等级示例")
    guide.table(
        ["等级", "基础参与档", "天衡第1名", "九曜成功档"],
        example_rows,
        [0.55, 1.8, 2.2, 2.2],
        compact=True,
    )
    guide.callout(
        "表中经验是活动基础值",
        "服务器发放时调用统一 add_exp_with_bonus 接口。若HTTP接口经验加成开关开启，实际经验会按该全局倍率增加并在结算消息中显示；达到当前人物等级上限时，经验接口可能返回0。VIP没有活动专属战斗加成、奖励倍率或额外入场次数。",
        "gold",
    )
    guide.callout(
        "令牌已经可以消费",
        "活动主页提供令牌兑换商店。天衡令与九曜令分别消费，兑换实物均为人物绑定物品；永久徽记只记录收藏成就，不提供攻防或奖励倍率。",
    )
    guide.pagebreak()
    guide.h2("4.4 令牌兑换商店")
    guide.table(
        ["天衡令", "消耗", "实际用途"],
        [
            ["天衡金囊", "1令", "立即获得10,000金币"],
            ["天衡传音符", "3令", "获得1张绑定千里传音符，用于向全服发言"],
            ["天衡免战符", "10令", "获得1张绑定免战符，使用后免战1小时"],
            ["绑定玄黄石", "12令", "基础锻造宝石"],
            ["绑定金刚钻", "36令", "高阶锻造宝石"],
            ["天衡百战徽记", "100令", "永久收藏徽记，只能兑换一次，无战斗数值"],
        ],
        [1.45, 0.75, 3.9],
        compact=True,
    )
    guide.table(
        ["九曜令", "消耗", "实际用途"],
        [
            ["九曜金囊", "1令", "立即获得10,000金币"],
            ["绑定玄黄石", "8令", "基础锻造宝石"],
            ["绑定玉翡翠", "20令", "进阶锻造宝石"],
            ["绑定金刚钻", "36令", "高阶锻造宝石"],
            ["绑定紫水晶", "50令", "顶阶锻造宝石"],
            ["九曜镇渊徽记", "100令", "永久收藏徽记，只能兑换一次，无战斗数值"],
        ],
        [1.45, 0.75, 3.9],
        compact=True,
    )
    guide.bullets(
        [
            "商店先进入确认页，余额不足、包袱已满、战斗中或活动场内都不会扣令牌。",
            "绑定实物不能交易、赠送或丢弃，但允许存入人物仓库。",
            "发放物品后才扣令牌；人物存档失败时会回滚金币、物品、徽记和令牌，防止丢失或复制。",
            "兑换成功写入独立审计日志；永久徽记重复点击不会再次扣令牌。",
        ]
    )
    guide.pagebreak()
    guide.h2("4.5 防重复发奖")
    guide.bullets(
        [
            "奖励先写入活动参与状态，再尝试发到人物；每个场次使用唯一领取凭据。",
            "人物保存成功后才把奖励标记为已领取；保存失败会提示处于待确认状态。",
            "断线或离线结算的玩家，下次进入游戏或打开活动页时会自动补领。",
            "同一场次凭据存在时不会再次增加经验、金币或令牌；人物只保留最近64条领取凭据。",
            "活动NPC死亡跳过普通怪物经验、任务进度和掉落链，避免活动奖励与普通奖励重复。",
        ]
    )
    guide.h1("5. 公平性、隔离与异常恢复")
    guide.h2("5.1 公平与逻辑区隔离")
    guide.table(
        ["边界", "服务器保证"],
        [
            ["VIP", "不增加活动攻防、战势数值、入场次数、封脉效率或活动奖励档位"],
            ["逻辑区", "场次键由玩法 + 日期 + 逻辑区组组成；隔离区玩家在房间、战斗、排名和奖励上不可见"],
            ["PVP围攻", "每场决斗使用独立克隆镜域，只允许交锋双方及其所属战斗对象存在"],
            ["传送与飞行", "活动外不能猜路径直飞；活动内不能用飞行、传送、跟随或普通移动离开"],
            ["普通逃跑", "战斗期逃跑命令被拦截，必须使用认输或撤离完成权威结算"],
            ["死亡惩罚", "活动状态机在普通复活、掉级、耐久、荣誉和常规死亡掉落前接管"],
        ],
        [1.15, 4.7],
    )
    guide.h2("5.2 断线与重新登录")
    guide.bullets(
        [
            f"两种玩法的断线宽限均为{tianheng['offline_grace_seconds']}秒；宽限内重新登录会恢复到权威活动场次。",
            "活动克隆房间不会覆盖人物正常 last_pos；恢复失败时不会把临时房间写成永久存档位置。",
            "超过宽限：天衡按淘汰结算；九曜按出局参与奖励结算。",
            "退出或活动结束后会清理战斗、补满生命与法力，并优先返回报名时记录的安全地图。",
        ]
    )
    guide.h2("5.3 服务器重启")
    guide.table(
        ["重启发生阶段", "处理方式", "玩家结果"],
        [
            ["集结期，尚未跨过开战点", "保留报名场次，重启后继续集结", "可继续等待或主动退出"],
            ["集结期重启跨过开战点", "安全取消，拒绝恢复不完整的开战状态", "不消耗正式参赛结果；无战斗奖励"],
            ["战斗期", "整场安全取消，不恢复NPC气血或PVP战斗快照", "无死亡惩罚；每名参与者补发1枚对应纪念令"],
        ],
        [1.6, 2.8, 2.0],
        compact=True,
    )
    guide.callout(
        "为什么战斗期不做断点续战",
        "NPC气血、玩家技能冷却、宠物状态、镜域对局和移动路线必须形成同一时刻的完整快照。当前实现选择安全取消并补纪念令，优先避免回档、复制奖励、双重死亡或不公平恢复。",
        "gold",
    )

    guide.pagebreak()
    guide.h1("6. 运营配置与部署")
    guide.paragraph(
        "权威配置文件为 gamelib/etc/timed_events.json。默认时区偏移为480分钟，即UTC+8。配置在活动守护进程创建时读取；代码提供 reload_config()，但当前没有面向普通运营人员的独立可视化编辑按钮。生产修改建议走版本审查并按标准流程重启。"
    )
    guide.h2("6.1 当前配置")
    guide.table(
        ["配置项", "天衡当前值", "九曜当前值", "允许范围"],
        [
            ["enabled", tianheng["enabled"], jiuyao["enabled"], "0或1"],
            ["hour / minute", f"{tianheng['hour']:02d}:{tianheng['minute']:02d}", f"{jiuyao['hour']:02d}:{jiuyao['minute']:02d}", "00:00-23:59"],
            ["signup_seconds", tianheng["signup_seconds"], jiuyao["signup_seconds"], "60-3600"],
            ["battle_seconds", tianheng["battle_seconds"], jiuyao["battle_seconds"], "300-7200"],
            ["minimum_level", tianheng["minimum_level"], jiuyao["minimum_level"], "1-1000"],
            ["minimum_players", tianheng["minimum_players"], jiuyao["minimum_players"], "1-200"],
            ["offline_grace_seconds", tianheng["offline_grace_seconds"], jiuyao["offline_grace_seconds"], "15-600"],
            ["force_match_seconds", tianheng["force_match_seconds"], "-", "天衡10-300"],
            ["seal_seconds", "-", jiuyao["seal_seconds"], "九曜30-600"],
            ["boss_move_seconds", "-", jiuyao["boss_move_seconds"], "九曜5-120"],
        ],
        [1.8, 1.3, 1.3, 1.25],
        compact=True,
    )
    guide.bullets(
        [
            "配置文件缺失、超过64KB、JSON损坏或字段越界时，守护进程会记录错误并使用安全默认值。",
            "活动运行数据自动创建在 data_xiand/timed_events/state.json，并维护 .bak 与临时原子替换文件；运行数据不应提交Git。",
            "状态文件超过4MB、结构损坏、单场参与者超过500或总场次超过256时拒绝载入，防止异常数据拖垮启动。",
            "已完成且全部奖励领取的场次保留14天后自动清理；存在待领奖励的场次不会提前删除。",
            "首次部署无需手工建立 timed_events 数据目录，守护进程在保存时自动创建。",
        ]
    )
    guide.h2("6.2 上线前检查清单")
    guide.table(
        ["检查", "通过标准"],
        [
            ["配置", "JSON可解析，时区、时间窗口和全部数值在允许范围内"],
            ["入口", "Vue快捷按钮、集结弹窗和旧界面 timed_event 链接都能打开"],
            ["隔离", "合并区共享场次，隔离区创建不同场次且互不可见"],
            ["PVP", "两人可随机配对、逃跑被拦截、死亡后只结算一次"],
            ["PVE", "九宫边界正确、首领可巡游、封脉人数随存活人数变化"],
            ["重启", "战斗期安全取消且补1令，状态文件和备份文件可读取"],
            ["测试", "test_timed_event_system.pike 与 Vue timed-event-ui.test.js 通过"],
        ],
        [1.0, 4.8],
    )

    guide.pagebreak()
    guide.h1("7. 常见问题")
    guide.table(
        ["问题", "答案"],
        [
            ["为什么活动按钮在，但不能进入？", "检查是否处于十分钟集结期、是否达到30级、是否仍在战斗，以及今天是否已正式参加过该玩法。"],
            ["为什么开战后不能补进？", "场次在集结结束时锁定参与者、逻辑区和动态强度；中途加入会破坏PVP排名与PVE首领规模。"],
            ["报名后退出会浪费次数吗？", "集结期退出不会。资格在正式开战、人物被接纳进入战场时才写入。"],
            ["PVP不移动会一直安全等待吗？", f"不会。超过{tianheng['force_match_seconds']}秒没有行动会被自动加入随机配对队列。"],
            ["PVP能组队围攻吗？", "不能。每个镜域只承载随机配对的双方，其他参赛者无法进入。"],
            ["PVE必须击败四个渊将吗？", "不是硬性胜利条件。击碎巡渊主核心即可胜利，但渊将会主动攻击并改变路线压力。"],
            ["为什么封脉要两个人？", "当前存活人数达到4人时需要两名不同玩家响应；少于4人时自动降为一人，防止减员后无解。"],
            ["为什么不能飞走或普通逃跑？", "活动房间由状态机管理。请使用认输、撤离或活动结束返回，确保死亡、排名和奖励只结算一次。"],
            ["断线后还能回来吗？", f"{tianheng['offline_grace_seconds']}秒宽限内重新登录可恢复活动场次；超过后按淘汰或出局处理。"],
            ["奖励保存失败会丢吗？", "不会立即标记已领。系统保留待领奖励，下次登录或打开活动页时继续补发。"],
            ["天衡令和九曜令在哪里花？", "打开限时玩法页，点击“令牌兑换商店”。两种令牌分别消费，可换金币、功能符、绑定锻造宝石和一次性永久徽记。"],
            ["为什么朋友看到的首领和我不同？", "先确认是否属于同一逻辑区组和同一日场次。隔离区从房间、NPC到排名都完全独立。"],
        ],
        [2.05, 3.65],
        compact=True,
    )

    guide.h1("8. 实现依据与版本边界")
    guide.paragraph(
        "本手册描述的是当前已经接线的服务器行为，不把尚未存在的赛季排行、跨日冠军称号或VIP专属收益写成已上线功能。后续修改开放时间、奖励公式、兑换目录、战势、九宫机制或异常恢复策略时，应同步更新本生成器并重新导出PDF。"
    )
    guide.table(
        ["权威来源", "用途"],
        [
            ["gamelib/etc/timed_events.json", "开放时间与可运营参数"],
            ["gamelib/single/daemons/_timed_event_mod/pvp.pike", "天衡配对、战势、淘汰与排名"],
            ["gamelib/single/daemons/_timed_event_mod/pve.pike", "九宫、封脉、渊将、首领与胜负"],
            ["gamelib/single/daemons/_timed_event_mod/runtime.pike", "场次、奖励、隔离、返回与断线恢复"],
            ["gamelib/single/daemons/_timed_event_mod/shop.pike", "令牌目录、绑定发放、扣费回滚与审计"],
            ["gamelib/single/daemons/_timed_event_mod/persistence.pike", "原子保存、重启取消与待领奖励"],
            ["test_unit/test_timed_event_system.pike", "真实Pike编译、时区、九宫和完整流程回归"],
            ["vue_source/tests/timed-event-ui.test.js", "弹窗、快捷入口和状态轮询回归"],
        ],
        [2.7, 3.0],
    )
    guide.callout(
        "版本声明",
        f"本文生成于{build_date}，发布分支{branch}，内容基线{commit}。配置与运营开放状态以服务器当日限时玩法页面为准。",
        "gold",
    )

    MD_PATH.write_text("\n".join(guide.md).rstrip() + "\n", encoding="utf-8")
    doc.multiBuild(story)
    OUTPUT_PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    DESKTOP_PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PDF_PATH, OUTPUT_PDF_PATH)
    shutil.copy2(PDF_PATH, DESKTOP_PDF_PATH)


if __name__ == "__main__":
    build_guide()
