from __future__ import annotations

import shutil
from pathlib import Path


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    processed_root = project_root / "data" / "processed"
    h5_data_root = project_root.parent / "h5-app" / "public" / "data"
    h5_data_root.mkdir(parents=True, exist_ok=True)

    mapping = {
        processed_root / "cards.sample.json": h5_data_root / "cards.json",
        processed_root / "faq.sample.json": h5_data_root / "faq.json",
        processed_root / "manifest.json": h5_data_root / "manifest.json",
    }

    for source, target in mapping.items():
      if source.exists():
        shutil.copyfile(source, target)
        print(f"Synced: {source.name} -> {target}")


if __name__ == "__main__":
    main()
