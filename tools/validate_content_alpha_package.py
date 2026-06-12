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
UI_WIREFRAME_SPEC = Path("data/content_alpha/ui_wireframe_spec.json")
UI_THEME_TOKENS = Path("data/content_alpha/ui_theme_tokens.json")
UI_THEME_RESOURCE = Path("themes/content_alpha_formal_theme.tres")
FORMAL_HUD_SCENE = Path("scenes/formal_hud.tscn")
CITY_DETAIL_SCENE = Path("scenes/city_detail_panel.tscn")
APPOINTMENT_SORTIE_SCENE = Path("scenes/appointment_sortie_panel.tscn")
BATTLE_REPORT_SCENE = Path("scenes/battle_report_panel.tscn")
EVENT_LOG_SCENE = Path("scenes/event_log_panel.tscn")
SAVE_LOAD_SCENE = Path("scenes/save_load_panel.tscn")
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
REQUIRED_UI_WIREFRAME_IDS = {
    "strategic_map",
    "city_detail_panel",
    "formal_officer_roster",
    "appointment_sortie_panel",
    "battle_report_panel",
    "event_log_panel",
    "save_load_panel",
    "candidate_officer_workbench",
}
ALLOWED_UI_WIREFRAME_STATUSES = {"wireframe_specified", "content_alpha_tool"}
REQUIRED_UI_THEME_PALETTE_KEYS = {
    "lacquer_dark",
    "lacquer_panel",
    "aged_paper",
    "paper_muted",
    "ink_text",
    "muted_text",
    "accent_gold",
    "accent_red",
    "warning",
    "danger",
    "success",
    "route_line",
    "player_force",
    "enemy_force",
    "neutral_force",
}
REQUIRED_UI_THEME_CONTROLS = {"panel", "button", "warning_badge", "danger_badge", "success_badge"}


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


def validate_ui_wireframe_spec(spec_path: Path) -> dict:
    if not spec_path.exists():
        raise FileNotFoundError(f"ui wireframe spec not found: {spec_path}")
    payload = json.loads(spec_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"ui wireframe spec root must be object: {spec_path}")
    source = payload.get("source")
    if not isinstance(source, dict):
        raise ValueError("ui wireframe spec source must be object")
    boundary_rule = str(source.get("boundary_rule", ""))
    if "not a finished Beta UI" not in boundary_rule:
        raise ValueError("ui wireframe spec boundary must state it is not a finished Beta UI")
    style_reference = str(source.get("style_reference", ""))
    if not style_reference.startswith("res://"):
        raise ValueError(f"ui wireframe style reference must use res://: {style_reference}")
    if not Path(style_reference.removeprefix("res://")).exists():
        raise FileNotFoundError(f"ui wireframe style reference missing: {style_reference}")
    wireframes = payload.get("wireframes")
    if not isinstance(wireframes, list) or not wireframes:
        raise ValueError("ui wireframe spec wireframes must be a non-empty array")

    wireframe_ids: set[str] = set()
    specified_count = 0
    tool_count = 0
    for index, wireframe in enumerate(wireframes):
        if not isinstance(wireframe, dict):
            raise ValueError(f"ui wireframe spec wireframes[{index}] must be object")
        wireframe_id = str(wireframe.get("id", ""))
        if not wireframe_id:
            raise ValueError(f"ui wireframe spec wireframes[{index}] missing id")
        if wireframe_id in wireframe_ids:
            raise ValueError(f"duplicate ui wireframe id: {wireframe_id}")
        wireframe_ids.add(wireframe_id)
        status = str(wireframe.get("implementation_status", ""))
        if status not in ALLOWED_UI_WIREFRAME_STATUSES:
            raise ValueError(f"ui wireframe spec wireframes[{index}] invalid status: {status}")
        if status == "wireframe_specified":
            specified_count += 1
        if status == "content_alpha_tool":
            tool_count += 1
        for field_name in ("layout_regions", "primary_components", "state_bindings", "interactions", "blocked_until"):
            values = wireframe.get(field_name)
            if not isinstance(values, list) or not values:
                raise ValueError(f"ui wireframe spec {wireframe_id} missing {field_name}")
        if len(wireframe["layout_regions"]) < 3:
            raise ValueError(f"ui wireframe spec {wireframe_id} must declare at least three layout regions")
        if len(wireframe["interactions"]) < 2:
            raise ValueError(f"ui wireframe spec {wireframe_id} must declare at least two interactions")
        for binding in wireframe["state_bindings"]:
            binding_text = str(binding)
            if binding_text.startswith("res://") and not Path(binding_text.removeprefix("res://")).exists():
                raise FileNotFoundError(f"ui wireframe spec binding missing: {binding_text}")
    missing = sorted(REQUIRED_UI_WIREFRAME_IDS.difference(wireframe_ids))
    if missing:
        raise ValueError(f"ui wireframe spec missing wireframes: {missing}")
    return {
        "ui_wireframes": len(wireframes),
        "ui_wireframe_specified": specified_count,
        "ui_wireframe_tools": tool_count,
    }


