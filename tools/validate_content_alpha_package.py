# -*- coding: utf-8 -*-
"""Validate that Content Alpha imported resources are package-ready."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path


IMPORT_MANIFEST = Path("data/content_alpha/hero_portrait_import_manifest.json")
PORTRAIT_POOL = Path("data/content_alpha/reusable_hero_portrait_pool.json")
CANDIDATE_ROSTER = Path("data/content_alpha/candidate_officer_roster.json")
UI_NAVIGATION_SPEC = Path("data/content_alpha/ui_navigation_spec.json")
DISALLOWED_POOL_FIELDS = {"source_power", "source_up_point", "skill_ids", "secret_ids", "biography_cn"}
DISALLOWED_ROSTER_FIELDS = DISALLOWED_POOL_FIELDS | {
    "force_id",
    "faction_id",
    "office",
    "stats",
    "leadership",
    "war",
    "intelligence",
    "politics",
    "charm",
}
REQUIRED_UI_SCREEN_IDS = {
    "strategic_map",
    "city_detail_panel",
    "candidate_officer_workbench",
    "formal_officer_roster",
    "appointment_sortie_panel",
    "battle_report_panel",
    "event_log_panel",
    "save_load_panel",
}
ALLOWED_UI_STATUSES = {"debug_available", "content_alpha_available", "planned"}


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


def validate_candidate_officer_roster(roster_path: Path, imported_target_paths: set[str]) -> dict:
    if not roster_path.exists():
        raise FileNotFoundError(f"candidate officer roster not found: {roster_path}")
    payload = json.loads(roster_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"candidate officer roster root must be object: {roster_path}")
    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("candidate officer roster records must be a non-empty array")
    candidate_count = payload.get("candidate_count")
    if int(candidate_count) != len(records):
        raise ValueError(f"candidate officer roster candidate_count mismatch: {candidate_count} != {len(records)}")

    candidate_ids: set[str] = set()
    half_bodies: set[str] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"candidate officer roster records[{index}] must be object")
        leaked = sorted(DISALLOWED_ROSTER_FIELDS.intersection(record.keys()))
        if leaked:
            raise ValueError(f"candidate officer roster records[{index}] leaked gameplay fields: {leaked}")
        candidate_id = str(record.get("candidate_officer_id", ""))
        if not candidate_id.startswith("CANDIDATE_"):
            raise ValueError(f"candidate officer roster records[{index}] invalid candidate_officer_id: {candidate_id}")
        if candidate_id in candidate_ids:
            raise ValueError(f"duplicate candidate officer id: {candidate_id}")
        candidate_ids.add(candidate_id)
        half_body = str(record.get("half_body", ""))
        if half_body in half_bodies:
            raise ValueError(f"duplicate candidate officer half_body: {half_body}")
        half_bodies.add(half_body)
        portrait_res_path = str(record.get("portrait_res_path", ""))
        if portrait_res_path not in imported_target_paths:
            raise ValueError(f"candidate officer roster path is not an imported asset: {portrait_res_path}")
    return {
        "candidate_officer_count": len(records),
    }


def validate_ui_navigation_spec(spec_path: Path) -> dict:
    if not spec_path.exists():
        raise FileNotFoundError(f"ui navigation spec not found: {spec_path}")
    payload = json.loads(spec_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"ui navigation spec root must be object: {spec_path}")
    source = payload.get("source")
    if not isinstance(source, dict):
        raise ValueError("ui navigation spec source must be object")
    boundary_rule = str(source.get("boundary_rule", ""))
    if "not a finished Beta UI" not in boundary_rule:
        raise ValueError("ui navigation spec boundary must state it is not a finished Beta UI")
    screens = payload.get("screens")
    if not isinstance(screens, list) or not screens:
        raise ValueError("ui navigation spec screens must be a non-empty array")

    screen_ids: set[str] = set()
    planned_count = 0
    available_count = 0
    for index, screen in enumerate(screens):
        if not isinstance(screen, dict):
            raise ValueError(f"ui navigation spec screens[{index}] must be object")
        screen_id = str(screen.get("id", ""))
        if not screen_id:
            raise ValueError(f"ui navigation spec screens[{index}] missing id")
        if screen_id in screen_ids:
            raise ValueError(f"duplicate ui navigation screen id: {screen_id}")
        screen_ids.add(screen_id)
        status = str(screen.get("implementation_status", ""))
        if status not in ALLOWED_UI_STATUSES:
            raise ValueError(f"ui navigation spec screens[{index}] invalid status: {status}")
        if status == "planned":
            planned_count += 1
            blockers = screen.get("blocked_until")
            if not isinstance(blockers, list) or not blockers:
                raise ValueError(f"ui navigation spec planned screen missing blockers: {screen_id}")
        else:
            available_count += 1
        data_sources = screen.get("primary_data_sources")
        if not isinstance(data_sources, list) or not data_sources:
            raise ValueError(f"ui navigation spec screen missing data sources: {screen_id}")
        for source_path in data_sources:
            source_text = str(source_path)
            if source_text.startswith("res://") and not Path(source_text.removeprefix("res://")).exists():
                raise FileNotFoundError(f"ui navigation spec data source missing: {source_text}")
    missing = sorted(REQUIRED_UI_SCREEN_IDS.difference(screen_ids))
    if missing:
        raise ValueError(f"ui navigation spec missing screens: {missing}")
    return {
        "ui_navigation_screens": len(screens),
        "ui_navigation_available": available_count,
        "ui_navigation_planned": planned_count,
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
    parser.add_argument("--candidate-roster", type=Path, default=CANDIDATE_ROSTER)
    parser.add_argument("--ui-navigation-spec", type=Path, default=UI_NAVIGATION_SPEC)
    parser.add_argument("--pck", type=Path)
    args = parser.parse_args()

    import_summary = validate_imported_resources(args.manifest)
    pool_summary = validate_reusable_portrait_pool(args.portrait_pool, import_summary["target_paths"])
    roster_summary = validate_candidate_officer_roster(args.candidate_roster, import_summary["target_paths"])
    ui_summary = validate_ui_navigation_spec(args.ui_navigation_spec)
    print("imported_assets:", import_summary["asset_count"])
    print("hero_bindings:", import_summary["hero_binding_count"])
    print("reusable_portraits:", pool_summary["reusable_portrait_count"])
    print("candidate_officers:", roster_summary["candidate_officer_count"])
    print("ui_navigation_screens:", ui_summary["ui_navigation_screens"])
    print("ui_navigation_available:", ui_summary["ui_navigation_available"])
    print("ui_navigation_planned:", ui_summary["ui_navigation_planned"])
    if args.pck is not None:
        pck_summary = validate_pck(args.pck)
        print("pck_path:", pck_summary["pck_path"])
        print("pck_bytes:", pck_summary["pck_bytes"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
