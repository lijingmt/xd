#!/usr/bin/env python3
"""Build the Xiand all-profession progression handbook.

The handbook is generated from the current repository's skill objects, book
catalog, forging recipes, and selected runtime contracts. It writes both an
editable Markdown source and a polished PDF under docs/.
"""

from __future__ import annotations

import csv
import datetime as dt
import html
import re
import subprocess
from collections import defaultdict
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    Image,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
PDF_PATH = DOCS / "xiand-all-professions-progression-guide.pdf"
MD_PATH = DOCS / "xiand-all-professions-progression-guide.md"

PAGE_W, PAGE_H = A4
LEFT_MARGIN = 14 * mm
RIGHT_MARGIN = 14 * mm
TOP_MARGIN = 16 * mm
BOTTOM_MARGIN = 15 * mm
CONTENT_W = PAGE_W - LEFT_MARGIN - RIGHT_MARGIN

NAVY = colors.HexColor("#102A43")
TEAL = colors.HexColor("#0F766E")
TEAL_LIGHT = colors.HexColor("#E6FFFA")
GOLD = colors.HexColor("#C69A3B")
GOLD_LIGHT = colors.HexColor("#FFF7E0")
INK = colors.HexColor("#243B53")
MUTED = colors.HexColor("#627D98")
LINE = colors.HexColor("#CBD5E1")
PAPER = colors.HexColor("#F8FAFC")
WHITE = colors.white
RED = colors.HexColor("#B42318")


PROFESSIONS = [
    {
        "id": "jianxian",
        "name": "剑仙",
        "faction": "人类",
        "role": "近战剑士 / 防御反击",
        "starter": "qieyunzhan",
        "starter_cn": "切云斩",
        "initial": "生命120 / 法力20 / 力12 / 敏6 / 智2",
        "growth": "力=12+2.5L；敏=6+1.5L；智=2+0.5L",
        "gear": "力量、物攻、命中、生命、防御；兼顾剑系主手",
        "identity": "稳定物理输出、破防、护盾与生命转换，容错较高。",
    },
    {
        "id": "yushi",
        "name": "羽士",
        "faction": "人类",
        "role": "元素法师 / 护盾控制",
        "starter": "yinghuozhou",
        "starter_cn": "引火咒",
        "initial": "生命80 / 法力120 / 力8 / 敏2 / 智12",
        "growth": "力=8+1.0L；敏=2+0.5L；智=12+3.0L",
        "gear": "智力、法力、全系/火冰风伤害、法术穿透、生存",
        "identity": "高智成长，覆盖火、冰、风法术，并拥有护盾与减速控制。",
    },
    {
        "id": "zhuxian",
        "name": "诛仙",
        "faction": "人类",
        "role": "敏捷剑修 / 暴击爆发",
        "starter": "suixinjue",
        "starter_cn": "碎心决",
        "initial": "生命100 / 法力40 / 力10 / 敏12 / 智4",
        "growth": "力=10+1.5L；敏=12+2.0L；智=4+1.0L",
        "gear": "敏捷、物攻、暴击、命中、闪避；重视爆发窗口",
        "identity": "物理剑阵与暴击路线，兼有命中压制、护盾和冷却重置。",
    },
    {
        "id": "kuangyao",
        "name": "狂妖",
        "faction": "妖魔",
        "role": "重装战士 / 流血狂暴",
        "starter": "silie",
        "starter_cn": "撕裂",
        "initial": "生命140 / 法力20 / 力14 / 敏2 / 智2",
        "growth": "力=14+3.0L；敏=2+1.0L；智=2+0.5L",
        "gear": "力量、生命、物攻、暴击、防御；适合高生命换伤",
        "identity": "最高力量与生命起点，擅长持续流血、破防与舍身爆发。",
    },
    {
        "id": "wuyao",
        "name": "巫妖",
        "faction": "妖魔",
        "role": "毒风术士 / 持续控制",
        "starter": "wudushu",
        "starter_cn": "巫毒术",
        "initial": "生命80 / 法力100 / 力8 / 敏2 / 智10",
        "growth": "力=8+1.5L；敏=2+0.5L；智=10+2.5L",
        "gear": "智力、法力、毒/风伤害、法穿、生命与抗性",
        "identity": "毒伤、风刃、持续伤害与多种削弱，擅长压制恢复和施法。",
    },
    {
        "id": "yinggui",
        "name": "影鬼",
        "faction": "妖魔",
        "role": "敏捷刺客 / 闪避潜行",
        "starter": "fuji",
        "starter_cn": "伏击",
        "initial": "生命100 / 法力30 / 力10 / 敏14 / 智3",
        "growth": "力=10+1.0L；敏=14+2.5L；智=3+1.0L",
        "gear": "敏捷、物攻、暴击、闪避、命中；突出第一击",
        "identity": "最高敏捷起点，专长伏击、闪避、脱战影遁与毒素爆发。",
    },
    {
        "id": "fangshi",
        "name": "方士",
        "faction": "中立",
        "role": "召唤师 / 治疗支援 / 混合输出",
        "starter": "lingdanshu",
        "starter_cn": "灵弹术",
        "initial": "生命100 / 法力50 / 力10 / 敏8 / 智8",
        "growth": "力=10+1.5L；敏=5+0.8L；智=12+2.0L",
        "gear": "全属性、智力、法力、生命、防御；按实际技能与队伍补物攻",
        "identity": "唯一中立职业，虎鹤龟召唤、单体/团队治疗与三灵共鸣并行。",
    },
]

PROF_BY_ID = {p["id"]: p for p in PROFESSIONS}
PROF_ORDER = {p["id"]: i for i, p in enumerate(PROFESSIONS)}

SKILL_TYPE_LABELS = {
    "phy": "物理直伤",
    "huo_mofa_attack": "火系法术",
    "bing_mofa_attack": "冰系法术",
    "feng_mofa_attack": "风系法术",
    "du_mofa_attack": "毒系法术",
    "dot": "持续伤害",
    "curse": "诅咒/控制",
    "buff": "增益/被动",
    "heal": "治疗",
    "spec": "职业绝技",
    "70_spec": "70级绝技",
}

FANGSHI_MILESTONES = [
    ("创建", "选择中立/方士，获得灵弹术、桃木剑与三件基础防具，自动补穿空位。"),
    ("2级", "灵刃，补充低冷却攻击。"),
    ("8级", "灵治：战斗中只治疗自己。"),
    ("10级", "虎灵：攻击向；解锁第一只实体召唤。"),
    ("15级", "鹤灵：防御向，并周期治疗存活主人。"),
    ("20级", "龟灵：生命/承伤向；方士传人开启三灵初契挂件任务。"),
    ("24级", "灵莲铺：必定治疗自己；组队时加治同房间存活队友。"),
    ("29-41级", "灵智魂五段被动，依次永久提高力、敏、智。"),
    ("30级", "同时存在的召唤上限由1只提升到2只。"),
    ("50级", "三灵合一增益；普通野外动态怪早已从50级开始。"),
    ("53级", "方士传人四段职业任务，终点奖励三灵合一技能书。"),
    ("60级", "召唤上限3只，开放 summon all 与每日高级技能书。"),
    ("65级", "三灵合一、灵玄影、灵穿心等强化替换技能。"),
    ("70级", "灵裂兽；实际等级70+怪物进入隐藏技能书资格池。"),
    ("75级", "灵玄、灵火烧、灵治、灵盾、虎灵秘传替换。"),
    ("80级", "可学习本职业隐藏大神书；后续技能阶段门槛到160级。"),
]

REALM_PREFIXES = [
    ("71-80", "欲界", "1.1x"),
    ("81-90", "色界", "1.3x"),
    ("91-100", "无色界", "1.5x"),
    ("101-120", "离三界-初阶", "1.7x"),
    ("121-140", "离三界-中阶", "1.9x"),
    ("141-160", "离三界-高阶", "2.1x"),
    ("161-190", "破虚境", "2.3x"),
    ("191-230", "渡劫境", "2.5x"),
    ("231-280", "天仙境", "2.7x"),
    ("281-330", "金仙境", "3.0x"),
    ("331-380", "太乙境", "3.3x"),
    ("381-430", "混元境", "3.6x"),
    ("431-480", "大罗境", "4.0x"),
    ("481-500", "大道境", "4.5x"),
    ("501+", "超凡境", "5.0x"),
]


