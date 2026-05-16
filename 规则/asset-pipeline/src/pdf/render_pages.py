from __future__ import annotations

from pathlib import Path

import fitz


def render_pdf_pages(
    pdf_path: Path,
    output_dir: Path,
    zoom: float = 2.0,
    start_page: int = 1,
    end_page: int | None = None,
) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    document = fitz.open(pdf_path)
    last_page = end_page or document.page_count
    generated: list[Path] = []

    for page_number in range(start_page, last_page + 1):
        page = document[page_number - 1]
        pixmap = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        target = output_dir / f"{pdf_path.stem}-page-{page_number:03d}.png"
        pixmap.save(target)
        generated.append(target)

    return generated
