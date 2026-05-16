from __future__ import annotations

import json
import re
import shutil
from collections import defaultdict
from pathlib import Path

import cv2
import numpy as np
from rapidocr_onnxruntime import RapidOCR

ROOT = Path(__file__).resolve().parents[2]
PUBLIC_DIR = ROOT / 'h5-app' / 'public'
PUBLIC_FACE_DIR = PUBLIC_DIR / 'cards' / 'faces'
PUBLIC_CARDS_PATH = PUBLIC_DIR / 'data' / 'cards.json'
DIST_CARDS_PATH = ROOT / 'h5-app' / 'dist' / 'data' / 'cards.json'
OCR_OUTPUT_PATH = ROOT / 'asset-pipeline' / 'data' / 'processed' / 'card-face-ocr.json'
RENAME_MAP_PATH = ROOT / 'asset-pipeline' / 'data' / 'processed' / 'card-face-rename-map.json'
ASSET_VERSION_PATH = ROOT / 'h5-app' / 'src' / 'utils' / 'assetVersion.ts'

CODE_RE = re.compile(r'S\d{2}-[A-Z0-9]+', re.IGNORECASE)
DISPLAY_NAME_SUFFIX_RE = re.compile(r'-\d+$')
INVALID_FILENAME_RE = re.compile(r'[\\/:*?"<>|]+')
TRIGGER_WORDS = ('登场时', '阵亡时', '进攻时', '回合', '触发', '持续', '规则上', '主动休整')
STABLE_LEGACY_FOLDERS = {'奥林匹斯', '彼界', '天灾'}


def natural_key(path: Path):
    return [int(part) if part.isdigit() else part for part in re.split(r'(\d+)', path.name)]


def normalize_text(value: str) -> str:
    return value.replace(' ', '').replace('\n', '').replace('·', '').replace('•', '').strip()


def sanitize_filename(value: str) -> str:
    value = INVALID_FILENAME_RE.sub('', value).strip().rstrip('.')
    return value or '未识别卡牌'


def clean_ocr_text(value: str) -> str:
    value = value.strip()
    replacements = {
        '主·城卡': '主城卡',
        '军团卡一': '军团卡',
        'DIVINITYCARD': 'DIVINITY CARD',
        'COSTCARD': 'COST CARD',
        'LEGIONCARD': 'LEGION CARD',
        'TACTICCARD': 'TACTIC CARD',
        'ARTIFACTCARD': 'ARTIFACT CARD',
        'MASTERCARD': 'MASTER CARD',
        'DESTRUCTIONCARD': 'DESTRUCTION CARD',
    }
    for before, after in replacements.items():
        value = value.replace(before, after)
    return value


def find_faces_root() -> Path:
    explicit = ROOT / '牌面'
    if explicit.exists() and explicit.is_dir():
        return explicit
    for path in ROOT.iterdir():
        if not path.is_dir():
            continue
        child_dirs = [child for child in path.iterdir() if child.is_dir()]
        if child_dirs and any(any(file.suffix.lower() == '.png' for file in child.iterdir() if file.is_file()) for child in child_dirs):
            return path
    raise RuntimeError('未找到牌面根目录。')


def read_legacy_cards() -> list[dict]:
    source = DIST_CARDS_PATH if DIST_CARDS_PATH.exists() else PUBLIC_CARDS_PATH
    return json.loads(source.read_text(encoding='utf-8'))


def build_legacy_indexes(cards: list[dict]):
    code_index: dict[str, dict] = {}
    name_index: dict[str, list[dict]] = defaultdict(list)
    for card in cards:
        code = normalize_text(str(card.get('cardNo', ''))).upper()
        if code:
            code_index[code] = card
        name_index[normalize_text(card.get('name', ''))].append(card)
    return code_index, name_index


def display_name_from_file(image_path: Path) -> str:
    stem = DISPLAY_NAME_SUFFIX_RE.sub('', image_path.stem).strip()
    return stem or image_path.stem


def ordered_files(folder: Path) -> list[Path]:
    return sorted([file for file in folder.iterdir() if file.suffix.lower() == '.png'], key=natural_key)


def detect_type(top_lines: list[str]) -> str:
    text = ' '.join(top_lines).upper()
    if 'DIVINITY' in text or '主城' in text:
        return '主城'
    if 'MASTER' in text or '主宰' in text:
        return '主宰'
    if 'LEGION' in text or '军团' in text:
        return '军团'
    if 'TACTIC' in text or '战术' in text:
        return '战术'
    if 'ARTIFACT' in text or '圣物' in text:
        return '圣物'
    if 'AURA' in text or '光环' in text:
        return '光环'
    if 'COST' in text or '士气' in text:
        return '士气卡'
    if 'DESTRUCTION' in text or '天灾' in text:
        return '天灾'
    return '待识别'


