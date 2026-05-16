from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT_DIR = PROJECT_ROOT / "规则" / "牌面" / "天灾"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "规则" / "牌面" / "天灾_纯背景"
EXPECTED_SIZE = (1080, 773)


def _read_image(path: Path) -> np.ndarray:
	image_bytes = np.fromfile(str(path), dtype=np.uint8)
	image = cv2.imdecode(image_bytes, cv2.IMREAD_COLOR)
	if image is None:
		raise RuntimeError(f"Unable to read image: {path}")
	return image


def _write_image(path: Path, image: np.ndarray) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	suffix = path.suffix.lower() or ".png"
	success, encoded = cv2.imencode(suffix, image)
	if not success:
		raise RuntimeError(f"Unable to encode image: {path}")
	encoded.tofile(str(path))


def _add_rotated_sample_mask(mask: np.ndarray) -> None:
	height, width = mask.shape
	text_layer = np.zeros((height, width), dtype=np.uint8)
	cv2.putText(
		text_layer,
		"SAMPLE",
		(125, 505),
		cv2.FONT_HERSHEY_TRIPLEX,
		5.5,
		255,
		22,
		cv2.LINE_AA,
	)

	rotation = cv2.getRotationMatrix2D((width // 2, height // 2), -12.0, 1.0)
	rotated = cv2.warpAffine(text_layer, rotation, (width, height))
	mask[:] = cv2.max(mask, rotated)

	# Cover the semitransparent watermark shadow around the letters.
	shadow_band = np.array(
		[
			[130, 420],
			[720, 235],
			[905, 355],
			[315, 585],
		],
		dtype=np.int32,
	)
	cv2.fillConvexPoly(mask, shadow_band, 255)


def _build_mask(image: np.ndarray) -> np.ndarray:
	height, width = image.shape[:2]
	if (width, height) != EXPECTED_SIZE:
		raise ValueError(
			f"Unexpected size {(width, height)} for calamity card; expected {EXPECTED_SIZE}"
		)

	mask = np.zeros((height, width), dtype=np.uint8)

	# Top title block.
	cv2.rectangle(mask, (300, 8), (805, 120), 255, -1)

	# Left and right name strips above the rules box.
	cv2.rectangle(mask, (40, 395), (405, 455), 255, -1)
	cv2.rectangle(mask, (705, 395), (1040, 455), 255, -1)

	# Rules box and footer overlays.
	cv2.rectangle(mask, (28, 446), (1045, 718), 255, -1)
	cv2.rectangle(mask, (20, 718), (1065, 772), 255, -1)

	# Bottom-right faction logo.
	cv2.circle(mask, (968, 662), 88, 255, -1)

	_add_rotated_sample_mask(mask)

	# Feather the mask a bit so borders and outlines disappear cleanly.
	mask = cv2.GaussianBlur(mask, (0, 0), 3.0)
	_, mask = cv2.threshold(mask, 16, 255, cv2.THRESH_BINARY)
	mask = cv2.dilate(mask, np.ones((9, 9), dtype=np.uint8), iterations=1)
	return mask


def _inpaint_background(image: np.ndarray, mask: np.ndarray) -> np.ndarray:
	first_pass = cv2.inpaint(image, mask, 5, cv2.INPAINT_TELEA)
	second_mask = cv2.GaussianBlur(mask, (0, 0), 2.0)
	_, second_mask = cv2.threshold(second_mask, 64, 255, cv2.THRESH_BINARY)
	return cv2.inpaint(first_pass, second_mask, 3, cv2.INPAINT_NS)


def process_directory(input_dir: Path, output_dir: Path, debug_dir: Path | None) -> int:
	count = 0
	for image_path in sorted(input_dir.glob("*.png")):
		image = _read_image(image_path)
		mask = _build_mask(image)
		output_image = _inpaint_background(image, mask)
		_write_image(output_dir / image_path.name, output_image)
		if debug_dir is not None:
			_write_image(debug_dir / image_path.name, mask)
		count += 1
	return count


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description="Remove fixed overlay text and watermarks from calamity card art."
	)
	parser.add_argument(
		"--input-dir",
		type=Path,
		default=DEFAULT_INPUT_DIR,
		help="Directory containing the source calamity card images.",
	)
	parser.add_argument(
		"--output-dir",
		type=Path,
		default=DEFAULT_OUTPUT_DIR,
		help="Directory for the cleaned background images.",
	)
	parser.add_argument(
		"--debug-mask-dir",
		type=Path,
		default=None,
		help="Optional directory used to save the generated masks.",
	)
	return parser.parse_args()


def main() -> None:
	args = parse_args()
	if not args.input_dir.exists():
		raise FileNotFoundError(args.input_dir)

	count = process_directory(args.input_dir, args.output_dir, args.debug_mask_dir)
	print(f"processed {count} images into {args.output_dir}")


if __name__ == "__main__":
	main()
