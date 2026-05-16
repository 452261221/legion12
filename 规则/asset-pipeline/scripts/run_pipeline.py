from __future__ import annotations

from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.pipeline import generate_bootstrap_outputs


def main() -> None:
    manifest_path, plan_path = generate_bootstrap_outputs(PROJECT_ROOT)
    print(f"Manifest generated: {manifest_path}")
    print(f"Extraction plan generated: {plan_path}")


if __name__ == "__main__":
    main()
