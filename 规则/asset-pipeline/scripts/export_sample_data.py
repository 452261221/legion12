from __future__ import annotations

from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.normalize.sample_extract import parse_cards_from_excel, parse_faq_from_docx, write_json


def main() -> None:
    source_root = PROJECT_ROOT.parent
    faq_items = parse_faq_from_docx(source_root / "Q&A.docx")

    cards: list[dict] = []
    for file_name in ["S2四阵营补强卡效果表.xlsx", "S2彼界&奥林匹斯.xlsx"]:
        cards.extend(parse_cards_from_excel(source_root / file_name))

    processed_root = PROJECT_ROOT / "data" / "processed"
    write_json(processed_root / "faq.sample.json", faq_items)
    write_json(processed_root / "cards.sample.json", cards)

    print(f"FAQ sample exported: {processed_root / 'faq.sample.json'}")
    print(f"Card sample exported: {processed_root / 'cards.sample.json'}")


if __name__ == "__main__":
    main()
