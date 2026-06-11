extends RefCounted

const CandidateOfficerRosterValidator = preload("res://scripts/data/candidate_officer_roster_validator.gd")

const DEFAULT_ROSTER_PATH := "res://data/content_alpha/candidate_officer_roster.json"


static func load_default_roster() -> Dictionary:
	return load_and_build_lookup(DEFAULT_ROSTER_PATH)


static func load_and_build_lookup(path: String) -> Dictionary:
	var load_result := _load_roster(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"source": {},
			"records": [],
			"lookup": {},
		}
	var validation: Dictionary = CandidateOfficerRosterValidator.validate_roster(load_result.roster)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"source": load_result.roster.get("source", {}),
			"records": [],
			"lookup": {},
		}
	var records: Array = _normalize_records(load_result.roster.records)
	return {
		"ok": true,
		"errors": [],
		"source": load_result.roster.source,
		"records": records,
		"lookup": _build_lookup(records),
	}


static func resolve_candidate(lookup: Dictionary, candidate_officer_id: String) -> Dictionary:
	if not lookup.has(candidate_officer_id):
		return {
			"ok": false,
			"errors": ["candidate officer roster missing id %s" % candidate_officer_id],
			"record": {},
		}
	return {
		"ok": true,
		"errors": [],
		"record": lookup[candidate_officer_id].duplicate(true),
	}


static func _load_roster(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["candidate officer roster file not found: %s" % path],
			"roster": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["candidate officer roster file cannot be opened: %s" % path],
			"roster": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["candidate officer roster root must be a JSON object: %s" % path],
			"roster": {},
		}
	return {
		"ok": true,
		"errors": [],
		"roster": parsed,
	}


static func _normalize_records(records: Array) -> Array:
	var normalized: Array[Dictionary] = []
	for record in records:
		var copied: Dictionary = record.duplicate(true)
		copied.source_reference.representative_source_hero_id = int(copied.source_reference.representative_source_hero_id)
		for binding in copied.source_reference.source_hero_bindings:
			binding.source_hero_id = int(binding.source_hero_id)
		normalized.append(copied)
	return normalized


static func _build_lookup(records: Array) -> Dictionary:
	var lookup := {}
	for record in records:
		lookup[str(record.candidate_officer_id)] = record
	return lookup
