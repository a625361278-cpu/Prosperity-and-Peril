# -*- coding: utf-8 -*-
"""Import audited hero portrait PNGs into the Godot project.

The audit index remains the authority for hero -> halfBody mapping. This tool
copies each unique halfBody PNG once and writes an import manifest that can be
validated by Godot tests before UI code uses the assets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path


DEFAULT_INDEX_PATH = Path("data/content_alpha/hero_portrait_index.json")
DEFAULT_TARGET_DIR = Path("assets/content_alpha/hero_portraits")
DEFAULT_MANIFEST_PATH = Path("data/content_alpha/hero_portrait_import_manifest.json")


def _load_index(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"hero portrait index not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"hero portrait index root must be object: {path}")
    if payload.get("schema_version") != 1:
        raise ValueError(f"unsupported hero portrait index schema_version: {payload.get('schema_version')}")
    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("hero portrait index records must be a non-empty array")
    return payload


def _png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a valid PNG header: {path}")
    width, height = struct.unpack(">II", header[16:24])
    return int(width), int(height)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _res_path(path: Path) -> str:
    return "res://" + path.as_posix()


def _validate_record(record: dict) -> None:
    required = ["id", "name_cn", "name_key", "half_body", "portrait_file", "portrait_source_path"]
    missing = [field for field in required if field not in record or str(record[field]) == ""]
    if missing:
        raise ValueError(f"hero portrait record missing required fields {missing}: {record}")


def import_portraits(index_path: Path, target_dir: Path, manifest_path: Path, copy_files: bool) -> dict:
    index = _load_index(index_path)
    target_dir.mkdir(parents=True, exist_ok=True)

    unique_assets: dict[str, dict] = {}
    hero_bindings: list[dict] = []
    for record in index["records"]:
        if not isinstance(record, dict):
            raise ValueError(f"hero portrait record must be object: {record}")
        _validate_record(record)
        hero_id = int(record["id"])
        half_body = str(record["half_body"])
        source_path = Path(str(record["portrait_source_path"]))
        if not source_path.exists():
            raise FileNotFoundError(f"hero portrait source missing: {source_path}")

        target_path = target_dir / source_path.name
        if half_body not in unique_assets:
            if copy_files:
                shutil.copy2(source_path, target_path)
            if not target_path.exists():
                raise FileNotFoundError(f"hero portrait target missing after import: {target_path}")
            width, height = _png_size(target_path)
            unique_assets[half_body] = {
                "half_body": half_body,
                "source_path": str(source_path),
                "target_res_path": _res_path(target_path),
                "file_name": source_path.name,
                "byte_size": target_path.stat().st_size,
                "sha256": _sha256(target_path),
                "width": width,
                "height": height,
            }

        hero_bindings.append(
            {
                "hero_id": hero_id,
                "name_key": str(record["name_key"]),
                "name_cn": str(record["name_cn"]),
                "half_body": half_body,
                "target_res_path": unique_assets[half_body]["target_res_path"],
            }
        )

    manifest = {
        "schema_version": 1,
        "resource_pack_id": "candidate_hero_portraits",
        "source_index_path": _res_path(index_path),
        "target_root": _res_path(target_dir),
        "mapping_rule": "hero.halfBody is authoritative; imported PNGs are unique by halfBody and heroes bind through the index",
        "asset_count": len(unique_assets),
        "hero_binding_count": len(hero_bindings),
        "assets": sorted(unique_assets.values(), key=lambda item: item["half_body"]),
        "hero_bindings": sorted(hero_bindings, key=lambda item: item["hero_id"]),
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Import audited hero portrait PNGs into the Godot project.")
    parser.add_argument("--index", type=Path, default=DEFAULT_INDEX_PATH)
    parser.add_argument("--target-dir", type=Path, default=DEFAULT_TARGET_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--no-copy", action="store_true", help="Only validate existing target files and rewrite manifest.")
    args = parser.parse_args()

    manifest = import_portraits(args.index, args.target_dir, args.manifest, not args.no_copy)
    print("imported_unique_assets:", manifest["asset_count"])
    print("hero_bindings:", manifest["hero_binding_count"])
    print("target_root:", manifest["target_root"])
    print("manifest:", args.manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