def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return "unknown"


def clean_text(value: str) -> str:
    value = value.replace("\\n", " ").replace("\r", " ").replace("\n", " ")
    return re.sub(r"\s+", " ", value).strip()


def parse_books() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    path = ROOT / "gamelib/data/can_buy_book_list.csv"
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.reader(stream):
            if len(row) != 8 or row[3] not in PROF_BY_ID:
                continue
            rows.append(
                {
                    "profession": row[3],
                    "level": int(row[2] or 0),
                    "name": row[4],
                    "path": row[1],
                    "jade": int(row[5] or 0),
                    "gold": int(row[6] or 0),
                    "stock": int(row[7] or 0),
                }
            )
    rows.sort(key=lambda r: (PROF_ORDER[str(r["profession"])], int(r["level"]), str(r["path"])))
    return rows


def match_one(pattern: str, source: str, default: str = "") -> str:
    found = re.search(pattern, source)
    return clean_text(found.group(1)) if found else default


def parse_skills() -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    skill_dir = ROOT / "gamelib/single/skills"
    prof_pattern = re.compile(
        r'skill_type\s*\+=\s*\(\{\s*"(jianxian|yushi|zhuxian|kuangyao|wuyao|yinggui|fangshi)"\s*\}\)'
    )
    for path in sorted(skill_dir.iterdir()):
        if not path.is_file():
            continue
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        prof_match = prof_pattern.search(source)
        if not prof_match:
            continue
        gates = [
            int(value)
            for _, value in re.findall(
                r"performs_level_limit\[(\d+)\]\s*=\s*(\d+)", source
            )
        ]
        result.append(
            {
                "profession": prof_match.group(1),
                "id": path.name,
                "name": match_one(r'name_cn\s*=\s*"([^"]+)"', source, path.name),
                "mode": match_one(r's_type\s*=\s*"([^"]+)"', source),
                "type": match_one(r's_skill_type\s*=\s*"([^"]+)"', source),
                "cooldown": match_one(r"s_delayTime\s*=\s*(\d+)", source),
                "gates": gates,
                "desc": match_one(r'desc\s*=\s*"([^"]*)"', source),
            }
        )
    result.sort(
        key=lambda r: (
            PROF_ORDER[str(r["profession"])],
            min(r["gates"]) if r["gates"] else 9999,
            str(r["id"]),
        )
    )
    return result


def parse_forge_stats() -> tuple[list[list[str]], list[list[str]]]:
    path = ROOT / "gamelib/data/material/duanzao.csv"
    rows: list[list[str]] = []
    type_stats: dict[str, dict[str, object]] = defaultdict(
        lambda: {"count": 0, "min": 9999, "max": 0}
    )
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.reader(stream):
            if len(row) != 7:
                continue
            level = int(row[4])
            type_stats[row[1]]["count"] = int(type_stats[row[1]]["count"]) + 1
            type_stats[row[1]]["min"] = min(int(type_stats[row[1]]["min"]), level)
            type_stats[row[1]]["max"] = max(int(type_stats[row[1]]["max"]), level)
            rows.append(row)
    type_names = {
        "m_weapon": "主手武器",
        "s_weapon": "副手/短武器",
        "d_weapon": "双手武器",
        "weapon": "高阶武器",
        "armor": "防具",
    }
    summary = [
        [
            type_names.get(key, key),
            str(data["count"]),
            f'{data["min"]}-{data["max"]}级',
        ]
        for key, data in sorted(type_stats.items())
    ]
    targets = [1, 9, 21, 33, 49, 53, 60, 70]
    samples: list[list[str]] = []
    for target in targets:
        candidates = [r for r in rows if int(r[4]) == target]
        if not candidates:
            continue
        row = candidates[0]
        samples.append(
            [
                row[4],
                type_names.get(row[1], row[1]),
                row[2],
                row[5],
                clean_text(row[6].replace("|", "；").replace(":", "×")),
            ]
        )
    return summary, samples


def register_fonts() -> None:
    candidates = [
        (
            Path("/System/Library/Fonts/STHeiti Light.ttc"),
            Path("/System/Library/Fonts/STHeiti Medium.ttc"),
        ),
        (
            Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
            Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"),
        ),
        (
            Path("/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc"),
            Path("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"),
        ),
        (
            Path("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"),
            Path("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"),
        ),
    ]
    for regular, bold in candidates:
        if regular.exists() and bold.exists():
            pdfmetrics.registerFont(TTFont("XiandBody", str(regular), subfontIndex=0))
            pdfmetrics.registerFont(TTFont("XiandBold", str(bold), subfontIndex=0))
            return
    raise RuntimeError(
        "No supported Chinese font found. Install Noto Sans CJK or WenQuanYi Zen Hei."
    )


class SectionBar(Flowable):
    def __init__(self, text: str, color: colors.Color = TEAL):
        super().__init__()
        self.text = text
        self.color = color
        self.height = 11 * mm

    def wrap(self, avail_width: float, avail_height: float) -> tuple[float, float]:
        self.draw_width = avail_width
        return avail_width, self.height

    def draw(self) -> None:
        self.canv.setFillColor(self.color)
        self.canv.roundRect(0, 0, self.draw_width, self.height, 3 * mm, fill=1, stroke=0)
        self.canv.setFillColor(WHITE)
        self.canv.setFont("XiandBold", 12)
        self.canv.drawString(5 * mm, 3.4 * mm, self.text)


class GuideDocTemplate(BaseDocTemplate):
    def __init__(self, filename: str, styles: dict[str, ParagraphStyle], **kwargs):
        super().__init__(filename, **kwargs)
        self.guide_styles = styles
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
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=self._on_page))

    def _on_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("仙道全职业技能与装备成长手册")
        canvas.setAuthor("Xiand Project")
        if doc.page > 1:
            canvas.setStrokeColor(LINE)
            canvas.setLineWidth(0.4)
            canvas.line(LEFT_MARGIN, PAGE_H - 11 * mm, PAGE_W - RIGHT_MARGIN, PAGE_H - 11 * mm)
            canvas.setFont("XiandBody", 7.5)
            canvas.setFillColor(MUTED)
            canvas.drawString(LEFT_MARGIN, PAGE_H - 8.5 * mm, "仙道全职业技能与装备成长手册")
            canvas.drawRightString(
                PAGE_W - RIGHT_MARGIN,
                PAGE_H - 8.5 * mm,
                "方士重点版",
            )
            canvas.line(LEFT_MARGIN, 10 * mm, PAGE_W - RIGHT_MARGIN, 10 * mm)
            canvas.drawCentredString(PAGE_W / 2, 6.5 * mm, f"- {doc.page} -")
        canvas.restoreState()

    def afterFlowable(self, flowable) -> None:
        if isinstance(flowable, Paragraph):
            style_name = flowable.style.name
            if style_name == "GuideH1":
                text = flowable.getPlainText()
                key = f"h1-{self.seq.nextf('heading1')}"
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(text, key, 0, False)
                self.notify("TOCEntry", (0, text, self.page, key))
            elif style_name == "GuideH2":
                text = flowable.getPlainText()
                key = f"h2-{self.seq.nextf('heading2')}"
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(text, key, 1, False)
                self.notify("TOCEntry", (1, text, self.page, key))


