from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CARD_FILES = [
    ROOT / "mini-app" / "src" / "static" / "data" / "cards.json",
    ROOT / "h5-app" / "public" / "data" / "cards.json",
]
FAQ_FILES = [
    ROOT / "mini-app" / "src" / "static" / "data" / "faq.json",
    ROOT / "h5-app" / "public" / "data" / "faq.json",
]


def normalize_card_id(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    return normalized or "card"


def build_legacy_key(card: dict) -> str:
    return f"{str(card.get('series', '')).strip()}__{str(card.get('cardNo', '')).strip()}"


def rewrite_cards(path: Path) -> dict[str, str]:
    cards = json.loads(path.read_text(encoding="utf-8"))
    rewritten: list[dict] = []
    legacy_to_id: dict[str, str] = {}
    used_ids: set[str] = set()

    for card in cards:
        card_no = str(card.get("cardNo", "")).strip()
        if not card_no:
            raise RuntimeError(f"{path} 存在缺少 cardNo 的卡牌：{card.get('name', '')}")

        card_id = normalize_card_id(card_no)
        if card_id in used_ids:
            raise RuntimeError(f"{path} 生成了重复 id：{card_id}")
        used_ids.add(card_id)

        legacy_key = build_legacy_key(card)
        if legacy_key:
            legacy_to_id[legacy_key] = card_id

        rewritten.append({**card, "id": card_id})

    path.write_text(json.dumps(rewritten, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return legacy_to_id


def rewrite_faq(path: Path, legacy_to_id: dict[str, str]) -> None:
    faq_items = json.loads(path.read_text(encoding="utf-8"))
    rewritten: list[dict] = []

    for item in faq_items:
        legacy_keys = item.get("relatedCardKeys", [])
        mapped_ids = []
        for key in legacy_keys:
            mapped_id = legacy_to_id.get(str(key).strip())
            if mapped_id:
                mapped_ids.append(mapped_id)
        unique_ids = list(dict.fromkeys(mapped_ids))
        rewritten.append(
            {
                **item,
                "relatedCardIds": unique_ids,
                "relatedCardKeys": unique_ids,
            }
        )

    path.write_text(json.dumps(rewritten, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    legacy_to_id: dict[str, str] = {}
    for card_file in CARD_FILES:
        current_map = rewrite_cards(card_file)
        if not legacy_to_id:
            legacy_to_id = current_map

    for faq_file in FAQ_FILES:
        rewrite_faq(faq_file, legacy_to_id)

    print("Card ids normalized for current data files.")


if __name__ == "__main__":
    main()
