from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

import fitz
from rapidocr_onnxruntime import RapidOCR


ROOT = Path(__file__).resolve().parents[2]
RULE_DIR = ROOT / "规则"
OUTPUT_DIR = ROOT / "data" / "raw_rule_cards"


CARD_HEADER_TYPES = {
    "LEGION CARD": "legion",
    "LEGIONCARD": "legion",
    "LEGIONGARD": "legion",
    "TACTIC CARD": "tactic",
    "TACTICCARD": "tactic",
    "MASTER CARD": "master",
    "MASTERCARD": "master",
    "DIVINITY CARD": "divinity",
    "DIVINITYCARD": "divinity",
    "ARTIFACT CARD": "artifact",
    "ARTIFACTCARD": "artifact",
    "DESTRUCTION": "calamity",
    "COST CARD": "cost",
    "COSTCARD": "cost",
}

MANUAL_NAME_OVERRIDES = {
    ("2.pdf", 22): "夺命诗人埃吉尔",
    ("4.pdf", 7): "本多忠胜",
    ("4.pdf", 10): "真田幸村",
    ("4.pdf", 15): "源义经",
    ("4.pdf", 23): "草薙剑",
    ("4.pdf", 28): "武田信玄",
    ("4.pdf", 30): "冲田总司",
}

NAME_BLOCKLIST = {
    "SAMPLE",
    "CARD",
    "LEGIONCARD",
    "LEGION CARD",
    "TACTICCARD",
    "TACTIC CARD",
    "MASTERCARD",
    "MASTER CARD",
    "DIVINITYCARD",
    "DIVINITY CARD",
    "ARTIFACTCARD",
    "ARTIFACT CARD",
    "DESTRUCTION",
    "COSTCARD",
    "COST CARD",
    "天灾等级",
    "军团卡",
    "战术卡",
    "主宰卡",
    "主城卡",
    "圣物卡",
    "士气卡",
    "阵营效果",
    "通用",
    "阿斯加德阵营",
    "高天原阵营",
    "太阳城",
    "高天原",
    "阿斯加德",
    "军团",
    "血量",
    "宰卡",
    "主宰者",
    "主堂者",
    "主军者",
    "主晕者",
    "生宰者",
    "领军灿",
    "领军拟",
    "武者灿",
    "武者沁",
    "术师少",
    "弓手",
    "圣物函",
    "制裁",
    "降魔",
    "特殊灿",
    "战术",
}


@dataclass
class OcrLine:
    text: str
    score: float
    min_x: float
    min_y: float
    max_x: float
    max_y: float


