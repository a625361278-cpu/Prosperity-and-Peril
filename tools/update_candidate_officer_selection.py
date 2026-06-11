# -*- coding: utf-8 -*-
"""Update candidate officer selection statuses with validation.

The tool only changes `selection_status`. It refuses unknown candidate IDs,
invalid statuses, missing portrait paths, and gameplay fields that do not belong
in the candidate roster.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


DEFAULT_ROSTER_PATH = Path("data/content_alpha/candidate_officer_roster.json")
ALLOWED_STATUS = {"candidate", "selected", "rejected"}
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


def _load_roster(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"candidate officer roster not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"candidate officer roster root must be object: {path}")
    return payload


def _res_to_project_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"candidate portrait path must use res://: {res_path}")
    return Path(res_path.removeprefix("res://"))


def _parse_assignment(raw: str) -> tuple[str, str]:
    if "=" not in raw:
        raise ValueError(f"assignment must be CANDIDATE_ID=status: {raw}")
    candidate_id, status = raw.split("=", 1)
    candidate_id = candidate_id.strip()
    status = status.strip()
    if not candidate_id:
        raise ValueError(f"assignment missing candidate id: {raw}")
    if status not in ALLOWED_STATUS:
        raise ValueError(f"selection status invalid {status}; allowed: {sorted(ALLOWED_STATUS)}")
    return candidate_id, status


def _validate_roster(payload: dict) -> list[dict]:
    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("candidate officer roster records must be a non-empty array")
    candidate_count = int(payload.get("candidate_count", -1))
    if candidate_count != len(records):
        raise ValueError(f"candidate officer roster candidate_count mismatch: {candidate_count} != {len(records)}")

    seen_ids: set[str] = set()
    seen_half_bodies: set[str] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"candidate officer roster records[{index}] must be object")
        leaked = sorted(DISALLOWED_GAMEPLAY_FIELDS.intersection(record.keys()))
        if leaked:
            raise ValueError(f"candidate officer roster records[{index}] leaked gameplay fields: {leaked}")
        candidate_id = str(record.get("candidate_officer_id", ""))
        if not candidate_id.startswith("CANDIDATE_"):
            raise ValueError(f"candidate officer roster records[{index}] invalid candidate_officer_id: {candidate_id}")
        if candidate_id in seen_ids:
            raise ValueError(f"duplicate candidate officer id: {candidate_id}")
        seen_ids.add(candidate_id)
        status = str(record.get("selection_status", ""))
        if status not in ALLOWED_STATUS:
            raise ValueError(f"candidate officer roster records[{index}] invalid selection_status: {status}")
        half_body = str(record.get("half_body", ""))
        if not half_body:
            raise ValueError(f"candidate officer roster records[{index}] missing half_body")
        if half_body in seen_half_bodies:
            raise ValueError(f"duplicate candidate officer half_body: {half_body}")
        seen_half_bodies.add(half_body)
        portrait_path = _res_to_project_path(str(record.get("portrait_res_path", "")))
        if not portrait_path.exists():
            raise FileNotFoundError(f"candidate officer portrait missing: {portrait_path}")
    return records


def update_selection(input_path: Path, output_path: Path, assignments: list[str]) -> dict:
    payload = _load_roster(input_path)
    records = _validate_roster(payload)
    parsed_assignments = [_parse_assignment(raw) for raw in assignments]
    lookup = {str(record["candidate_officer_id"]): record for record in records}

    changed: list[dict] = []
    for candidate_id, status in parsed_assignments:
        if candidate_id not in lookup:
            raise KeyError(f"candidate officer id not found: {candidate_id}")
        record = lookup[candidate_id]
        old_status = str(record["selection_status"])
        record["selection_status"] = status
        changed.append({"candidate_officer_id": candidate_id, "old_status": old_status, "new_status": status})

    _validate_roster(payload)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {status: 0 for status in sorted(ALLOWED_STATUS)}
    for record in records:
        counts[str(record["selection_status"])] += 1
    return {
        "candidate_count": len(records),
        "status_counts": counts,
        "changed": changed,
        "output": str(output_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Update candidate officer selection statuses.")
    parser.add_argument("--input", type=Path, default=DEFAULT_ROSTER_PATH)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--set",
        action="append",
        default=[],
        dest="assignments",
        help="Assignment in CANDIDATE_ID=status form. Status: candidate, selected, rejected.",
    )
    args = parser.parse_args()

    if not args.assignments:
        raise ValueError("at least one --set assignment is required")
    summary = update_selection(args.input, args.output, args.assignments)
    print("candidate_officers:", summary["candidate_count"])
    print("status_counts:", json.dumps(summary["status_counts"], ensure_ascii=False, sort_keys=True))
    for changed in summary["changed"]:
        print("changed:", changed["candidate_officer_id"], changed["old_status"], "->", changed["new_status"])
    print("output:", summary["output"])
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"error: {exc}")
        raise SystemExit(1)