def validate_ui_theme_tokens(tokens_path: Path) -> dict:
    if not tokens_path.exists():
        raise FileNotFoundError(f"ui theme tokens not found: {tokens_path}")
    payload = json.loads(tokens_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"ui theme tokens root must be object: {tokens_path}")
    source = payload.get("source")
    if not isinstance(source, dict):
        raise ValueError("ui theme tokens source must be object")
    boundary_rule = str(source.get("boundary_rule", ""))
    if "not a finished Beta UI" not in boundary_rule:
        raise ValueError("ui theme tokens boundary must state it is not a finished Beta UI")
    style_reference = str(source.get("style_reference", ""))
    if not style_reference.startswith("res://"):
        raise ValueError(f"ui theme style reference must use res://: {style_reference}")
    if not Path(style_reference.removeprefix("res://")).exists():
        raise FileNotFoundError(f"ui theme style reference missing: {style_reference}")

    palette = payload.get("palette")
    if not isinstance(palette, dict):
        raise ValueError("ui theme tokens palette must be object")
    missing_palette = sorted(REQUIRED_UI_THEME_PALETTE_KEYS.difference(palette.keys()))
    if missing_palette:
        raise ValueError(f"ui theme tokens missing palette colors: {missing_palette}")
    for key, value in palette.items():
        text = str(value)
        if len(text) != 7 or not text.startswith("#"):
            raise ValueError(f"ui theme tokens palette.{key} must be #RRGGBB")

    typography = payload.get("typography")
    if not isinstance(typography, dict) or not isinstance(typography.get("sizes"), dict):
        raise ValueError("ui theme tokens typography.sizes must be object")
    for key in ("title", "section", "body", "caption", "number"):
        if int(typography["sizes"].get(key, 0)) <= 0:
            raise ValueError(f"ui theme tokens typography.sizes.{key} must be positive")

    shape = payload.get("shape")
    if not isinstance(shape, dict) or int(shape.get("corner_radius", 0)) <= 0:
        raise ValueError("ui theme tokens shape.corner_radius must be positive")
    controls = payload.get("controls")
    if not isinstance(controls, dict):
        raise ValueError("ui theme tokens controls must be object")
    missing_controls = sorted(REQUIRED_UI_THEME_CONTROLS.difference(controls.keys()))
    if missing_controls:
        raise ValueError(f"ui theme tokens missing controls: {missing_controls}")
    for control_name, control in controls.items():
        if not isinstance(control, dict):
            raise ValueError(f"ui theme tokens controls.{control_name} must be object")
        for color_name in control.values():
            if str(color_name) not in palette:
                raise ValueError(f"ui theme tokens controls.{control_name} references missing color: {color_name}")
    responsive_rules = payload.get("responsive_rules")
    if not isinstance(responsive_rules, list) or len(responsive_rules) < 3:
        raise ValueError("ui theme tokens responsive_rules must contain at least three rules")
    return {
        "ui_theme_palette_colors": len(palette),
        "ui_theme_controls": len(controls),
        "ui_theme_corner_radius": int(shape["corner_radius"]),
    }


