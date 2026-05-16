from __future__ import annotations

import json
import re
import hashlib
from pathlib import Path
from typing import Any

import pandas as pd
from docx import Document


HEADER_KEYWORDS = {"卡名", "卡效", "费用", "兵力", "天灾等级", "卡牌属性", "备注"}


def normalize_text(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).replace("\r", "\n").strip()
    return "" if text.lower() == "nan" else text


def parse_number(value: Any) -> int | None:
    text = normalize_text(value)
    if not text or text == "/":
        return None
    match = re.search(r"-?\d+", text)
    return int(match.group()) if match else None


def slugify_series(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "series"


def build_unique_sample_id(series: str, running_index: int) -> str:
    prefix = slugify_series(series)
    if prefix != "series":
        return f"{prefix}-{running_index:03d}"
    digest = hashlib.sha1(series.encode("utf-8")).hexdigest()[:8]
    return f"series-{digest}-{running_index:03d}"


def parse_faq_from_docx(docx_path: Path) -> list[dict[str, Any]]:
    document = Document(docx_path)
    paragraphs = [paragraph.text.strip() for paragraph in document.paragraphs if paragraph.text.strip()]
    faq_items: list[dict[str, Any]] = []
    current_question = ""
    current_answer_lines: list[str] = []

    def flush() -> None:
        nonlocal current_question, current_answer_lines
        if not current_question:
            return
        faq_items.append(
            {
                "id": f"faq-{len(faq_items) + 1:03d}",
                "question": current_question,
                "answer": "\n".join(current_answer_lines).strip(),
                "relatedCardIds": [],
                "keywords": [],
                "source": docx_path.name,
            }
        )
        current_question = ""
        current_answer_lines = []

    for line in paragraphs:
        if line.startswith(("Q：", "Q:", "Q：", "Q:")):
            flush()
            current_question = re.sub(r"^Q[:：]\s*", "", line)
            continue
        if line.startswith(("A：", "A:")):
            current_answer_lines.append(re.sub(r"^A[:：]\s*", "", line))
            continue
        if current_question:
            if current_answer_lines:
                current_answer_lines.append(line)
            else:
                current_question = f"{current_question} {line}".strip()
    flush()
    return faq_items


def parse_cards_from_excel(xlsx_path: Path) -> list[dict[str, Any]]:
    workbook = pd.ExcelFile(xlsx_path)
    cards: list[dict[str, Any]] = []
    running_index = 1

    for sheet_name in workbook.sheet_names:
        df = pd.read_excel(xlsx_path, sheet_name=sheet_name, header=None)
        current_faction = sheet_name
        header_row: int | None = None

        for idx, row in df.iterrows():
            values = [normalize_text(cell) for cell in row.tolist()]
            non_empty = [cell for cell in values if cell]
            if not non_empty:
                continue

            if len(non_empty) == 1 and non_empty[0] not in HEADER_KEYWORDS and len(non_empty[0]) <= 24:
                current_faction = non_empty[0]
                continue

            if "卡名" in non_empty and "卡效" in non_empty:
                header_row = idx
                continue

            if header_row is None:
                continue

            name = values[0] if len(values) > 0 else ""
            effect = values[1] if len(values) > 1 else ""
            if not name or name in HEADER_KEYWORDS:
                continue

            card = {
                "id": build_unique_sample_id(xlsx_path.stem, running_index),
                "name": name.replace("\n", " ").strip(),
                "alias": [],
                "series": xlsx_path.stem,
                "cardNo": f"{running_index:03d}",
                "image": "",
                "type": values[5] if len(values) > 5 and values[5] else "待识别",
                "subType": "",
                "faction": current_faction,
                "rarity": values[6] if len(values) > 6 else "",
                "cost": parse_number(values[2] if len(values) > 2 else ""),
                "attack": parse_number(values[3] if len(values) > 3 else ""),
                "health": None,
                "tags": [],
                "effectText": effect,
                "flavorText": values[6] if len(values) > 6 else "",
                "faqIds": [],
                "searchText": " ".join(
                    part for part in [name, current_faction, values[5] if len(values) > 5 else "", effect] if part
                ),
                "source": {
                    "file": xlsx_path.name,
                    "page": 1,
                },
                "verified": False,
            }
            cards.append(card)
            running_index += 1
    return cards


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
