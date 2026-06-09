extends RefCounted

const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")


static func build_preview_rows(lookup: Dictionary, hero_ids: Array) -> Dictionary:
	var errors: Array[String] = []
	var rows: Array[Dictionary] = []
	for hero_id in hero_ids:
		var resolved: Dictionary = HeroPortraitIndexLoader.resolve_portrait(lookup, hero_id)
		if not resolved.ok:
			errors.append_array(resolved.errors)
			continue
		var record: Dictionary = resolved.record
		_validate_record_path(record, errors)
		rows.append({
			"hero_id": int(record.id),
			"name_cn": str(record.name_cn),
			"name_key": str(record.name_key),
			"half_body": str(record.half_body),
			"portrait_source_path": str(record.portrait_source_path),
		})
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"rows": [],
		}
	return {
		"ok": true,
		"errors": [],
		"rows": rows,
	}


static func build_default_preview_rows(lookup: Dictionary, limit: int) -> Dictionary:
	if limit <= 0:
		return {
			"ok": false,
			"errors": ["hero portrait preview limit must be positive"],
			"rows": [],
		}
	var hero_ids := _first_numeric_ids(lookup, limit)
	if hero_ids.is_empty():
		return {
			"ok": false,
			"errors": ["hero portrait preview requires at least one indexed hero"],
			"rows": [],
		}
	return build_preview_rows(lookup, hero_ids)


static func _validate_record_path(record: Dictionary, errors: Array[String]) -> void:
	if not record.has("portrait_source_path"):
		errors.append("hero portrait preview record missing portrait_source_path")
		return
	var portrait_path := str(record.portrait_source_path)
	if portrait_path.is_empty():
		errors.append("hero portrait preview record empty portrait_source_path")
	elif not FileAccess.file_exists(portrait_path):
		errors.append("hero portrait preview source file missing: %s" % portrait_path)


static func _first_numeric_ids(lookup: Dictionary, limit: int) -> Array:
	var ids: Array[int] = []
	for key in lookup.keys():
		if str(key).is_valid_int():
			ids.append(int(key))
	ids.sort()
	var result := []
	for index in min(limit, ids.size()):
		result.append(ids[index])
	return result
