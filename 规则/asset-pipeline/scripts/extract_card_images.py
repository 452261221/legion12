from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.image.detect_cards import crop_card_regions, detect_card_regions
from src.pdf.render_pages import render_pdf_pages


def main() -> None:
    parser = argparse.ArgumentParser(description="Render PDF pages and crop card regions.")
    parser.add_argument("--pdf", required=True, help="PDF file name relative to project root.")
    parser.add_argument("--start-page", type=int, default=1)
    parser.add_argument("--end-page", type=int)
    parser.add_argument("--zoom", type=float, default=2.0)
    args = parser.parse_args()

    source_root = PROJECT_ROOT.parent
    pdf_path = source_root / args.pdf
    rendered_dir = PROJECT_ROOT / "data" / "intermediate" / "rendered" / pdf_path.stem
    crop_dir = PROJECT_ROOT / "data" / "processed" / "card-crops" / pdf_path.stem

    rendered_pages = render_pdf_pages(
        pdf_path=pdf_path,
        output_dir=rendered_dir,
        zoom=args.zoom,
        start_page=args.start_page,
        end_page=args.end_page,
    )

    report: list[dict[str, object]] = []
    for page_image in rendered_pages:
        boxes = detect_card_regions(page_image)
        crops = crop_card_regions(page_image, crop_dir, boxes)
        report.append(
            {
                "pageImage": str(page_image),
                "boxes": boxes,
                "crops": [str(item) for item in crops],
            }
        )

    report_path = PROJECT_ROOT / "data" / "processed" / f"{pdf_path.stem}-crop-report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Crop report generated: {report_path}")
    print(f"Cropped images directory: {crop_dir}")


if __name__ == "__main__":
    main()
