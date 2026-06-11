# -*- coding: utf-8 -*-
"""Export the reusable hero portrait pool for Content Alpha.

This pool is intentionally portrait-only. Source hero names are kept only as
human-readable references for choosing reusable Three Kingdoms portraits; source
gameplay fields such as skills, biography, strategy text, or stats are not part
of this project data.
"""

from __future__ import annotations

import json
from pathlib import Path


DEFAULT_IMPORT_MANIFEST_PATH = Path("data/content_alpha/hero_portrait_import_manifest.json")
DEFAULT_POOL_PATH = Path("data/content_alpha/reusable_hero_portrait_pool.json")
DISALLOWED_SOURCE_FIELDS = ["source_power", "source_up_point", "skill_ids", "secret_ids", "biography_cn"]


def _load_manifest(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"hero portrait import manifest not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"hero portrait import manifest root must be object: {path}")
    if payload.get("schema_version") != 1:
        raise ValueError(f"unsupported hero portrait import manifest schema_version: {payload.get('schema_version')}")
    if not isinstance(payload.get("assets"), list) or not payload["assets"]:
        raise ValueError("hero portrait import manifest assets must be a non-empty array")
    if not isinstance(payload.get("hero_bindings"), list) or not payload["hero_bindings"]:
        raise ValueError("hero portrait import manifest hero_bindings must be a non-empty array")
    return payload


def _validate_asset(asset: dict) -> None:
    required = ["half_body", "target_res_path", "source_path", "file_name", "byte_size", "sha256", "width", "height"]
    missing = [field for field in required if field not in asset or str(asset[field]) == ""]
    if missing:
        raise ValueError(f"portrait asset missing required fields {missing}: {asset}")
    if not Path(str(asset["target_res_path"]).replace("res://", "")).exists():
        raise FileNotFoundError(f"portrait target missing: {asset['target_res_path']}")


def _validate_binding(binding: dict) -> None:
    required = ["hero_id", "name_key", "name_cn", "half_body", "target_res_path"]
    missing = [field for field in required if field not in binding or str(binding[field]) == ""]
    if missing:
        raise ValueError(f"portrait binding missing required fields {missing}: {binding}")
    leaked = [field for field in DISALLOWED_SOURCE_FIELDS if field in binding]
    if leaked:
        raise ValueError(f"portrait binding leaked source gameplay fields {leaked}: {binding}")


def export_pool(manifest_path: Path, pool_path: Path) -> dict:
    manifest = _load_manifest(manifest_path)

    bindings_by_half_body: dict[str, list[dict]] = {}
    for binding in manifest["hero_bindings"]:
        if not isinstance(binding, dict):
            raise ValueError(f"portrait binding must be object: {binding}")
        _validate_binding(binding)
        half_body = str(binding["half_body"])
        bindings_by_half_body.setdefault(half_body, []).append(
            {
                "source_hero_id": int(binding["hero_id"]),
                "source_name_key": str(binding["name_key"]),
                "source_name_cn": str(binding["name_cn"]),
            }
        )

    records: list[dict] = []
    seen_half_bodies: set[str] = set()
    for asset in manifest["assets"]:
        if not isinstance(asset, dict):
            raise ValueError(f"portrait asset must be object: {asset}")
        _validate_asset(asset)
        half_body = str(asset["half_body"])
        if half_body in seen_half_bodies:
            raise ValueError(f"duplicate reusable portrait half_body: {half_body}")
        seen_half_bodies.add(half_body)
        source_bindings = sorted(bindings_by_half_body.get(half_body, []), key=lambda item: item["source_hero_id"])
        if not source_bindings:
            raise ValueError(f"portrait asset has no source hero binding: {half_body}")
        representative = source_bindings[0]
        records.append(
            {
                "half_body": half_body,
                "portrait_res_path": str(asset["target_res_path"]),
                "file_name": str(asset["file_name"]),
                "width": int(asset["width"]),
                "height": int(asset["height"]),
                "byte_size": int(asset["byte_size"]),
                "sha256": str(asset["sha256"]),
                "representative_source_hero_id": representative["source_hero_id"],
                "representative_source_name_cn": representative["source_name_cn"],
                "source_hero_bindings": source_bindings,
            }
        )

    payload = {
        "schema_version": 1,
        "source": {
            "import_manifest_path": "res://" + manifest_path.as_posix(),
            "selection_rule": "one reusable portrait candidate per imported halfBody; source hero identity is only a visual reference",
            "scope_rule": "do not import source gameplay fields such as skills, biography, strategy text, stats, offices, or factions",
            "project_rule": "the project may build a smaller final officer roster from these reusable portraits and may skip officers without portraits",
        },
        "asset_count": len(records),
        "records": sorted(records, key=lambda item: item["half_body"]),
    }
    if payload["asset_count"] != int(manifest.get("asset_count", -1)):
        raise ValueError(
            f"portrait pool asset_count mismatch: pool={payload['asset_count']} manifest={manifest.get('asset_count')}"
        )

    pool_path.parent.mkdir(parents=True, exist_ok=True)
    pool_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    payload = export_pool(DEFAULT_IMPORT_MANIFEST_PATH, DEFAULT_POOL_PATH)
    print("reusable_portrait_assets:", payload["asset_count"])
    print("pool:", DEFAULT_POOL_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
