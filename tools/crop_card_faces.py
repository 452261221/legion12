from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CARD_DATA_DIR = PROJECT_ROOT / "data" / "cards"
EXTRA_CARD_DATA_FILES = [
	PROJECT_ROOT / "data" / "raw_rule_cards" / "starter_duel_master_cards.json",
	PROJECT_ROOT / "data" / "raw_rule_cards" / "tianting_master_cards.json",
]
OUTPUT_DIR = PROJECT_ROOT / "client" / "assets" / "cards"
MANIFEST_PATH = OUTPUT_DIR / "card_faces_manifest.json"

EXPECTED_CARD_RATIO = 1353.0 / 969.0
WHITE_THRESHOLD = 245
MIN_COMPONENT_AREA = 100_000
MAX_OUTPUT_WIDTH = 720
JPEG_QUALITY = 88


def _resolve_res_path(path: str) -> Path:
	if path.startswith("res://"):
		return PROJECT_ROOT / path.removeprefix("res://")
	return PROJECT_ROOT / path


def _find_card_bounds(image_path: Path) -> tuple[int, int, int, int]:
	image_bytes = np.fromfile(str(image_path), dtype=np.uint8)
	image = cv2.imdecode(image_bytes, cv2.IMREAD_COLOR)
	if image is None:
		raise RuntimeError(f"Unable to read image: {image_path}")

	rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
	mask = np.any(rgb < WHITE_THRESHOLD, axis=2).astype("uint8")
	count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(mask, 8)

	components: list[tuple[int, int, int, int, int]] = []
	for index in range(1, count):
		x, y, width, height, area = stats[index]
		if int(area) >= MIN_COMPONENT_AREA:
			components.append((int(area), int(x), int(y), int(width), int(height)))

	if not components:
		for index in range(1, count):
			x, y, width, height, area = stats[index]
			components.append((int(area), int(x), int(y), int(width), int(height)))

	if not components:
		raise RuntimeError(f"No card-like component found: {image_path}")

	_area, x, y, width, height = max(components, key=lambda item: item[0])

	expected_height = int(round(width * EXPECTED_CARD_RATIO))
	if height < expected_height - 10:
		bottom = y + height
		height = expected_height
		y = bottom - height

	y = max(0, y)
	x = max(0, x)
	height = min(height, image.shape[0] - y)
	width = min(width, image.shape[1] - x)
	return x, y, width, height


def _iter_card_definitions() -> list[dict]:
	cards: list[dict] = []
	data_paths = list(sorted(CARD_DATA_DIR.glob("*.json"))) + EXTRA_CARD_DATA_FILES
	for data_path in data_paths:
		if not data_path.exists():
			continue
		data = json.loads(data_path.read_text(encoding="utf-8"))
		if not isinstance(data, list):
			continue
		for card in data:
			if isinstance(card, dict) and card.get("id") and card.get("image_path"):
				cards.append(card)
	return cards


def main() -> None:
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	manifest: dict[str, dict] = {}

	for card in _iter_card_definitions():
		card_id = str(card["id"])
		source_path = _resolve_res_path(str(card["image_path"]))
		if not source_path.exists():
			raise FileNotFoundError(source_path)

		x, y, width, height = _find_card_bounds(source_path)
		with Image.open(source_path) as source:
			cropped = source.crop((x, y, x + width, y + height)).convert("RGB")
			if cropped.width > MAX_OUTPUT_WIDTH:
				scaled_height = int(round(cropped.height * (MAX_OUTPUT_WIDTH / float(cropped.width))))
				cropped = cropped.resize((MAX_OUTPUT_WIDTH, scaled_height), Image.Resampling.LANCZOS)
			output_path = OUTPUT_DIR / f"{card_id}.jpg"
			cropped.save(
				output_path,
				format="JPEG",
				quality=JPEG_QUALITY,
				subsampling="4:2:0",
				optimize=True,
				progressive=True,
			)

		manifest[card_id] = {
			"face_path": f"res://client/assets/cards/{card_id}.jpg",
			"source_path": str(card["image_path"]),
			"crop": {"x": x, "y": y, "width": width, "height": height},
			"output_width": cropped.width,
			"output_height": cropped.height,
			"format": "jpg",
		}

	MANIFEST_PATH.write_text(
		json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8",
	)
	print(f"cropped {len(manifest)} card faces into {OUTPUT_DIR}")


if __name__ == "__main__":
	main()