def main() -> None:
    args = parse_args()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    engine = RapidOCR()
    pdf_names = [args.pdf] if args.pdf else ["2.pdf", "4.pdf", "8.pdf"]
    for pdf_name in pdf_names:
        manifests = extract_pdf(engine, RULE_DIR / pdf_name, args.start_page, args.end_page)
        manifest_path = OUTPUT_DIR / f"manifest_{Path(pdf_name).stem}.json"
        merged = merge_manifest_rows(load_manifest(manifest_path), manifests)
        manifest_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {len(merged)} entries to {manifest_path}")

    if not args.pdf:
        merged_all: list[dict] = []
        for pdf_name in pdf_names:
            manifest_path = OUTPUT_DIR / f"manifest_{Path(pdf_name).stem}.json"
            merged_all.extend(load_manifest(manifest_path))
        all_manifest_path = OUTPUT_DIR / "manifest.json"
        all_manifest_path.write_text(json.dumps(merged_all, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {len(merged_all)} entries to {all_manifest_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", help="single pdf file name under 规则/, e.g. 4.pdf")
    parser.add_argument("--start-page", type=int, default=1, help="1-based inclusive page number")
    parser.add_argument("--end-page", type=int, default=0, help="1-based inclusive page number, 0 means to the end")
    return parser.parse_args()


def extract_pdf(engine: RapidOCR, pdf_path: Path, start_page: int, end_page: int) -> list[dict]:
    doc = fitz.open(pdf_path)
    pdf_output = OUTPUT_DIR / pdf_path.stem
    pdf_output.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    start_index = max(0, start_page - 1)
    end_index = doc.page_count if end_page <= 0 else min(doc.page_count, end_page)
    print(f"processing {pdf_path.name} pages {start_index + 1}-{end_index}")
    for page_index in range(start_index, end_index):
        page = doc.load_page(page_index)
        pix = page.get_pixmap(matrix=fitz.Matrix(2.2, 2.2), alpha=False)
        page_image = pdf_output / f"page_{page_index + 1:02d}.jpg"
        page_image.write_bytes(pix.tobytes("jpg"))
        print(f"- page {page_index + 1}/{doc.page_count}")
        try:
            result, _ = engine(str(page_image))
        except Exception as exc:
            print(f"  ocr failed on {pdf_path.name} page {page_index + 1}: {exc}")
            continue
        lines = parse_lines(result or [])
        card_type = detect_card_type(lines)
        if card_type is None:
            print("  skipped: no card header detected")
            continue
        card_name = detect_card_name(lines, card_type)
        if not card_name:
            print(f"  skipped: no card name detected ({card_type})")
            continue
        card_name = MANUAL_NAME_OVERRIDES.get((pdf_path.name, page_index + 1), card_name)

        rows.append(
            {
                "pdf": pdf_path.name,
                "page": page_index + 1,
                "card_type": card_type,
                "name": card_name,
                "image_path": str(page_image.relative_to(ROOT)).replace("\\", "/"),
                "ocr_lines": [line.text for line in lines[:24]],
            }
        )
        print(f"  captured: {card_type} | {card_name}")
    return rows


def load_manifest(manifest_path: Path) -> list[dict]:
    if not manifest_path.exists():
        return []
    try:
        loaded = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return loaded if isinstance(loaded, list) else []


def merge_manifest_rows(existing: list[dict], incoming: list[dict]) -> list[dict]:
    merged: dict[tuple[str, int], dict] = {}
    for row in existing + incoming:
        if not isinstance(row, dict):
            continue
        key = (str(row.get("pdf", "")), int(row.get("page", 0)))
        merged[key] = row
    result = list(merged.values())
    result.sort(key=lambda row: (str(row.get("pdf", "")), int(row.get("page", 0))))
    return result


def parse_lines(result: list) -> list[OcrLine]:
    lines: list[OcrLine] = []
    for item in result:
        box, text, score = item
        xs = [point[0] for point in box]
        ys = [point[1] for point in box]
        lines.append(
            OcrLine(
                text=str(text).strip(),
                score=float(score),
                min_x=min(xs),
                min_y=min(ys),
                max_x=max(xs),
                max_y=max(ys),
            )
        )
    lines.sort(key=lambda row: (row.min_y, row.min_x))
    return lines


def detect_card_type(lines: list[OcrLine]) -> str | None:
    joined = " ".join(line.text.upper() for line in lines[:16])
    compact = re.sub(r"[^A-Z]", "", joined)
    for marker, card_type in CARD_HEADER_TYPES.items():
        compact_marker = re.sub(r"[^A-Z]", "", marker.upper())
        if marker in joined or compact_marker in compact:
            return card_type
    return None


def detect_card_name(lines: list[OcrLine], card_type: str) -> str:
    candidates: list[tuple[float, str]] = []
    for line in lines:
        text = normalize_text(line.text)
        if not text:
            continue
        if _looks_like_vertical_label(line):
            continue
        if text.upper() in NAME_BLOCKLIST:
            continue
        if any(char.isdigit() for char in text):
            continue
        if len(text) <= 1 or len(text) > 16:
            continue
        if re.search(r"[A-Za-z]", text):
            continue
        if text.startswith("我方") or text.startswith("对方") or text.startswith("登场") or text.startswith("进攻"):
            continue
        if text.startswith("主动") or text.startswith("触发") or text.startswith("持续") or text.startswith("规则上"):
            continue
        if text.startswith("（") or text.startswith("("):
            continue
        if text.startswith("『"):
            continue
        if any(word in text for word in ["主宰者", "军团", "战术", "圣物", "主城", "血量", "兵力", "天灾等级"]):
            continue
        if any(word in text for word in ["位于前排", "位于后排"]):
            continue

        score = line.score
        score += _name_position_bonus(card_type, line)
        score += _left_title_bonus(line)
        score -= _subtitle_penalty(line)
        candidates.append((score, text))

    candidates.sort(reverse=True)
    seen = set()
    for _, text in candidates:
        if text in seen:
            continue
        seen.add(text)
        return text
    return ""


def normalize_text(text: str) -> str:
    text = text.replace(" ", "")
    text = text.replace("· ", "·")
    text = text.replace("·", "·")
    text = text.replace("“", "").replace("”", "")
    text = text.replace("【", "").replace("】", "")
    return text.strip(" :：.-_")


def _name_position_bonus(card_type: str, line: OcrLine) -> float:
    y = line.min_y
    if 880 <= y <= 980:
        return 1.0
    if 820 <= y < 880 or 980 < y <= 1030:
        return 0.3
    if card_type == "master" and 120 <= y <= 420:
        return 0.1
    return 0.0


def _left_title_bonus(line: OcrLine) -> float:
    if 200 <= line.min_x <= 320 and line.max_x <= 620 and 880 <= line.min_y <= 980:
        return 1.2
    if line.min_x <= 340 and line.max_x <= 650 and 880 <= line.min_y <= 990:
        return 0.7
    return 0.0


def _subtitle_penalty(line: OcrLine) -> float:
    if line.min_x >= 620 and line.min_y <= 980:
        return 0.9
    return 0.0


def _looks_like_vertical_label(line: OcrLine) -> bool:
    width = line.max_x - line.min_x
    height = line.max_y - line.min_y
    return width <= 110 and height >= 140


if __name__ == "__main__":
    main()