def validate_ui_theme_resource(theme_path: Path) -> dict:
    if not theme_path.exists():
        raise FileNotFoundError(f"ui theme resource not found: {theme_path}")
    text = theme_path.read_text(encoding="utf-8")
    required_markers = [
        'resource_name = "ContentAlphaFormalTheme"',
        "Button/styles/normal",
        "Button/styles/hover",
        "Button/styles/pressed",
        "PanelContainer/styles/panel",
        "Label/font_sizes/font_size = 15",
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"ui theme resource missing marker: {marker}")
    return {
        "ui_theme_resource": str(theme_path),
        "ui_theme_resource_markers": len(required_markers),
    }


def validate_formal_hud_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"formal hud scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "TopBar",
        "RightPanel",
        "BottomCommandBar",
        "CommandButtons",
        'script = ExtResource("1_formal_hud")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"formal hud scene missing marker: {marker}")
    return {
        "formal_hud_scene": str(scene_path),
        "formal_hud_markers": len(required_markers),
    }


def validate_city_detail_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"city detail scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "CityHeader",
        "ResourceStats",
        "GovernanceStats",
        "GovernorSummary",
        "OfficerList",
        "ActionBar",
        'script = ExtResource("1_city_detail")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"city detail scene missing marker: {marker}")
    return {
        "city_detail_scene": str(scene_path),
        "city_detail_markers": len(required_markers),
    }


def validate_appointment_sortie_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"appointment sortie scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "AppointmentSortiePanel",
        "OfficerOption",
        "RouteOption",
        "TroopSpin",
        "FoodSpin",
        "AppointButton",
        "SortieButton",
        'script = ExtResource("1_appointment_sortie")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"appointment sortie scene missing marker: {marker}")
    return {
        "appointment_sortie_scene": str(scene_path),
        "appointment_sortie_markers": len(required_markers),
    }


def validate_battle_report_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"battle report scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "BattleReportPanel",
        "ReportOption",
        "ReportTitle",
        "Summary",
        "Casualties",
        "Ownership",
        "JumpButton",
        'script = ExtResource("1_battle_report")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"battle report scene missing marker: {marker}")
    return {
        "battle_report_scene": str(scene_path),
        "battle_report_markers": len(required_markers),
    }


def validate_event_log_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"event log scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "EventLogPanel",
        "CategoryOption",
        "EventList",
        "EventDetail",
        "ValidationMessages",
        "CloseButton",
        'script = ExtResource("1_event_log")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"event log scene missing marker: {marker}")
    return {
        "event_log_scene": str(scene_path),
        "event_log_markers": len(required_markers),
    }


