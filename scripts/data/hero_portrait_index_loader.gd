extends RefCounted

const HeroPortraitIndexValidator = preload("res://scripts/data/hero_portrait_index_validator.gd")


static func load_and_build_lookup(path: String) -> Dictionary:
	var load_result := _load_index(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"lookup": {},
			"source": {},
		}

	var validation: Dictionary = HeroPortraitIndexValidator.validate_index(load_result.index)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"lookup": {},
			"source": load_result.index.get("source", {}),
		}

	var lookup := {}
	for record in load_result.index.records:
		lookup[_hero_id_key(record.id)] = record.duplicate(true)
	return {
		"ok": true,
		"errors": [],
		"lookup": lookup,
		"source": load_result.index.source.duplicate(true),
	}


static func resolve_portrait(lookup: Dictionary, hero_id) -> Dictionary:
	var key := _hero_id_key(hero_id)
	if not lookup.has(key):
		return {
			"ok": false,
			"errors": ["hero portrait index missing hero id %s" % key],
			"record": {},
		}
	return {
		"ok": true,
		"errors": [],
		"record": lookup[key].duplicate(true),
	}


static func _load_index(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["hero portrait index file not found: %s" % path],
			"index": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["hero portrait index file cannot be opened: %s" % path],
			"index": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["hero portrait index root must be a JSON object: %s" % path],
			"index": {},
		}
	return {
		"ok": true,
		"errors": [],
		"index": parsed,
	}


static func _hero_id_key(hero_id) -> String:
	if typeof(hero_id) == TYPE_INT or typeof(hero_id) == TYPE_FLOAT:
		if is_equal_approx(float(hero_id), float(int(hero_id))):
			return str(int(hero_id))
	return str(hero_id)