def build_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    styles: dict[str, ParagraphStyle] = {}
    styles["Body"] = ParagraphStyle(
        "GuideBody",
        parent=base["BodyText"],
        fontName="XiandBody",
        fontSize=9.2,
        leading=14,
        textColor=INK,
        spaceAfter=2.5 * mm,
        wordWrap="CJK",
    )
    styles["Small"] = ParagraphStyle(
        "GuideSmall",
        parent=styles["Body"],
        fontSize=7.4,
        leading=10,
        textColor=MUTED,
        spaceAfter=1.5 * mm,
    )
    styles["Bullet"] = ParagraphStyle(
        "GuideBullet",
        parent=styles["Body"],
        leftIndent=5 * mm,
        firstLineIndent=-3.5 * mm,
        bulletIndent=0,
        spaceAfter=1.2 * mm,
    )
    styles["H1"] = ParagraphStyle(
        "GuideH1",
        parent=base["Heading1"],
        fontName="XiandBold",
        fontSize=18,
        leading=23,
        textColor=NAVY,
        spaceBefore=4 * mm,
        spaceAfter=4 * mm,
        keepWithNext=True,
        wordWrap="CJK",
    )
    styles["H2"] = ParagraphStyle(
        "GuideH2",
        parent=base["Heading2"],
        fontName="XiandBold",
        fontSize=13.5,
        leading=18,
        textColor=TEAL,
        spaceBefore=3.5 * mm,
        spaceAfter=2.5 * mm,
        keepWithNext=True,
        wordWrap="CJK",
    )
    styles["H3"] = ParagraphStyle(
        "GuideH3",
        parent=base["Heading3"],
        fontName="XiandBold",
        fontSize=10.5,
        leading=14,
        textColor=GOLD,
        spaceBefore=2.5 * mm,
        spaceAfter=1.5 * mm,
        keepWithNext=True,
        wordWrap="CJK",
    )
    styles["Table"] = ParagraphStyle(
        "GuideTable",
        parent=styles["Body"],
        fontSize=6.6,
        leading=8.5,
        spaceAfter=0,
        wordWrap="CJK",
    )
    styles["TableHead"] = ParagraphStyle(
        "GuideTableHead",
        parent=styles["Table"],
        fontName="XiandBold",
        fontSize=7,
        leading=9,
        textColor=WHITE,
        alignment=TA_CENTER,
    )
    styles["Callout"] = ParagraphStyle(
        "GuideCallout",
        parent=styles["Body"],
        fontSize=8.6,
        leading=13,
        spaceAfter=0,
    )
    styles["CoverTitle"] = ParagraphStyle(
        "GuideCoverTitle",
        parent=base["Title"],
        fontName="XiandBold",
        fontSize=27,
        leading=34,
        textColor=NAVY,
        alignment=TA_CENTER,
        spaceAfter=5 * mm,
        wordWrap="CJK",
    )
    styles["CoverSub"] = ParagraphStyle(
        "GuideCoverSub",
        parent=styles["Body"],
        fontName="XiandBold",
        fontSize=12,
        leading=18,
        textColor=TEAL,
        alignment=TA_CENTER,
    )
    return styles


class HandbookBuilder:
    def __init__(self, story: list, styles: dict[str, ParagraphStyle]):
        self.story = story
        self.styles = styles
        self.md: list[str] = []

    def esc(self, text: object) -> str:
        return html.escape(str(text), quote=False)

    def h1(self, text: str) -> None:
        self.story.append(Paragraph(self.esc(text), self.styles["H1"]))
        self.md.extend([f"# {text}", ""])

    def h2(self, text: str) -> None:
        self.story.append(Paragraph(self.esc(text), self.styles["H2"]))
        self.md.extend([f"## {text}", ""])

    def h3(self, text: str) -> None:
        self.story.append(Paragraph(self.esc(text), self.styles["H3"]))
        self.md.extend([f"### {text}", ""])

    def paragraph(self, text: str, small: bool = False) -> None:
        style = self.styles["Small"] if small else self.styles["Body"]
        self.story.append(Paragraph(self.esc(text), style))
        self.md.extend([text, ""])

    def bullets(self, lines: list[str]) -> None:
        for line in lines:
            self.story.append(
                Paragraph(
                    f'<font color="#0F766E">●</font> {self.esc(line)}',
                    self.styles["Bullet"],
                )
            )
            self.md.append(f"- {line}")
        self.md.append("")

    def callout(self, title: str, text: str, kind: str = "teal") -> None:
        background = TEAL_LIGHT if kind == "teal" else GOLD_LIGHT
        border = TEAL if kind == "teal" else GOLD
        content = Paragraph(
            f'<font name="XiandBold" color="{border.hexval()}">{self.esc(title)}</font><br/>'
            f"{self.esc(text)}",
            self.styles["Callout"],
        )
        table = Table([[content]], colWidths=[CONTENT_W], hAlign="LEFT")
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), background),
                    ("BOX", (0, 0), (-1, -1), 0.8, border),
                    ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                    ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
                ]
            )
        )
        self.story.extend([table, Spacer(1, 3 * mm)])
        self.md.extend([f"> **{title}**", ">", f"> {text}", ""])

    def table(
        self,
        headers: list[str],
        rows: list[list[object]],
        ratios: list[float] | None = None,
        compact: bool = False,
    ) -> None:
        if ratios is None:
            ratios = [1] * len(headers)
        total = sum(ratios)
        widths = [CONTENT_W * value / total for value in ratios]
        body_style = self.styles["Table"]
        if compact:
            body_style = ParagraphStyle(
                "GuideTableCompact",
                parent=self.styles["Table"],
                fontSize=6.1,
                leading=7.6,
            )
        data = [
            [Paragraph(self.esc(cell), self.styles["TableHead"]) for cell in headers]
        ]
        for row in rows:
            data.append([Paragraph(self.esc(cell), body_style) for cell in row])
        table = Table(
            data,
            colWidths=widths,
            repeatRows=1,
            hAlign="LEFT",
            splitByRow=1,
        )
        commands = [
            ("BACKGROUND", (0, 0), (-1, 0), NAVY),
            ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
            ("GRID", (0, 0), (-1, -1), 0.35, LINE),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 1.4 * mm),
            ("RIGHTPADDING", (0, 0), (-1, -1), 1.4 * mm),
            ("TOPPADDING", (0, 0), (-1, -1), 1.1 * mm),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 1.1 * mm),
        ]
        for index in range(1, len(data)):
            if index % 2 == 0:
                commands.append(("BACKGROUND", (0, index), (-1, index), PAPER))
        table.setStyle(TableStyle(commands))
        self.story.extend([table, Spacer(1, 3 * mm)])

        self.md.append("| " + " | ".join(headers) + " |")
        self.md.append("| " + " | ".join(["---"] * len(headers)) + " |")
        for row in rows:
            cells = [
                str(cell).replace("|", "\\|").replace("\n", "<br>") for cell in row
            ]
            self.md.append("| " + " | ".join(cells) + " |")
        self.md.append("")

    def pagebreak(self) -> None:
        self.story.append(PageBreak())
        self.md.extend(["<!-- PAGEBREAK -->", ""])


def skill_rows(skills: list[dict[str, object]]) -> list[list[str]]:
    rows: list[list[str]] = []
    for skill in skills:
        gates = skill["gates"]
        if gates:
            gate_text = "/".join(str(value) for value in gates)
        else:
            gate_text = "随技能书/替换"
        mode = "被动" if skill["mode"] == "beidong" else "主动"
        type_label = SKILL_TYPE_LABELS.get(str(skill["type"]), str(skill["type"]) or "特殊")
        cooldown = f'{skill["cooldown"]}秒' if skill["cooldown"] else "-"
        rows.append(
            [
                f'{skill["name"]}\n({skill["id"]})',
                mode,
                type_label,
                gate_text,
                cooldown,
                str(skill["desc"]),
            ]
        )
    return rows


def book_rows(books: list[dict[str, object]], advanced: bool) -> list[list[str]]:
    rows: list[list[str]] = []
    for book in books:
        if (int(book["level"]) >= 60) != advanced:
            continue
        price = f'{book["jade"]}碎玉'
        if int(book["gold"]):
            price += f' + {book["gold"]}黄金'
        route = "每日职业轮换"
        if not advanced:
            route = "职业技能书商店"
        rows.append(
            [
                str(book["level"]),
                str(book["name"]),
                str(book["path"]).replace("book/", ""),
                price,
                route,
            ]
        )
    return rows


