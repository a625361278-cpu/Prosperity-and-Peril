# -*- coding: utf-8 -*-
"""Validate hero half-body portrait mappings from the source project.

This script is intentionally dependency-free: it reads .xlsx files through the
OpenXML zip structure so the audit can run on a clean Windows machine.
"""

from __future__ import annotations

import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


HERO_XLSX = Path(r"E:\work\dajunshi\new\resource\数据表\hero_英雄.xlsx")
LANG_XLSX = Path(r"E:\work\dajunshi\new\resource\数据表\lang_多语言.xlsx")
PORTRAIT_DIR = Path(r"E:\work\dajunshi\new\client\dajunshi\Assets\Arts\04_UI\04_Hero")

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def _col_to_idx(ref: str) -> int:
    letters = "".join(ch for ch in ref if ch.isalpha())
    value = 0
    for ch in letters:
        value = value * 26 + ord(ch.upper()) - 64
    return value - 1


def _load_first_sheet(path: Path) -> list[list[str]]:
    if not path.exists():
        raise FileNotFoundError(f"Excel file not found: {path}")

    with zipfile.ZipFile(path) as archive:
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in root.findall("a:si", NS):
                shared_strings.append("".join(t.text or "" for t in item.findall(".//a:t", NS)))

        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        rel_root = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        rels = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rel_root}

        first_sheet = workbook.find("a:sheets/a:sheet", NS)
        if first_sheet is None:
            raise ValueError(f"Workbook has no sheets: {path}")

        rel_id = first_sheet.attrib[
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        ]
        target = rels[rel_id].lstrip("/")
        if not target.startswith("xl/"):
            target = "xl/" + target

        sheet = ET.fromstring(archive.read(target))
        rows: list[list[str]] = []
        for row in sheet.findall("a:sheetData/a:row", NS):
            values: list[str] = []
            last_idx = -1
            for cell in row.findall("a:c", NS):
                idx = _col_to_idx(cell.attrib.get("r", "A1"))
                while last_idx + 1 < idx:
                    values.append("")
                    last_idx += 1

                cell_type = cell.attrib.get("t")
                raw_value = cell.find("a:v", NS)
                if cell_type == "s" and raw_value is not None:
                    value = shared_strings[int(raw_value.text or "0")]
                elif cell_type == "inlineStr":
                    value = "".join(t.text or "" for t in cell.findall(".//a:t", NS))
                elif raw_value is not None:
                    value = raw_value.text or ""
                else:
                    value = ""

                values.append(value)
                last_idx = idx
            rows.append(values)
        return rows


def _header_index(rows: list[list[str]], row_index: int = 1) -> dict[str, int]:
    if len(rows) <= row_index:
        raise ValueError("Missing machine-readable header row")
    return {name: idx for idx, name in enumerate(rows[row_index]) if name}


def _cell(row: list[str], idx: int) -> str:
    return row[idx] if idx < len(row) else ""


def main() -> int:
    if not PORTRAIT_DIR.exists():
        raise FileNotFoundError(f"Portrait directory not found: {PORTRAIT_DIR}")

    hero_rows = _load_first_sheet(HERO_XLSX)
    lang_rows = _load_first_sheet(LANG_XLSX)
    hero_idx = _header_index(hero_rows)
    lang_idx = _header_index(lang_rows)

    required_hero_fields = ["id", "name", "halfBody"]
    required_lang_fields = ["key", "CN"]
    missing_hero_fields = [field for field in required_hero_fields if field not in hero_idx]
    missing_lang_fields = [field for field in required_lang_fields if field not in lang_idx]
    if missing_hero_fields:
        raise ValueError(f"hero_英雄.xlsx missing fields: {missing_hero_fields}")
    if missing_lang_fields:
        raise ValueError(f"lang_多语言.xlsx missing fields: {missing_lang_fields}")

    lang_map = {}
    for row in lang_rows[3:]:
        key = _cell(row, lang_idx["key"])
        cn = _cell(row, lang_idx["CN"])
        if key:
            lang_map[key] = cn

    portrait_stems = {path.stem for path in PORTRAIT_DIR.glob("*.png")}
    portrait_ids: dict[int, list[str]] = {}
    for path in PORTRAIT_DIR.glob("*.png"):
        match = re.search(r"(\d+)$", path.stem)
        if match:
            portrait_ids.setdefault(int(match.group(1)), []).append(path.name)

    seen_ids: set[int] = set()
    duplicate_ids: list[int] = []
    missing_lang: list[str] = []
    missing_portrait: list[str] = []
    empty_half_body: list[int] = []
    records: list[tuple[int, str, str, str]] = []

    for row in hero_rows[3:]:
        raw_id = _cell(row, hero_idx["id"])
        if not raw_id:
            continue

        hero_id = int(float(raw_id))
        if hero_id in seen_ids:
            duplicate_ids.append(hero_id)
        seen_ids.add(hero_id)

        name_key = _cell(row, hero_idx["name"])
        half_body = _cell(row, hero_idx["halfBody"])
        cn_name = lang_map.get(name_key, "")

        if not cn_name:
            missing_lang.append(f"{hero_id}:{name_key}")
        if not half_body:
            empty_half_body.append(hero_id)
        elif half_body not in portrait_stems:
            missing_portrait.append(f"{hero_id}:{half_body}")
        records.append((hero_id, name_key, cn_name, half_body))

    print("hero_records:", len(records))
    print("lang_matches:", len(records) - len(missing_lang))
    print("portrait_matches:", len(records) - len(missing_portrait) - len(empty_half_body))
    print("png_files:", len(list(PORTRAIT_DIR.glob("*.png"))))
    print("duplicate_portrait_numeric_suffixes:", sum(1 for names in portrait_ids.values() if len(names) > 1))

    for sample_id in [1001, 1002, 1003, 1004, 1007, 2001, 3001, 6001, 99001, 2000501]:
        matches = [record for record in records if record[0] == sample_id]
        if matches:
            hero_id, name_key, cn_name, half_body = matches[0]
            print(f"sample:{hero_id}:{name_key}:{cn_name}:{half_body}")

    if duplicate_ids:
        print("duplicate_hero_ids:", duplicate_ids[:20], file=sys.stderr)
    if missing_lang:
        print("missing_lang:", missing_lang[:20], file=sys.stderr)
    if empty_half_body:
        print("empty_half_body:", empty_half_body[:20], file=sys.stderr)
    if missing_portrait:
        print("missing_portrait:", missing_portrait[:20], file=sys.stderr)

    if duplicate_ids or missing_lang or empty_half_body or missing_portrait:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

