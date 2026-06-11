# -*- coding: utf-8 -*-
"""Export a portrait-backed candidate officer roster for Content Alpha.

This roster is a selection aid, not the final officer database. It contains
identity and portrait binding only; gameplay fields such as stats, skills,
factions, offices, biography, or strategy text are intentionally forbidden.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


DEFAULT_POOL_PATH = Path("data/content_alpha/reusable_hero_portrait_pool.json")
DEFAULT_ROSTER_PATH = Path("data/content_alpha/candidate_officer_roster.json")
DISALLOWED_GAMEPLAY_FIELDS = {
    "force_id",
    "faction_id",
    "office",
    "stats",
    "leadership",
    "war",
    "intelligence",
    "politics",
    "charm",
    "skill_ids",
    "secret_ids",
    "biography_cn",
}


def _load_pool(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"reusable portrait pool not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"reusable portrait pool root must be object: {path}")
    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("reusable portrait pool records must be a non-empty array")
    return payload


def _candidate_id(half_body: str) -> str:
    normalized = re.sub(r"[^0-9A-Za-z_]+", "_", half_body).upper()
    return f"CANDIDATE_{normalized}"


def _validate_pool_record(record: dict, index: int) -> None:
    required = [
        "half_body",
        "portrait_res_path",
        "representative_source_hero_id",
        "representative_source_name_cn",
        "source_hero_bindings",
    ]
    missing = [field for field in required if field not in record or str(record[field]) == ""]
    if missing:
        raise ValueError(f"portrait pool records[{index}] missing required fields {missing}")
    leaked = sorted(DISALLOWED_GAMEPLAY_FIELDS.intersection(record.keys()))
    if leaked:
        raise ValueError(f"portrait pool records[{index}] leaked gameplay fields: {leaked}")
    if not isinstance(record["source_hero_bindings"], list) or not record["source_hero_bindings"]:
        raise ValueError(f"portrait pool records[{index}] source_hero_bindings must be non-empty")


def export_roster(pool_path: Path, roster_path: Path) -> dict:
    pool = _load_pool(pool_path)
    records: list[dict] = []
    candidate_ids: set[str] = set()
    half_bodies: set[str] = set()
    for index, record in enumerate(pool["records"]):
        if not isinstance(record, dict):
            raise ValueError(f"portrait pool records[{index}] must be object")
        _validate_pool_record(record, index)
        half_body = str(record["half_body"])
        candidate_id = _candidate_id(half_body)
        if candidate_id in candidate_ids:
            raise ValueError(f"duplicate candidate officer id: {candidate_id}")
        if half_body in half_bodies:
            raise ValueError(f"duplicate candidate officer half_body: {half_body}")
        candidate_ids.add(candidate_id)
        half_bodies.add(half_body)
        records.append(
            {
                "candidate_officer_id": candidate_id,
                "display_name_cn": str(record["representative_source_name_cn"]),
                "selection_status": "candidate",
                "half_body": half_body,
                "portrait_res_path": str(record["portrait_res_path"]),
                "source_reference": {
                    "representative_source_hero_id": int(record["representative_source_hero_id"]),
                    "source_hero_bindings": record["source_hero_bindings"],
                },
            }
        )

    payload = {
        "schema_version": 1,
        "source": {
            "portrait_pool_path": "res://" + pool_path.as_posix(),
            "roster_rule": "candidate roster is identity and portrait binding only; it is not the final officer database",
            "gameplay_field_rule": "do not add stats, skills, factions, offices, biography, or strategy text to this roster",
            "selection_rule": "final officer roster may select a smaller set from portrait-backed candidates",
        },
        "candidate_count": len(records),
        "records": sorted(records, key=lambda item: item["candidate_officer_id"]),
    }
    roster_path.parent.mkdir(parents=True, exist_ok=True)
    roster_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    payload = export_roster(DEFAULT_POOL_PATH, DEFAULT_ROSTER_PATH)
    print("candidate_officers:", payload["candidate_count"])
    print("roster:", DEFAULT_ROSTER_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
