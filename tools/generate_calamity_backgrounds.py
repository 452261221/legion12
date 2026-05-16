from __future__ import annotations

import argparse
import json
import time
from io import BytesIO
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "规则" / "牌面" / "天灾_重生成背景"
PROMPT_RECORD_PATH = OUTPUT_DIR / "prompts.json"
TARGET_WIDTH = 1080
TARGET_HEIGHT = 773
GENERATION_ENDPOINT = "https://image.pollinations.ai/prompt"

COMMON_STYLE = (
	"detailed dark fantasy environment concept art, cinematic composition, painterly illustration, "
	"high detail, atmospheric lighting, dramatic depth, no text, no typography, no logo, no watermark, "
	"no interface, no border, no card frame"
)

PROMPTS = {
	"傲慢之罪.png": (
		"an arrogant golden tyrant seated on a vast throne above skulls and ruins, oppressive imperial hall, "
		"divine judgment atmosphere, warm gold light, monumental dark fantasy scene"
	),
	"天启默示录.png": (
		"four apocalyptic riders crossing a blood red wasteland under an eclipse, ragged cloaks, ominous horses, "
		"plague war famine death imagery, vast crimson sky, end of the world atmosphere"
	),
	"天地异变.png": (
		"cataclysmic landscape of erupting volcanoes, cracked earth, molten rivers, lightning splitting the sky, "
		"massive geological upheaval, vivid teal and orange contrast"
	),
	"无眠之夜.png": (
		"blood moon above a haunted night forest, shadowy humanoid horrors with glowing red eyes emerging from mist, "
		"insomnia nightmare mood, deep blue and crimson palette"
	),
	"暴怒之罪.png": (
		"a wrathful horned dark knight standing on a burning battlefield, giant glowing sword, torn cape, "
		"embers and smoke, intense red infernal atmosphere"
	),
	"最终天灾 湮灭.png": (
		"abstract cosmic annihilation, purple black void storm, collapsing light, turbulent ethereal clouds, "
		"ominous end-of-all-things atmosphere, minimal surreal background"
	),
	"百鬼夜行.png": (
		"night parade of a hundred demons, giant oni face looming above a festival street, burning paper lanterns, "
		"crowd of yokai and spirits, eerie traditional horror mood"
	),
	"神之天平.png": (
		"a jackal-headed god of judgment in a shadowed temple, holding ancient scales, monumental black robes, "
		"afterlife tribunal, gold and ivory light cutting through darkness"
	),
	"腐秽大地.png": (
		"corrupted wasteland of dead twisted trees, poisoned marsh, decaying earth, desolate twilight sky, "
		"rotting life and blight spreading across the land"
	),
	"虚构的圣杯.png": (
		"a false holy grail on a dark stone altar in an abyssal temple, eldritch idol looming behind, "
		"cold shafts of light, forbidden relic, ominous occult atmosphere"
	),
	"诸神黄昏.png": (
		"ragnarok, gods and monsters clashing in a vast apocalyptic battlefield, lightning storms, fire and ash, "
		"winged figures falling from the sky, world-ending mythic war"
	),
	"迷雾绝境.png": (
		"bleached fog-choked forest, thin long-limbed silhouette emerging through dense mist, silent horror landscape, "
		"desaturated grey tones, suffocating atmosphere"
	),
	"雷霆天怒.png": (
		"colossal lightning strike tearing through storm clouds above ruined pillars and shattered architecture, "
		"electric magenta and cyan sky, divine wrath unleashed"
	),
	"风暴乱象.png": (
		"abstract storm maelstrom of swirling red, indigo, black and white clouds, chaotic sky currents, "
		"violent atmospheric turbulence, painterly high-energy composition"
	),
	"魔龙降世.png": (
		"a gigantic black infernal dragon descending over a burning wasteland, wings spread wide, lava and fire pillars, "
		"catastrophic arrival, dark fantasy apocalypse"
	),
	"黯陨晨星.png": (
		"a fallen morning star, dark winged angel with radiant halo, blazing dawn behind, collision of holy light and shadow, "
		"epic celestial tragedy"
	),
}


def _final_prompt(subject_prompt: str) -> str:
	return f"{subject_prompt}, {COMMON_STYLE}"


def _fetch_image(prompt: str) -> Image.Image:
	url = (
		f"{GENERATION_ENDPOINT}/{quote(prompt)}"
		f"?width={TARGET_WIDTH}&height={TARGET_HEIGHT}&nologo=true"
	)
	request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
	with urlopen(request, timeout=180) as response:
		data = response.read()
	image = Image.open(BytesIO(data))
	return image.convert("RGB")


def _resize_and_crop(image: Image.Image) -> Image.Image:
	scale = max(TARGET_WIDTH / image.width, TARGET_HEIGHT / image.height)
	resized = image.resize(
		(int(round(image.width * scale)), int(round(image.height * scale))),
		Image.Resampling.LANCZOS,
	)
	left = max(0, (resized.width - TARGET_WIDTH) // 2)
	top = max(0, (resized.height - TARGET_HEIGHT) // 2)
	return resized.crop((left, top, left + TARGET_WIDTH, top + TARGET_HEIGHT))


def _parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate regenerated calamity background art.")
	parser.add_argument(
		"file_names",
		nargs="*",
		help="Optional subset of output file names to generate.",
	)
	return parser.parse_args()


def main() -> None:
	args = _parse_args()
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	prompt_records: dict[str, dict[str, str]] = {}
	if PROMPT_RECORD_PATH.exists():
		prompt_records = json.loads(PROMPT_RECORD_PATH.read_text(encoding="utf-8"))
	selected_names = set(args.file_names)
	selected_prompts = (
		{key: value for key, value in PROMPTS.items() if key in selected_names}
		if selected_names
		else PROMPTS
	)

	for file_name, subject_prompt in selected_prompts.items():
		final_prompt = _final_prompt(subject_prompt)
		last_error: Exception | None = None
		for attempt in range(3):
			try:
				image = _fetch_image(final_prompt)
				image = _resize_and_crop(image)
				output_path = OUTPUT_DIR / file_name
				image.save(output_path, format="PNG", optimize=True)
				prompt_records[file_name] = {
					"subject_prompt": subject_prompt,
					"final_prompt": final_prompt,
					"image_size": f"{TARGET_WIDTH}x{TARGET_HEIGHT}",
				}
				print(f"generated {file_name}")
				time.sleep(1.0)
				break
			except Exception as exc:  # pragma: no cover - best effort network retries
				last_error = exc
				print(f"retry {attempt + 1} for {file_name}: {exc}")
				time.sleep(2.0)
		else:
			raise RuntimeError(f"Failed to generate {file_name}") from last_error

	PROMPT_RECORD_PATH.write_text(
		json.dumps(prompt_records, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8",
	)
	print(f"generated {len(prompt_records)} images into {OUTPUT_DIR}")


if __name__ == "__main__":
	main()