def build_handbook() -> None:
    register_fonts()
    styles = build_styles()
    books = parse_books()
    skills = parse_skills()
    forge_summary, forge_samples = parse_forge_stats()
    books_by_prof: dict[str, list[dict[str, object]]] = defaultdict(list)
    skills_by_prof: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in books:
        books_by_prof[str(row["profession"])].append(row)
    for row in skills:
        skills_by_prof[str(row["profession"])].append(row)

    branch = git_value("rev-parse", "--abbrev-ref", "HEAD")
    commit = git_value("rev-parse", "--short=10", "HEAD")
    build_date = dt.date.today().isoformat()

    doc = GuideDocTemplate(
        str(PDF_PATH),
        styles,
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="仙道全职业技能与装备成长手册",
        author="Xiand Project",
    )
    story: list = []
    guide = HandbookBuilder(story, styles)

    # Cover
    story.append(Spacer(1, 18 * mm))
    icon_paths = [
        ROOT / "images/third_logo.png",
        ROOT / "images/human_fangshi_male.png",
        ROOT / "images/human_fangshi_logo.png",
        ROOT / "images/human_fangshi_female.png",
    ]
    icon_cells = [
        Image(str(path), width=18 * mm, height=18 * mm) for path in icon_paths
    ]
    icon_table = Table([icon_cells], colWidths=[24 * mm] * 4, hAlign="CENTER")
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
    story.append(Spacer(1, 8 * mm))
    story.append(Paragraph("仙道全职业技能与装备成长手册", styles["CoverTitle"]))
    story.append(
        Paragraph(
            "从创建人物到 500+ 境界 · 七职业全覆盖 · 方士重点版",
            styles["CoverSub"],
        )
    )
    story.append(Spacer(1, 10 * mm))
    cover_box = Table(
        [
            [
                Paragraph(
                    "覆盖 7 职业 / 127 个职业技能对象 / 全部职业技能书路线<br/>"
                    "装备掉落、锻造、熔炼、宝石、转化、动态怪、隐藏大神技能<br/>"
                    "任务、副本、队伍、帮派、家园、排行、交易与玉石经济",
                    ParagraphStyle(
                        "CoverBox",
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
    story.append(Spacer(1, 18 * mm))
    story.append(
        Paragraph(
            f"分支：{html.escape(branch)}　提交基线：{html.escape(commit)}　生成日期：{build_date}",
            ParagraphStyle(
                "CoverMeta",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=MUTED,
            ),
        )
    )
    story.append(
        Paragraph(
            "说明：本手册依据当前仓库代码与数据生成。服务器活动、轮换库存和运营数值可能调整，以游戏内实时显示为准。",
            ParagraphStyle(
                "CoverNote",
                parent=styles["Small"],
                alignment=TA_CENTER,
                textColor=RED,
            ),
        )
    )
    guide.md.extend(
        [
            "# 仙道全职业技能与装备成长手册",
            "",
            "从创建人物到 500+ 境界 · 七职业全覆盖 · 方士重点版",
            "",
            f"- 分支：`{branch}`",
            f"- 提交基线：`{commit}`",
            f"- 生成日期：{build_date}",
            f"- 数据规模：{len(PROFESSIONS)} 个职业，{len(skills)} 个职业技能对象，{len(books)} 条职业技能书配置",
            "",
            "> 本手册依据当前仓库代码与数据生成。服务器活动、轮换库存和运营数值可能调整，以游戏内实时显示为准。",
            "",
        ]
    )
    guide.pagebreak()

    # TOC
    story.append(Paragraph("目录", styles["H1"]))
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle(
            "TOC1",
            fontName="XiandBold",
            fontSize=9.5,
            leading=15,
            leftIndent=0,
            firstLineIndent=0,
            textColor=NAVY,
            spaceAfter=1.5 * mm,
        ),
        ParagraphStyle(
            "TOC2",
            fontName="XiandBody",
            fontSize=8.3,
            leading=12,
            leftIndent=6 * mm,
            firstLineIndent=0,
            textColor=INK,
            spaceAfter=0.8 * mm,
        ),
    ]
    story.append(toc)
    story.append(PageBreak())

    # 1. How to use
    guide.h1("1. 如何使用这本手册")
    guide.callout(
        "先记住一条主线",
        "创建人物 -> 完成20步真实动作引导 -> 穿好基础装备 -> 买到技能书 -> 在背包点击学习 -> 实战积累熟练度 -> 按等级更新装备 -> 60级进入每日进阶书 -> 70级挑战高阶动态怪 -> 80级学习极稀有隐藏神技。",
    )
    guide.paragraph(
        "“0级”在本手册中指注册、选择阵营与职业的创建阶段；正式进入游戏后按1级起步。技能书购买成功不等于已经学会，必须在背包中执行学习动作。"
    )
    guide.table(
        ["阶段", "首要目标", "技能重点", "装备重点", "同步体验的系统"],
        [
            ["创建-8", "选职业并走通新手引导", "起手技、首个治疗/增益", "桃木剑与基础防具；一键补空位", "地图、任务、背包、技能页"],
            ["9-20", "完成职业核心雏形", "9/14/19级书；方士三灵逐步解锁", "怪物掉落替换低级装备", "组队、聊天、20级职业任务"],
            ["21-29", "形成职业循环", "24级主技能、29级被动/控制", "关注职业/属性/等级限制", "副本、仓库、交易、荣誉"],
            ["30-49", "补齐中阶技能", "30/39/49附近主力技能", "配方锻造与精制装备", "帮派、家园、熔炼、宝石"],
            ["50-59", "进入动态怪阶段", "职业绝技准备；方士三灵合一", "动态怪按人物等级产出成长装备", "高阶地图、离线修炼、自动战斗"],
            ["60-69", "每日进阶技能书", "每天每职业独立轮换2本", "开始长期词条与宝石规划", "高级玉石商店、职业任务链"],
            ["70-79", "挑战高阶装备与隐藏掉落资格怪", "70级绝技；方士75级秘传", "欲界装备从71级开始", "高阶动态Boss、团队分配"],
            ["80-160", "隐藏神技分阶段成长", "神技阶段门槛80/100/120/140/160", "色界至离三界高阶", "长期副本、帮派、家园与排行"],
            ["161-500+", "境界装备长期养成", "稳定熟练度与职业循环", "破虚境至大道境/超凡境", "高阶团队、经济与收藏玩法"],
        ],
        [0.8, 1.3, 1.6, 1.7, 1.5],
    )
    guide.h2("1.1 新手必须完成的真实动作")
    guide.bullets(
        [
            "打开 newbie_guide 开始20步课程；服务器检查人物真实状态，不会因为点过按钮就伪装完成。",
            "使用 auto_equip 补穿空装备位。助手不会替换已经穿戴的装备，也不会绕过等级、职业或属性限制。",
            "通过 buy_items book <职业ID> 打开本职业普通技能书商店；购买后到背包点击“学习”。",
            "打开 myskills 检查已学技能、有效阶段、熟练度百分比和技能入口。",
            "通过 map_display 选择适合等级的地图，通过 mytasks 跟进任务，通过 look_top 了解排行目标。",
        ]
    )
    guide.h2("1.2 完成后自动结算，不用返回引导页")
    guide.callout(
        "真实动作完成即弹窗",
        "人物完成当前课程要求后，服务器会立即验证、推进步骤并发放一次性奖励。Vue界面直接弹出“新手任务完成”，显示本步奖励和下一步；玩家可以留在当前界面，也可以从弹窗直接开始下一步，不必回到newbie_guide点击检查。",
        "gold",
    )
    guide.bullets(
        [
            "连续达成两步时，完成结果按顺序排队显示，不会互相覆盖；最后一步会自动毕业并提供职业成长路线入口。",
            "重复执行同一动作、重复打开页面或重复点击检查不会重复推进，也不会重复发钱、干粮或碎玉。",
            "人物在进入对应课程前已经达到等级，或老人物已经完成本级职业历练时，会按服务器保存的真实历史进度兼容结算，避免第7、8、17步卡死。",
            "背包暂时无法接收实物奖励时，步骤不会被错误推进；界面提示先整理背包，之后执行引导动作即可自动补领，并抑制重复弹窗循环。",
            "旧界面会收到醒目的文字完成提示；newbie_guide check保留为历史进度和异常情况下的手动补领入口。",
        ]
    )

    # 2. Profession matrix
    guide.h1("2. 七职业选择与属性成长")
    guide.paragraph(
        "L 表示“当前等级减1”。创建时的初始属性与升级重算公式同时列出；升级后生命和法力会按公共等级逻辑恢复至上限。"
    )
    guide.table(
        ["职业", "阵营", "定位", "创建属性", "升级属性公式", "起手技能"],
        [
            [
                p["name"],
                p["faction"],
                p["role"],
                p["initial"],
                p["growth"],
                p["starter_cn"],
            ]
            for p in PROFESSIONS
        ],
        [0.55, 0.55, 1.15, 1.55, 1.7, 0.85],
        compact=True,
    )
    guide.h2("2.1 选职业的简明建议")
    guide.table(
        ["想要的体验", "优先职业", "原因"],
        [
            ["稳健物理与反击", "剑仙", "力量成长高，具备破防、被动防御、生命转换与反转窗口。"],
            ["纯元素法术", "羽士", "最高智力成长，火冰风法术、护盾与减速一体。"],
            ["敏捷剑阵爆发", "诛仙", "高敏成长，暴击/闪避被动与物理剑阵密集。"],
            ["高生命近战与流血", "狂妖", "生命和力量起点最高，擅长持续伤害与生命换伤。"],
            ["毒风持续压制", "巫妖", "毒、风、持续伤害和治疗压制均衡。"],
            ["闪避刺杀与影遁", "影鬼", "敏捷成长最高，脱战、冷却重置和第一击爆发鲜明。"],
            ["召唤、治疗与中立自由", "方士", "唯一拥有实体虎鹤龟、团队治疗、共鸣和双阵营公共设施访问。"],
        ],
        [1.2, 0.9, 3.1],
    )

    # 3. Universal skill system
    guide.h1("3. 所有职业通用的技能学习与熟练度")
    guide.h2("3.1 技能书的完整学习链")
    guide.table(
        ["步骤", "玩家动作", "系统检查", "常见误区"],
        [
            ["1. 找入口", "普通书：buy_items book 职业ID；高级书：yushi_buy_hlbook_list", "只展示对应职业目录", "看到书不代表等级已满足"],
            ["2. 购买", "支付碎玉与黄金", "职业、库存、服务器价格、背包空间", "高级书价格不信任客户端链接参数"],
            ["3. 入包", "打开 inventory", "物品真实进入背包", "购买完成仍未学习"],
            ["4. 学习", "点击书上的“学习”", "等级、职业、前置技能、重复技能", "替换书会删除旧技能键并加入新技能"],
            ["5. 实战", "成功施放技能", "BOSS技能除外；约1/3概率增长熟练度", "显示0%不一定是故障"],
            ["6. 升段", "熟练度达到门槛", "技能等级+1，熟练度归零", "方士多数技能只有5段；旧职业多数为10段"],
        ],
        [0.75, 1.3, 1.65, 1.45],
    )
    guide.h2("3.2 熟练度门槛")
    guide.table(
        ["当前技能等级", "升到下一等级所需熟练度", "界面显示特点"],
        [
            ["1", "2000", "需要20点熟练度才显示1%"],
            ["2", "4000", "整数截断百分比"],
            ["3", "8000", "成功施放后约1/3概率+1"],
            ["4", "12000", "失败施放不应增长"],
            ["5", "20000", "是否还能升级取决于技能真实配置上限"],
        ],
        [1, 1.6, 2.2],
    )
    guide.callout(
        "方士阶段模型",
        "多数方士技能配置5个角色等级阶段，因此熟练度到第5段即封顶；旧职业只有一个角色等级门槛的技能通常保留10段模型。灵百雷11级属于强化技能名，不代表人物技能数组会凭空变成11段。",
        "gold",
    )

    # 4. Six legacy professions
    guide.h1("4. 六个经典职业成长路线")
    for index, prof in enumerate(PROFESSIONS[:-1], start=1):
        pid = prof["id"]
        guide.h2(f"4.{index} {prof['name']} - {prof['role']}")
        guide.callout("职业定位", prof["identity"])
        guide.table(
            ["阵营", "起手技能", "创建属性", "升级公式", "装备优先级"],
            [[prof["faction"], prof["starter_cn"], prof["initial"], prof["growth"], prof["gear"]]],
            [0.6, 0.8, 1.45, 1.55, 1.8],
            compact=True,
        )
        ordinary = book_rows(books_by_prof[pid], advanced=False)
        advanced = book_rows(books_by_prof[pid], advanced=True)
        guide.h3("普通技能书节奏")
        guide.table(
            ["等级", "技能书", "书ID", "价格", "入口"],
            ordinary,
            [0.45, 1.45, 1.35, 1.15, 1.25],
            compact=True,
        )
        guide.h3("60级以上每日轮换")
        guide.paragraph(
            "该职业高阶池每天独立随机展示2本；每本配置库存2。先检查当天目录，再决定碎玉投入。"
        )
        guide.table(
            ["等级", "技能书", "书ID", "价格", "入口"],
            advanced,
            [0.45, 1.45, 1.35, 1.15, 1.25],
            compact=True,
        )
        guide.h3("职业技能对象全表")
        guide.table(
            ["技能(内部ID)", "形态", "类别", "角色等级门槛", "冷却", "实际定位"],
            skill_rows(skills_by_prof[pid]),
            [1.8, 0.55, 0.95, 1.1, 0.7, 2.5],
            compact=True,
        )
        if pid == "yushi":
            guide.callout(
                "隐藏大神传承",
                "羽士在80级后可学习九天雷引、太乙玄光、冰魄缠身。它们只从实际等级70+怪物极低概率掉落，不在商店出售。",
                "gold",
            )
        if pid == "wuyao":
            guide.callout(
                "隐藏大神传承",
                "巫妖在80级后可学习黄泉五毒、万象噬魂、九幽毒瘴。它们只从实际等级70+怪物极低概率掉落，不在商店出售。",
                "gold",
            )

    # 5. Fangshi
    guide.pagebreak()
    guide.h1("5. 方士重点：从创建到大神传承")
    guide.callout(
        "方士不是“多一个法师”",
        "方士是中立召唤/治疗/混合输出职业。核心体验来自实体虎鹤龟、同房间队伍治疗、三灵共鸣、技能替换后保留召唤能力，以及能使用仙妖双方公共设施。",
    )
    guide.h2("5.1 身份、出生与中立规则")
    guide.bullets(
        [
            "创建时选择 race=third、profession=fangshi，起手技能固定为灵弹术。",
            "随机进入仙侧或妖侧起始区域，但职业身份始终是中立。",
            "可使用仙妖双方公共驿站、休息点、仓库、聊天、荣誉商店与支持的NPC任务。",
            "可与两边玩家组队、交易、寄送、私聊、跟随、加好友，并可加入两边帮派。",
            "创建帮派时归属取决于当时所在仙城或妖城；方士本身不能转换阵营，也不会消耗轮回符印。",
            "荣誉显示为“灵气”，排行标签为“【方】”。",
        ]
    )
    guide.h2("5.2 方士等级里程碑")
    guide.table(["阶段", "能力与行动"], [list(row) for row in FANGSHI_MILESTONES], [0.8, 4.4])
    guide.h2("5.3 1-50级普通技能书全表")
    guide.paragraph(
        "普通商店价格来自当前 can_buy_book_list.csv。支付时会按碎玉总价值自动拆分、找零，不需要玩家手工打碎或兑换玉石。"
    )
    guide.table(
        ["等级", "技能书", "书ID", "价格", "入口"],
        book_rows(books_by_prof["fangshi"], advanced=False),
        [0.45, 1.55, 1.35, 1.2, 1.15],
        compact=True,
    )
    guide.h2("5.4 治疗：单人、组队与死亡边界")
    guide.table(
        ["能力", "无队伍", "有队伍", "明确不会发生"],
        [
            ["灵治 / 灵治·秘", "只治疗自己", "仍只治疗自己", "不会治疗队友；不会超过生命上限"],
            ["灵莲铺", "只治疗自己", "治疗自己 + 同房间、同队伍、存活队友", "不治远程队友、外人或死亡成员"],
            ["鹤灵被动治疗", "周期治疗存活主人", "召唤本身不扩大成全队治疗", "主人死亡时不会复活"],
            ["万灵朝生", "治疗自己", "治疗自己 + 同房间存活队友", "90秒冷却；不复活、不跨房间"],
            ["鹤灵共鸣", "治疗方士", "治疗同房间存活队友", "受治疗削弱影响；完美共鸣最高15%"],
        ],
        [1.1, 1.25, 1.85, 2.0],
    )
    guide.h2("5.5 虎、鹤、龟实体召唤")
    guide.table(
        ["灵兽", "首次门槛", "战斗定位", "共鸣效果", "生命周期"],
        [
            ["虎灵", "10级", "偏攻击，立即跟随主人当前目标", "缩短正在冷却的方士技能3-6秒", "死亡、到期、主人掉线/离场或主动解散后清理"],
            ["鹤灵", "15级", "偏防御，约每6秒治疗存活主人", "治疗自己与同房间存活队友", "遵守治疗削弱与不复活规则"],
            ["龟灵", "20级", "偏生命/承伤，约每10秒强制仇恨", "清除dot和curse；完美时加清curse2", "主人换目标时重置旧仇恨并立即跟随"],
        ],
        [0.65, 0.75, 1.8, 1.6, 1.75],
        compact=True,
    )
    guide.table(
        ["人物等级", "同时召唤上限", "建议组合"],
        [
            ["1-29", "1只", "单刷输出选虎；危险战斗选鹤或龟"],
            ["30-59", "2只", "虎+鹤兼顾输出续航；高压战斗鹤+龟"],
            ["60+", "3只", "summon all 原子补齐虎鹤龟；任一失败不会留下半套"],
        ],
        [1, 1, 3.2],
    )
    guide.h3("召唤命令")
    guide.table(
        ["命令", "用途"],
        [
            ["summon", "打开召唤界面"],
            ["summon huling / heling / guiling", "召唤指定灵兽"],
            ["summon all", "60级起补齐三灵"],
            ["summon list", "查看当前召唤"],
            ["summon dismiss", "主动解散"],
            ["summon resonance", "让同房间存活灵兽触发共鸣"],
        ],
        [1.5, 3.7],
    )
    guide.h2("5.6 三灵共鸣")
    guide.table(
        ["参与灵兽", "效果", "冷却"],
        [
            ["只有虎", "仅减少当前正在冷却的方士技能；不清全局冷却", "90秒"],
            ["只有鹤", "按技能阶段治疗方士与同房间存活队友", "90秒"],
            ["只有龟", "清除dot与curse", "90秒"],
            ["虎+鹤+龟", "三种效果 + 回复15%最大法力 + 清公共timeCold + 额外清curse2", "120秒"],
        ],
        [1.2, 3.3, 0.7],
    )
    guide.callout(
        "共鸣边界",
        "死亡灵兽不计数；远程灵兽不计数；不会复活玩家；冷却保存在人物持久数据中，重连不能重置。",
        "gold",
    )
    guide.h2("5.7 被动与职业任务")
    guide.table(
        ["等级", "路线", "奖励/作用"],
        [
            ["20", "方士传人：三灵初契", "三灵契印，方士专属20级挂件"],
            ["29/32/35/38/41", "灵智魂1-5", "每本只能学习下一段，永久提升力、敏、智"],
            ["53", "灵息试炼 -> 冥府守契 -> 五行驭灵 -> 三灵归一", "四段任务必须按序并由正确NPC发放；终点奖励三灵合一书"],
        ],
        [0.9, 2.6, 2.6],
    )
    guide.h2("5.8 60-75级每日高级书与替换关系")
    guide.paragraph(
        "方士高阶池共有10本，每天独立轮换2本，每本库存2。65/75级多为替换书：学习后旧技能键消失，但召唤、治疗等旧能力必须由新技能继续承接。"
    )
    guide.table(
        ["等级", "技能书", "书ID", "价格", "入口"],
        book_rows(books_by_prof["fangshi"], advanced=True),
        [0.45, 1.55, 1.35, 1.15, 1.2],
        compact=True,
    )
    guide.table(
        ["旧技能", "替换技能", "必须保留的能力"],
        [
            ["灵百雷", "灵百雷11级", "强化攻击，按自身真实10段模型成长"],
            ["灵玄影", "灵玄影(2级)", "全属性增益"],
            ["三灵合一", "三灵合一(2级)", "三灵附体；60级 summon all 仍可用"],
            ["灵穿心", "灵穿心(2级)", "强化物理攻击"],
            ["灵旋", "灵玄·秘", "强化攻击"],
            ["灵火烧", "灵火烧·秘", "降低敌方防御"],
            ["灵治", "灵治·秘", "自疗能力"],
            ["灵盾", "灵盾·秘", "防护能力"],
            ["虎灵", "虎灵·秘", "虎灵实体召唤与共鸣等级"],
        ],
        [1.15, 1.5, 3.0],
    )
    guide.h2("5.9 隐藏大神技能")
    guide.table(
        ["技能", "角色", "门槛", "平衡限制"],
        [
            ["太虚灵陨", "风系巨额爆发", "人物80级；技能阶段80/100/120/140/160", "60秒冷却"],
            ["万灵朝生", "同房间存活队伍大治疗", "人物80级；技能阶段80/100/120/140/160", "90秒冷却；不复活"],
            ["四象封禁", "短时压制物理攻击", "人物80级；技能阶段80/100/120/140/160", "持续不超过12秒；120秒冷却"],
        ],
        [1.05, 1.65, 2.1, 1.5],
    )
    guide.bullets(
        [
            "九本隐藏书共用总掉率9/100000，九本等概率，单本长期均值约1/100000。",
            "资格只看怪物实际等级70+，不看击杀者等级或地图名字。",
            "团队Boss、团队普通怪与单人击杀各自每只怪只掷一次；队伍人数不会放大掉率。",
            "队伍/个人地面归属保护120秒；无人拾取5分钟后清理。",
            "任何职业可拾取、交易、寄送与存储，但学习时严格检查80级和职业。",
            "重复学习不会消耗技能书；成功掉落写入 hidden_skill_drop.log。",
        ]
    )
    guide.h2("5.10 方士装备策略")
    guide.callout(
        "为什么没有方士专属套装",
        "当前设计让方士兼容所有受职业限制的旧装备路线，因此不再叠加一套专属高数值装备，避免召唤、治疗与广泛装备兼容同时造成强度跃迁。",
    )
    guide.bullets(
        [
            "前期优先穿上等级最高且满足限制的装备；用 auto_equip 只补空位。",
            "单刷输出可偏全属性、力量/物攻与命中；组队治疗/召唤可偏智力、法力、生命与防御。",
            "虎鹤龟已提供攻击、续航与承伤分工，装备选择应补当前召唤组合的短板。",
            "高阶替换前后不要只看技能名；确认治疗、召唤和共鸣入口仍可使用。",
        ]
    )
    guide.h2("5.11 方士44个技能对象全表")
    guide.table(
        ["技能(内部ID)", "形态", "类别", "角色等级门槛", "冷却", "实际定位"],
        skill_rows(skills_by_prof["fangshi"]),
        [1.8, 0.55, 0.95, 1.1, 0.7, 2.5],
        compact=True,
    )

    # 6. Equipment
    guide.pagebreak()
    guide.h1("6. 所有职业装备成长系统")
    guide.h2("6.1 装备位与穿戴检查")
    guide.table(
        ["类别", "装备位"],
        [
            ["武器", "双手武器、主手武器、副手武器"],
            ["防具", "头部、衣服、护腕、手套、裤子、鞋子"],
            ["首饰", "戒指、项链、手镯"],
            ["饰物", "披风、挂件、携带物"],
        ],
        [1, 4.2],
    )
    guide.bullets(
        [
            "穿戴前检查：物品必须在背包、可装备、非任务禁用品、等级足够、职业允许、力量/敏捷/智力达标。",
            "双手武器与主副手互斥；auto_equip 会保护已有装备，不会强拆。",
            "自动评分优先考虑需求等级、稀有等级、全属性/单属性、生命法力；武器再看攻击/命中/暴击，防具再看防御/闪避/减伤。",
            "全身黄水玉类宝石存在总量限制；自动穿装会在超限时拒绝。",
        ]
    )
    guide.h2("6.2 稀有度")
    guide.table(
        ["稀有等级", "显示前缀", "养成建议"],
        [
            ["0", "无前缀", "过渡白装；等级提升快时不必重投入"],
            ["1-2", "【优良】", "低中期可用"],
            ["3-4", "【精制】", "可进入熔炼候选；值得比较词条"],
            ["5", "【神炼】", "中高阶重点保留"],
            ["6", "【天降】", "高价值掉落"],
            ["7", "【幻化】", "高端装备/特殊来源"],
            ["8", "【空觉】", "后期稀有层级"],
            ["9", "【破空】", "后期稀有层级"],
            ["10", "【寂灭】", "顶级稀有层级"],
            ["11", "【三摩地】", "当前映射中的最高稀有前缀"],
        ],
        [1, 1.2, 3.0],
    )
    guide.h2("6.3 装备来源")
    guide.table(
        ["来源", "特点", "适合阶段"],
        [
            ["普通怪物", "经验、金钱与随机装备；50级后野外动态怪随人物成长", "全阶段"],
            ["动态精英/Boss", "动态怪有2.5%精英、0.5%Boss机会，通常更值得组队", "50级+"],
            ["固定Boss与副本", "固定等级怪仍可提供高阶装备；副本通常关闭动态缩放", "按副本门槛"],
            ["任务奖励", "职业20级挂件、主线武器/饰物等明确奖励", "前中期"],
            ["荣誉商店", "以荣誉/灵气路线换取装备", "中高期"],
            ["配方锻造", "矿物 + 已学配方 + 锻造熟练度", "1-70级配方"],
            ["熔炼", "两件符合条件的装备合成普通或特殊产物", "精制装备后"],
            ["装备转化/宝石镶嵌", "调整附加属性与插槽效果", "形成长期装备后"],
        ],
        [1.1, 2.6, 1.5],
    )
    guide.h2("6.4 配方锻造")
    guide.paragraph(
        "当前 Xiand 锻造不是“碎片-精华-核心”模型，而是学习配方后消耗铜矿、锌矿、铁矿、银矿、金矿、铂金、钨金、钒铁、钛金、陨铁、坚晶、玄铁石等材料制造装备。"
    )
    guide.table(["配方类型", "当前数量", "装备等级范围"], forge_summary, [1.6, 1, 1.4])
    guide.table(
        ["装备等级", "类型", "示例成品", "熟练度要求", "材料示例"],
        forge_samples,
        [0.75, 1.1, 1.6, 1.0, 2.3],
        compact=True,
    )
    guide.h2("6.5 熔炼")
    guide.bullets(
        [
            "选择两件未穿戴、可熔炼的装备；通常要求稀有度达到精制(3)或带明确特殊来源。",
            "同类+同类通常得到同类；武器+防具可走首饰产物；涉及首饰的跨类组合会被限制。",
            "普通产物等级按两件输入中的较低等级推导到下一合法装备档。",
            "当前特殊熔炼表有99条组合；命中特殊配方时可产出固定特殊装备。",
            "玉石档位可提高特殊产物概率，但不应以客户端显示数值作为最终结算依据。",
        ]
    )
    guide.h2("6.6 宝石、凹槽与装备转化")
    guide.table(
        ["系统", "作用", "注意事项"],
        [
            ["红/蓝/黄宝石", "提供攻击、防御、属性或特殊增益", "先看装备凹槽颜色与数量"],
            ["凹槽", "动态装备可能生成1-3个凹槽", "不要为了低级过渡装投入稀有宝石"],
            ["装备转化", "重置/转换附加属性", "有次数与玉石成本；先确认装备会长期使用"],
            ["强化/词条比较", "比较全属性、主属性、生命法力、攻击/防御与穿透", "职业定位不同，不只看稀有前缀"],
        ],
        [1.1, 2.0, 2.4],
    )
    guide.h2("6.7 71级以上装备境界")
    guide.paragraph(
        "73级以上装备可由动态掉落系统按怪物实际等级生成；名字带境界前缀，属性还会叠加对应区间倍率。不要把境界前缀与人物称号混为一谈。"
    )
    guide.table(["装备等级", "名字前缀", "区间倍率"], [list(row) for row in REALM_PREFIXES], [1.2, 2.1, 1.2])
    guide.h2("6.8 各职业装备方向")
    guide.table(
        ["职业", "优先属性", "风险提醒"],
        [
            [p["name"], p["gear"], "先满足穿戴限制，再按实际技能循环比较总收益。"]
            for p in PROFESSIONS
        ],
        [0.75, 3.2, 1.7],
    )

    # 7. Dynamic monsters and hidden drops
    guide.h1("7. 动态怪、Boss与隐藏技能书")
    guide.h2("7.1 动态怪从50级开始")
    guide.bullets(
        [
            "普通、非和平、非副本房间在人物50级起启用动态NPC。",
            "普通难度按人物等级生成；噩梦额外+5级，地狱额外+10级，之后再随机+0到2级。",
            "怪物等级受服务器MAX_LEVEL限制；动态怪有0.5%概率成为Boss、2.5%概率成为精英。",
            "普通注册副本关闭动态缩放；破散之地是明确例外，仍保留动态怪。",
        ]
    )
    guide.h2("7.2 隐藏大神书的资格与归属")
    guide.table(
        ["判断项", "正确规则", "错误理解"],
        [
            ["资格等级", "被击杀怪物实际等级70+", "玩家70级就必定有资格"],
            ["总掉率", "9/100000，共9本等概率", "每个队员各掷一次"],
            ["可学习等级", "人物80级且职业匹配", "捡到即可跨职业学习"],
            ["归属保护", "个人或队伍120秒", "完整5分钟都属于原队伍"],
            ["清理", "无人拾取5分钟后删除", "永久留在地面"],
            ["副本", "固定70+怪同样可掉；普通副本不动态升怪", "副本怪绝不掉落"],
        ],
        [1.0, 2.4, 2.0],
    )
    guide.table(
        ["职业", "隐藏技能1", "隐藏技能2", "隐藏技能3"],
        [
            ["方士", "太虚灵陨", "万灵朝生", "四象封禁"],
            ["羽士", "九天雷引", "太乙玄光", "冰魄缠身"],
            ["巫妖", "黄泉五毒", "万象噬魂", "九幽毒瘴"],
        ],
        [0.8, 1.45, 1.45, 1.45],
    )

    # 8. Shared systems
    guide.h1("8. 覆盖全职业的公共玩法")
    guide.table(
        ["系统", "入口/命令", "核心价值", "成长建议"],
        [
            ["新手引导", "newbie_guide", "20步真实动作验证、自动领奖与完成弹窗", "按弹窗直接继续；check仅用于历史进度或异常补领"],
            ["地图与打怪", "map_display / look / fight", "经验、金钱、装备与材料", "选择接近自身等级的区域"],
            ["任务", "mytasks", "经验、金钱、职业饰物与技能书", "优先职业限制和连续任务"],
            ["技能", "buy_items book <职业ID> / myskills", "形成职业循环", "购买后必须在背包学习"],
            ["自动穿装", "auto_equip", "补齐空装备位", "不会替换现有装备，需手工比较升级"],
            ["队伍", "my_term", "组队打Boss、分担风险", "方士治疗与共鸣要求同房间队伍"],
            ["副本", "fb_entry / fb_leave", "固定挑战、团队奖励与掉落分配", "普通副本不使用动态怪，破散之地例外"],
            ["聊天/社交", "chatroom_list / tell / follow", "组织队伍、交易与社区", "方士可跨仙妖社交"],
            ["帮派", "my_bang / bang_*", "组织、职位、帮派目标与城池归属", "方士可加入两边帮派"],
            ["家园", "home_*", "住房、种养、功能房、店铺与宠物", "不限制职业，作为长期资源循环"],
            ["仓库/寄送/交易", "仓库入口 / sendother / trade", "保存与流通装备、材料、技能书", "隐藏书可交易，但学习仍验职业"],
            ["排行榜", "look_top / paihang_list", "等级、财富、轮回值等目标", "长期检查自身成长位置"],
            ["荣誉/灵气", "honer_*", "PK与荣誉商店", "方士显示灵气并保留中立规则"],
            ["锻造/熔炼", "viceskill_duanzao_* / viceskill_ronglian_*", "配方装备与特殊合成", "先积累材料和熟练度"],
            ["宝石/转化", "equip_xiangqian_* / convert_equip_*", "定向强化长期装备", "高等级稳定装备再投入"],
            ["高级书", "yushi_buy_hlbook_list", "60级以上职业进阶", "每天检查2本职业独立轮换"],
            ["离线/自动修炼", "自动战斗与 autolearn 区域", "降低重复操作成本", "确保技能、药品和路线与职业匹配"],
        ],
        [1.0, 1.6, 2.0, 2.2],
        compact=True,
    )
    guide.h2("8.1 玉石购买的自动兑换")
    guide.bullets(
        [
            "购买技能书和其他接入YUSHID的商品时，系统按玉石总价值判断是否足够。",
            "支付过程自动拆分高面额玉石并找零，无需玩家手工打碎和逐级兑换。",
            "高级技能书以服务器目录中的价格、职业、当日轮换与库存为准，不能用伪造链接改价。",
            "碎玉和黄金不足、背包已满或支付失败时不会完成购买。",
        ]
    )

    # 9. Checklists
    guide.h1("9. 0到高阶实战检查表")
    guide.h2("9.1 所有职业通用")
    guide.table(
        ["检查点", "完成标准"],
        [
            ["创建完成", "阵营/职业正确，起手技能存在，桃木剑与三件基础防具入包并穿戴"],
            ["新手引导", "20步均由真实动作验证；完成后自动领奖弹窗，无需返回引导页手动检查"],
            ["学技能", "技能书已买、已入包、点击学习后在myskills可见"],
            ["练熟练度", "技能成功施放后原始熟练度会增长；百分比可能长时间显示0%"],
            ["更新装备", "需求等级、职业、主属性、装备位均满足；双手与主副手不冲突"],
            ["做任务", "职业20级奖励与连续任务按序完成，不只刷怪升级"],
            ["进入50+", "野外动态怪随人物等级变化，开始关注精英/Boss和动态装备"],
            ["进入60+", "每天查看本职业高级书轮换，避免跨职业或非当日书"],
            ["进入70+", "挑战实际等级70+怪；开始境界装备与隐藏书长期追求"],
            ["进入80+", "隐藏书仍需职业匹配；按80/100/120/140/160提升神技阶段"],
            ["进入161+", "围绕境界装备、词条、宝石、团队、副本、帮派与家园做长期养成"],
        ],
        [1.25, 4.1],
    )
    guide.h2("9.2 方士专用")
    guide.table(
        ["检查点", "完成标准"],
        [
            ["治疗", "灵治只自疗；灵莲铺无队只自疗，有队只加治同房间存活队友"],
            ["召唤", "10/15/20级分别掌握虎/鹤/龟；30级2只、60级3只"],
            ["共鸣", "只统计同房间存活灵兽；普通90秒、三灵完美120秒"],
            ["替换", "虎灵·秘后仍可召虎；三灵合一2后仍可summon all"],
            ["被动", "灵智魂按29/32/35/38/41顺序学习，属性实际生效"],
            ["任务", "20级三灵初契；53级四段链最终获得三灵合一书"],
            ["装备", "可用旧职业受限装备，但按角色定位补全属性而不是盲追单一稀有度"],
            ["神技", "太虚灵陨/万灵朝生/四象封禁不在任何商店，只走极低概率掉落"],
        ],
        [1.25, 4.1],
    )

    # 10. Troubleshooting and source notes
    guide.h1("10. 常见问题与数据来源")
    guide.table(
        ["问题", "先检查"],
        [
            ["买完技能书在哪里学？", "打开背包，找到书并点击“学习”；购买本身不学习。"],
            ["技能一直0%？", "查看原始熟练度；1级要2000，20点才显示1%，且成功施放约1/3概率增长。"],
            ["方士没组队时群疗给谁？", "灵莲铺和万灵朝生只治疗自己；不会治疗路人。"],
            ["为什么召唤不齐？", "确认人物等级上限、已学虎鹤龟技能、同类型未重复、召唤未死亡/过期。"],
            ["为什么装备穿不上？", "检查背包位置、可装备、等级、职业、力敏智、装备位和黄水玉总量。"],
            ["为什么70级没掉隐藏书？", "只进入资格池；总掉率仍为9/100000，且看怪物实际等级。"],
            ["高级书为什么今天没有？", "每职业每天只轮换2本；第二天或下次刷新再检查。"],
            ["方士为什么没有专属装备套？", "方士已兼容旧职业限制装备，专属高数值套会造成额外强度跃迁。"],
        ],
        [1.9, 3.7],
    )
    guide.h2("10.1 本手册读取的主要代码与数据")
    guide.bullets(
        [
            "职业创建与初始技能：gamelib/d/init",
            "20步新手进度、自动奖励与弹窗队列：gamelib/single/daemons/newbied.pike",
            "完成弹窗接口与前端：gamelib/single/daemons/http_api_daemon.pike、vue_source/index.html、vue_source/js/app.js",
            "初始属性：lowlib/mudlib/inherit/user.pike",
            "等级成长：lowlib/mudlib/inherit/feature/level.pike",
            "技能对象：gamelib/single/skills/",
            "技能书目录与价格：gamelib/data/can_buy_book_list.csv",
            "学习与熟练度：lowlib/mudlib/inherit/feature/readed.pike、lowlib/wapmud2/inherit/feature/fight.pike",
            "装备与穿戴：lowlib/mudlib/inherit/feature/equip.pike、gamelib/cmds/auto_equip.pike",
            "掉落与高阶装备：gamelib/single/daemons/itemsd.pike、bossdropd.pike",
            "锻造与熔炼：duanzaod.pike、rongliand.pike、duanzao.csv、ronglian.csv",
            "方士召唤与共鸣：gamelib/cmds/summon.pike、gamelib/single/daemons/summond.pike",
            "任务、副本、家园、帮派、排行与玉石：对应cmds与daemon实现。",
        ]
    )
    guide.callout(
        "版本声明",
        f"本文生成于 {build_date}，分支 {branch}，提交基线 {commit}。技能书每日轮换、库存、活动和运营价格以服务器当日界面为准。",
        "gold",
    )

    # Write Markdown before PDF build, then build the PDF in two passes for TOC.
    MD_PATH.write_text("\n".join(guide.md).rstrip() + "\n", encoding="utf-8")
    doc.multiBuild(story)


if __name__ == "__main__":
    build_handbook()
