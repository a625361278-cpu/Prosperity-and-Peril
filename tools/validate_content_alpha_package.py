# -*- coding: utf-8 -*-
"""Validate that Content Alpha imported resources are package-ready."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path


IMPORT_MANIFEST = Path("data/content_alpha/hero_portrait_import_manifest.json")


def _load_manifest(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"import manifest not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"import manifest root must be object: {path}")
    return payload


def _res_to_project_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"package resource path must use res://: {res_path}")
    return Path(res_path.removeprefix("res://"))


def validate_imported_resources(manifest_path: Path) -> dict:
    manifest = _load_manifest(manifest_path)
    assets = manifest.get("assets")
    bindings = manifest.get("hero_bindings")
    if not isinstance(assets, list) or not assets:
        raise ValueError("import manifest assets must be a non-empty array")
    if not isinstance(bindings, list) or not bindings:
        raise ValueError("import manifest hero_bindings must be a non-empty array")

    target_paths: set[str] = set()
    for index, asset in enumerate(assets):
        if not isinstance(asset, dict):
            raise ValueError(f"assets[{index}] must be object")
        target_path = _res_to_project_path(str(asset.get("target_res_path", "")))
        if not target_path.exists():
            raise FileNotFoundError(f"imported target missing: {target_path}")
        if target_path.suffix.lower() != ".png":
            raise ValueError(f"imported target must be png: {target_path}")
        target_paths.add("res://" + target_path.as_posix())

    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            raise ValueError(f"hero_bindings[{index}] must be object")
        target_res_path = str(binding.get("target_res_path", ""))
        if target_res_path not in target_paths:
            raise ValueError(f"hero binding target is not imported asset: {target_res_path}")
    return {
        "asset_count": len(assets),
        "hero_binding_count": len(bindings),
    }


def validate_pck(pck_path: Path) -> dict:
    if not pck_path.exists():
        raise FileNotFoundError(f"exported pck not found: {pck_path}")
    if pck_path.stat().st_size <= 0:
        raise ValueError(f"exported pck is empty: {pck_path}")
    return {
        "pck_path": str(pck_path),
        "pck_bytes": pck_path.stat().st_size,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Content Alpha package readiness.")
    parser.add_argument("--manifest", type=Path, default=IMPORT_MANIFEST)
    parser.add_argument("--pck", type=Path)
    args = parser.parse_args()

    import_summary = validate_imported_resources(args.manifest)
    print("imported_assets:", import_summary["asset_count"])
    print("hero_bindings:", import_summary["hero_binding_count"])
    if args.pck is not None:
        pck_summary = validate_pck(args.pck)
        print("pck_path:", pck_summary["pck_path"])
        print("pck_bytes:", pck_summary["pck_bytes"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
