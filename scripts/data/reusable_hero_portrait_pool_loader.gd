extends RefCounted

const ReusableHeroPortraitPoolValidator = preload("res://scripts/data/reusable_hero_portrait_pool_validator.gd")

const DEFAULT_POOL_PATH := "res://data/content_alpha/reusable_hero_portrait_pool.json"
const INTEGER_RECORD_FIELDS := ["width", "height", "byte_size", "representative_source_hero_id"]


static func load_default_pool() -> Dictionary:
	return load_and_build_lookup(DEFAULT_POOL_PATH)


static func load_and_build_lookup(path: String) -> Dictionary:
	var load_result := _load_pool(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"source": {},
			"lookup": {},
			"records": [],
		}
	var validation: Dictionary = ReusableHeroPortraitPoolValidator.validate_pool(load_result.pool)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"source": load_result.pool.get("source", {}),
			"lookup": {},
			"records": [],
		}
	var records: Array = _normalize_records(load_result.pool.records)
	return {
		"ok": true,
		"errors": [],
		"source": load_result.pool.source,
		"lookup": _build_lookup(records),
		"records": records,
	}


static func resolve_portrait(lookup: Dictionary, half_body: String) -> Dictionary:
	if not lookup.has(half_body):
		return {
			"ok": false,
			"errors": ["reusable hero portrait pool missing half_body %s" % half_body],
			"record": {},
		}
	return {
		"ok": true,
		"errors": [],
		"record": lookup[half_body].duplicate(true),
	}


static func _load_pool(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["reusable hero portrait pool file not found: %s" % path],
			"pool": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["reusable hero portrait pool file cannot be opened: %s" % path],
			"pool": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["reusable hero portrait pool root must be a JSON object: %s" % path],
			"pool": {},
		}
	return {
		"ok": true,
		"errors": [],
		"pool": parsed,
	}


static func _normalize_records(records: Array) -> Array:
	var normalized: Array = []
	for record in records:
		var copied: Dictionary = record.duplicate(true)
		for field in INTEGER_RECORD_FIELDS:
			copied[field] = int(copied[field])
		for binding in copied.source_hero_bindings:
			binding.source_hero_id = int(binding.source_hero_id)
		normalized.append(copied)
	return normalized


static func _build_lookup(records: Array) -> Dictionary:
	var lookup := {}
	for record in records:
		lookup[str(record.half_body)] = record
	return lookup