def validate_save_load_scene(scene_path: Path) -> dict:
    if not scene_path.exists():
        raise FileNotFoundError(f"save load scene not found: {scene_path}")
    text = scene_path.read_text(encoding="utf-8")
    required_markers = [
        "SaveLoadPanel",
        "RuntimeSummary",
        "SaveFileSummary",
        "SavePath",
        "SaveButton",
        "LoadButton",
        "CloseButton",
        'script = ExtResource("1_save_load")',
    ]
    for marker in required_markers:
        if marker not in text:
            raise ValueError(f"save load scene missing marker: {marker}")
    return {
        "save_load_scene": str(scene_path),
        "save_load_markers": len(required_markers),
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
    parser.add_argument("--ui-wireframe-spec", type=Path, default=UI_WIREFRAME_SPEC)
    parser.add_argument("--ui-theme-tokens", type=Path, default=UI_THEME_TOKENS)
    parser.add_argument("--ui-theme-resource", type=Path, default=UI_THEME_RESOURCE)
    parser.add_argument("--formal-hud-scene", type=Path, default=FORMAL_HUD_SCENE)
    parser.add_argument("--city-detail-scene", type=Path, default=CITY_DETAIL_SCENE)
    parser.add_argument("--appointment-sortie-scene", type=Path, default=APPOINTMENT_SORTIE_SCENE)
    parser.add_argument("--battle-report-scene", type=Path, default=BATTLE_REPORT_SCENE)
    parser.add_argument("--event-log-scene", type=Path, default=EVENT_LOG_SCENE)
    parser.add_argument("--save-load-scene", type=Path, default=SAVE_LOAD_SCENE)
    parser.add_argument("--pck", type=Path)
    args = parser.parse_args()

    import_summary = validate_imported_resources(args.manifest)
    pool_summary = validate_reusable_portrait_pool(args.portrait_pool, import_summary["target_paths"])
    roster_summary = validate_candidate_officer_roster(args.candidate_roster, import_summary["target_paths"])
    ui_summary = validate_ui_navigation_spec(args.ui_navigation_spec)
    wireframe_summary = validate_ui_wireframe_spec(args.ui_wireframe_spec)
    theme_summary = validate_ui_theme_tokens(args.ui_theme_tokens)
    theme_resource_summary = validate_ui_theme_resource(args.ui_theme_resource)
    formal_hud_summary = validate_formal_hud_scene(args.formal_hud_scene)
    city_detail_summary = validate_city_detail_scene(args.city_detail_scene)
    appointment_sortie_summary = validate_appointment_sortie_scene(args.appointment_sortie_scene)
    battle_report_summary = validate_battle_report_scene(args.battle_report_scene)
    event_log_summary = validate_event_log_scene(args.event_log_scene)
    save_load_summary = validate_save_load_scene(args.save_load_scene)
    print("imported_assets:", import_summary["asset_count"])
    print("hero_bindings:", import_summary["hero_binding_count"])
    print("reusable_portraits:", pool_summary["reusable_portrait_count"])
    print("candidate_officers:", roster_summary["candidate_officer_count"])
    print("ui_navigation_screens:", ui_summary["ui_navigation_screens"])
    print("ui_navigation_available:", ui_summary["ui_navigation_available"])
    print("ui_navigation_planned:", ui_summary["ui_navigation_planned"])
    print("ui_wireframes:", wireframe_summary["ui_wireframes"])
    print("ui_wireframe_specified:", wireframe_summary["ui_wireframe_specified"])
    print("ui_wireframe_tools:", wireframe_summary["ui_wireframe_tools"])
    print("ui_theme_palette_colors:", theme_summary["ui_theme_palette_colors"])
    print("ui_theme_controls:", theme_summary["ui_theme_controls"])
    print("ui_theme_corner_radius:", theme_summary["ui_theme_corner_radius"])
    print("ui_theme_resource:", theme_resource_summary["ui_theme_resource"])
    print("ui_theme_resource_markers:", theme_resource_summary["ui_theme_resource_markers"])
    print("formal_hud_scene:", formal_hud_summary["formal_hud_scene"])
    print("formal_hud_markers:", formal_hud_summary["formal_hud_markers"])
    print("city_detail_scene:", city_detail_summary["city_detail_scene"])
    print("city_detail_markers:", city_detail_summary["city_detail_markers"])
    print("appointment_sortie_scene:", appointment_sortie_summary["appointment_sortie_scene"])
    print("appointment_sortie_markers:", appointment_sortie_summary["appointment_sortie_markers"])
    print("battle_report_scene:", battle_report_summary["battle_report_scene"])
    print("battle_report_markers:", battle_report_summary["battle_report_markers"])
    print("event_log_scene:", event_log_summary["event_log_scene"])
    print("event_log_markers:", event_log_summary["event_log_markers"])
    print("save_load_scene:", save_load_summary["save_load_scene"])
    print("save_load_markers:", save_load_summary["save_load_markers"])
    if args.pck is not None:
        pck_summary = validate_pck(args.pck)
        print("pck_path:", pck_summary["pck_path"])
        print("pck_bytes:", pck_summary["pck_bytes"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
