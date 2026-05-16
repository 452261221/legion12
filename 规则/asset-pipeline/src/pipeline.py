from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path


SUPPORTED_EXTENSIONS = {".pdf", ".docx", ".xlsx", ".png", ".jpg", ".jpeg", ".webp"}


@dataclass
class SourceFile:
    name: str
    relative_path: str
    suffix: str
    category: str


def categorize_file(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        return "pdf"
    if suffix == ".docx":
        return "docx"
    if suffix == ".xlsx":
        return "xlsx"
    if suffix in {".png", ".jpg", ".jpeg", ".webp"}:
        return "image"
    return "other"


def collect_source_files(source_root: Path) -> list[SourceFile]:
    files: list[SourceFile] = []
    for path in sorted(source_root.iterdir()):
        if not path.is_file():
            continue
        if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            continue
        files.append(
            SourceFile(
                name=path.name,
                relative_path=path.name,
                suffix=path.suffix.lower(),
                category=categorize_file(path),
            )
        )
    return files


def build_extraction_plan(files: list[SourceFile]) -> list[dict[str, object]]:
    plan: list[dict[str, object]] = []
    for item in files:
        steps: list[str]
        if item.category == "pdf":
            steps = ["render_pages", "detect_card_regions", "extract_text_or_ocr"]
        elif item.category == "docx":
            steps = ["parse_document", "split_questions_and_answers"]
        elif item.category == "xlsx":
            steps = ["read_sheets", "map_columns", "normalize_fields"]
        elif item.category == "image":
            steps = ["manual_reference_only"]
        else:
            steps = []
        plan.append(
            {
                "file": item.relative_path,
                "category": item.category,
                "steps": steps,
                "status": "pending",
            }
        )
    return plan


def write_json(target: Path, payload: object) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def generate_bootstrap_outputs(project_root: Path) -> tuple[Path, Path]:
    source_root = project_root.parent
    files = collect_source_files(source_root)

    manifest = {
        "project": "十二军团查卡器",
        "sourceRoot": str(source_root),
        "counts": {
            "pdf": sum(1 for item in files if item.category == "pdf"),
            "docx": sum(1 for item in files if item.category == "docx"),
            "xlsx": sum(1 for item in files if item.category == "xlsx"),
            "image": sum(1 for item in files if item.category == "image"),
        },
        "files": [asdict(item) for item in files],
    }
    plan = {"items": build_extraction_plan(files)}

    manifest_path = project_root / "data" / "processed" / "manifest.json"
    plan_path = project_root / "data" / "processed" / "extraction-plan.json"
    write_json(manifest_path, manifest)
    write_json(plan_path, plan)
    return manifest_path, plan_path