def parse_image(image_path: Path, ocr: RapidOCR) -> dict:
    image = cv2.imdecode(np.fromfile(str(image_path), dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise RuntimeError(f'无法读取图片: {image_path}')
    height, width = image.shape[:2]
    top_crop = image[: int(height * 0.18), int(width * 0.05) : int(width * 0.95)]
    bottom_crop = image[int(height * 0.84) : height, : int(width * 0.35)]
    effect_crop = image[int(height * 0.62) : int(height * 0.86), int(width * 0.04) : int(width * 0.96)]

    top_result, _ = ocr(top_crop)
    bottom_result, _ = ocr(bottom_crop)
    effect_result, _ = ocr(effect_crop)

    top_lines = [clean_ocr_text(str(item[1])) for item in top_result or [] if clean_ocr_text(str(item[1]))]
    bottom_lines = [clean_ocr_text(str(item[1])) for item in bottom_result or [] if clean_ocr_text(str(item[1]))]
    effect_lines = [clean_ocr_text(str(item[1])) for item in effect_result or [] if clean_ocr_text(str(item[1]))]

    all_text = ' '.join(top_lines + bottom_lines + effect_lines)
    code_match = CODE_RE.search(all_text)
    code = code_match.group(0).upper() if code_match else ''
    effect_lines = [text for text in effect_lines if '服务号' not in text and 'CYNIC' not in text.upper()]
    return {
        'ocrName': display_name_from_file(image_path),
        'code': code,
        'type': detect_type(top_lines),
        'effectText': '\n'.join(effect_lines).strip(),
        'topLines': top_lines,
        'effectLines': effect_lines,
    }


def infer_series(folder: str, legacy_card: dict | None, code: str) -> str:
    if legacy_card:
        return legacy_card.get('series', folder)
    if folder == '通用':
        return '通用'
    if folder == '天灾' or '-DS' in code:
        return '独立天灾图鉴'
    if folder in {'奥林匹斯', '彼界'}:
        return 'S2彼界&奥林匹斯'
    return folder


def build_card(entry: dict, legacy_card: dict | None) -> dict:
    if legacy_card:
        card = dict(legacy_card)
    else:
        fallback_no = entry['code'] or sanitize_filename(entry['name'])
        card = {
            'id': f"face-{normalize_text(fallback_no).lower().replace('-', '_')}",
            'alias': [],
            'series': entry['series'],
            'cardNo': fallback_no,
            'rarity': '',
            'cost': None,
            'attack': None,
            'health': None,
            'tags': [],
            'faqIds': [],
            'flavorText': '',
        }
    card['name'] = entry['name']
    card['image'] = entry['image']
    card['faction'] = entry['folder']
    card['series'] = card.get('series') or entry['series']
    card['cardNo'] = card.get('cardNo') or entry['code'] or entry['name']
    card['type'] = entry['type']
    card['subType'] = card.get('subType', '')
    card['effectText'] = entry['effectText']
    card['searchText'] = f"{card['name']} {card['faction']} {card['type']} {entry['effectText']}".strip()
    card['verified'] = True
    card['source'] = {'file': f"牌面/{entry['folder']}/{entry['renamed']}", 'code': entry['code']}
    return card


def main() -> None:
    ocr = RapidOCR()
    faces_root = find_faces_root()
    legacy_cards = read_legacy_cards()
    legacy_code_index, legacy_name_index = build_legacy_indexes(legacy_cards)

    entries: list[dict] = []
    raw_entries: list[dict] = []

    for folder in sorted([path for path in faces_root.iterdir() if path.is_dir()], key=lambda value: value.name):
        files = ordered_files(folder)
        print(f'processing {folder.name}: {len(files)}', flush=True)
        for image_path in files:
            parsed = parse_image(image_path, ocr)
            display_name = display_name_from_file(image_path)
            code_key = normalize_text(parsed['code']).upper()
            name_key = normalize_text(display_name)
            legacy_card = legacy_code_index.get(code_key)
            if legacy_card is None:
                candidates = legacy_name_index.get(name_key, [])
                if len(candidates) == 1:
                    legacy_card = candidates[0]

            card_type = parsed['type']
            effect_text = parsed['effectText']
            if legacy_card and folder.name in STABLE_LEGACY_FOLDERS:
                card_type = legacy_card.get('type', card_type)
                effect_text = legacy_card.get('effectText', effect_text)

            entry = {
                'folder': folder.name,
                'original': image_path.name,
                'renamed': image_path.name,
                'image': f'/cards/faces/{folder.name}/{image_path.name}',
                'legacy': legacy_card,
                'series': infer_series(folder.name, legacy_card, parsed['code']),
                'name': display_name,
                'ocrName': parsed['ocrName'],
                'code': parsed['code'],
                'type': card_type,
                'effectText': effect_text,
            }
            entries.append(entry)
            raw_entries.append({
                'folder': folder.name,
                'original': image_path.name,
                'renamed': image_path.name,
                'name': display_name,
                'ocrName': parsed['ocrName'],
                'code': parsed['code'],
                'type': card_type,
                'legacyMatch': legacy_card['name'] if legacy_card else None,
                'topLines': parsed['topLines'],
                'effectLines': parsed['effectLines'],
            })

    if PUBLIC_FACE_DIR.exists():
        shutil.rmtree(PUBLIC_FACE_DIR)
    for entry in entries:
        source = faces_root / entry['folder'] / entry['renamed']
        target_dir = PUBLIC_FACE_DIR / entry['folder']
        target_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target_dir / entry['renamed'])

    cards = [build_card(entry, entry['legacy']) for entry in entries]
    cards.sort(key=lambda card: (card['faction'], card['name'], card['image']))

    PUBLIC_CARDS_PATH.write_text(json.dumps(cards, ensure_ascii=False, indent=2), encoding='utf-8')
    OCR_OUTPUT_PATH.write_text(json.dumps(raw_entries, ensure_ascii=False, indent=2), encoding='utf-8')
    RENAME_MAP_PATH.write_text(json.dumps([{k: v for k, v in item.items() if k not in {'topLines', 'effectLines'}} for item in raw_entries], ensure_ascii=False, indent=2), encoding='utf-8')

    version_text = ASSET_VERSION_PATH.read_text(encoding='utf-8')
    version_text = re.sub(r'"\d{8}-\d{2}"', '"20260503-04"', version_text)
    ASSET_VERSION_PATH.write_text(version_text, encoding='utf-8')

    print(f'done {len(cards)}', flush=True)


if __name__ == '__main__':
    main()
