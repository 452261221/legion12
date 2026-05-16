from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np


Box = tuple[int, int, int, int]


def detect_card_regions(
    image_path: Path,
    white_threshold: int = 245,
    min_area_ratio: float = 0.02,
    padding: int = 18,
) -> list[Box]:
    image = _read_image(image_path)
    if image is None:
        raise FileNotFoundError(f"Unable to read image: {image_path}")

    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, white_threshold, 255, cv2.THRESH_BINARY_INV)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    min_area = width * height * min_area_ratio
    boxes: list[Box] = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        area = w * h
        if area < min_area:
            continue
        if w < width * 0.1 or h < height * 0.1:
            continue
        x1 = max(0, x - padding)
        y1 = max(0, y - padding)
        x2 = min(width, x + w + padding)
        y2 = min(height, y + h + padding)
        boxes.append((x1, y1, x2, y2))

    boxes.sort(key=lambda item: (item[1], item[0]))
    return _deduplicate_boxes(boxes)


def _deduplicate_boxes(boxes: list[Box]) -> list[Box]:
    result: list[Box] = []
    for candidate in boxes:
        if any(_intersection_over_min(candidate, existing) > 0.9 for existing in result):
            continue
        result.append(candidate)
    return result


def _intersection_over_min(left: Box, right: Box) -> float:
    x1 = max(left[0], right[0])
    y1 = max(left[1], right[1])
    x2 = min(left[2], right[2])
    y2 = min(left[3], right[3])
    if x2 <= x1 or y2 <= y1:
        return 0.0
    intersection = (x2 - x1) * (y2 - y1)
    left_area = (left[2] - left[0]) * (left[3] - left[1])
    right_area = (right[2] - right[0]) * (right[3] - right[1])
    return intersection / min(left_area, right_area)


def crop_card_regions(image_path: Path, output_dir: Path, boxes: list[Box]) -> list[Path]:
    image = _read_image(image_path)
    if image is None:
        raise FileNotFoundError(f"Unable to read image: {image_path}")

    output_dir.mkdir(parents=True, exist_ok=True)
    generated: list[Path] = []
    for index, (x1, y1, x2, y2) in enumerate(boxes, start=1):
        crop = image[y1:y2, x1:x2]
        target = output_dir / f"{image_path.stem}-card-{index:02d}.png"
        encoded, buffer = cv2.imencode(".png", crop)
        if not encoded:
            raise RuntimeError(f"Unable to encode crop: {target}")
        target.write_bytes(buffer.tobytes())
        generated.append(target)
    return generated


def _read_image(image_path: Path):
    buffer = np.fromfile(str(image_path), dtype=np.uint8)
    if buffer.size == 0:
        return None
    return cv2.imdecode(buffer, cv2.IMREAD_COLOR)
