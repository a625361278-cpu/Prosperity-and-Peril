# -*- coding: utf-8 -*-
"""Validate that Content Alpha imported resources are package-ready."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path


IMPORT_MANIFEST = Path("data/content_alpha/hero_portrait_import_manifest.json")
PORTRAIT_POOL = Path("data/content_alpha/reusable_hero_portrait_pool.json")
DISALLOWED_POOL_FIELDS = {"source_power", "source_up_point", "skill_ids", "secret_ids", "biography_cn"}


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
        "target_paths": target_paths,
    }


def validate_reusable_portrait_pool(pool_path: Path, imported_target_paths: set[str]) -> dict:
    if not pool_path.exists():
        raise FileNotFoundError(f"reusable portrait pool not found: {pool_path}")
    payload = json.loads(pool_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"reusable portrait pool root must be object: {pool_path}")
    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("reusable portrait pool records must be a non-empty array")
    asset_count = payload.get("asset_count")
    if int(asset_count) != len(records):
        raise ValueError(f"reusable portrait pool asset_count mismatch: {asset_count} != {len(records)}")

    half_bodies: set[str] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"reusable portrait pool records[{index}] must be object")
        leaked = sorted(DISALLOWED_POOL_FIELDS.intersection(record.keys()))
        if leaked:
            raise ValueError(f"reusable portrait pool records[{index}] leaked source gameplay fields: {leaked}")
        half_body = str(record.get("half_body", ""))
        if not half_body:
            raise ValueError(f"reusable portrait pool records[{index}] missing half_body")
        if half_body in half_bodies:
            raise ValueError(f"duplicate reusable portrait half_body: {half_body}")
        half_bodies.add(half_body)
        portrait_res_path = str(record.get("portrait_res_path", ""))
        if portrait_res_path not in imported_target_paths:
            raise ValueError(f"reusable portrait pool path is not an imported asset: {portrait_res_path}")
    return {
        "reusable_portrait_count": len(records),
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
    parser.add_argument("--portrait-pool", type=Path, default=PORTRAIT_POOL)
    parser.add_argument("--pck", type=Path)
    args = parser.parse_args()

    import_summary = validate_imported_resources(args.manifest)
    pool_summary = validate_reusable_portrait_pool(args.portrait_pool, import_summary["target_paths"])
    print("imported_assets:", import_summary["asset_count"])
    print("hero_bindings:", import_summary["hero_binding_count"])
    print("reusable_portraits:", pool_summary["reusable_portrait_count"])
    if args.pck is not None:
        pck_summary = validate_pck(args.pck)
        print("pck_path:", pck_summary["pck_path"])
        print("pck_bytes:", pck_summary["pck_bytes"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
