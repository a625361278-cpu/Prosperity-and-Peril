extends SceneTree

const HeroPortraitIndexValidator = preload("res://scripts/data/hero_portrait_index_validator.gd")


var _failed := 0


func _initialize() -> void:
	_run("content alpha hero portrait index is valid", _test_index_is_valid)
	_run("hero portrait index keeps halfBody as authoritative mapping", _test_half_body_mapping_is_authoritative)
	_run("hero portrait index rejects duplicate ids", _test_duplicate_ids_fail)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_index_is_valid() -> Dictionary:
	var index := _load_index()
	if not index.ok:
		return index
	var validation: Dictionary = HeroPortraitIndexValidator.validate_index(index.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid portrait index, got %s" % [validation.errors]}
	if index.data.records.size() < 400:
		return {"ok": false, "message": "expected staged portrait index to contain at least 400 records"}
	return {"ok": true}


func _test_half_body_mapping_is_authoritative() -> Dictionary:
	var index := _load_index()
	if not index.ok:
		return index
	for record in index.data.records:
		if int(record.id) == 2000501:
			if str(record.half_body) != "UI_gj_gg_basemap_hero_1004":
				return {"ok": false, "message": "hero 2000501 must use audited halfBody mapping, not id-derived mapping"}
			return {"ok": true}
	return {"ok": false, "message": "expected sample hero 2000501 in portrait index"}


func _test_duplicate_ids_fail() -> Dictionary:
	var index := _load_index()
	if not index.ok:
		return index
	var copied: Dictionary = index.data.duplicate(true)
	copied.records.append(copied.records[0].duplicate(true))
	var validation: Dictionary = HeroPortraitIndexValidator.validate_index(copied)
	if validation.ok:
		return {"ok": false, "message": "expected duplicate id validation failure"}
	for error in validation.errors:
		if str(error).contains("duplicate hero portrait index id"):
			return {"ok": true}
	return {"ok": false, "message": "expected duplicate id error, got %s" % [validation.errors]}


func _load_index() -> Dictionary:
	var path := "res://data/content_alpha/hero_portrait_index.json"
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "hero portrait index missing: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "hero portrait index cannot be opened: %s" % path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "hero portrait index root must be a JSON object"}
	return {"ok": true, "data": parsed}
