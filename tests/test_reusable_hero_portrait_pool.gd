extends SceneTree

const ReusableHeroPortraitPoolValidator = preload("res://scripts/data/reusable_hero_portrait_pool_validator.gd")
const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")

const POOL_PATH := "res://data/content_alpha/reusable_hero_portrait_pool.json"


var _failed := 0


func _initialize() -> void:
	_run("reusable hero portrait pool is valid", _test_pool_is_valid)
	_run("reusable hero portrait pool loader resolves imported portraits", _test_loader_resolves_imported_portraits)
	_run("reusable hero portrait pool keeps alternate source bindings", _test_keeps_alternate_source_bindings)
	_run("reusable hero portrait pool rejects source gameplay fields", _test_rejects_source_gameplay_fields)
	_run("reusable hero portrait pool rejects missing portrait resource", _test_rejects_missing_portrait_resource)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_pool_is_valid() -> Dictionary:
	var pool_result := _load_pool()
	if not pool_result.ok:
		return pool_result
	var validation: Dictionary = ReusableHeroPortraitPoolValidator.validate_pool(pool_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid reusable portrait pool, got %s" % [validation.errors]}
	if int(pool_result.data.asset_count) != 212:
		return {"ok": false, "message": "expected 212 reusable portrait assets"}
	if pool_result.data.records.size() != 212:
		return {"ok": false, "message": "expected 212 reusable portrait records"}
	return {"ok": true}


func _test_loader_resolves_imported_portraits() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var portrait_result: Dictionary = ReusableHeroPortraitPoolLoader.resolve_portrait(load_result.lookup, "UI_gj_gg_basemap_hero_1001")
	if not portrait_result.ok:
		return {"ok": false, "message": "expected portrait UI_gj_gg_basemap_hero_1001"}
	var record: Dictionary = portrait_result.record
	if str(record.representative_source_name_cn) != "刘备":
		return {"ok": false, "message": "portrait representative source name mismatch"}
	if str(record.portrait_res_path) != "res://assets/content_alpha/hero_portraits/UI_gj_gg_basemap_hero_1001.png":
		return {"ok": false, "message": "portrait res path mismatch"}
	if int(record.width) != 1300 or int(record.height) != 1080:
		return {"ok": false, "message": "portrait size mismatch"}
	return {"ok": true}


func _test_keeps_alternate_source_bindings() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var portrait_result: Dictionary = ReusableHeroPortraitPoolLoader.resolve_portrait(load_result.lookup, "UI_gj_gg_basemap_hero_1004")
	if not portrait_result.ok:
		return {"ok": false, "message": "expected portrait UI_gj_gg_basemap_hero_1004"}
	var has_zhaoyun_alt := false
	for binding in portrait_result.record.source_hero_bindings:
		if int(binding.source_hero_id) == 2000501 and str(binding.source_name_cn) == "赵云":
			has_zhaoyun_alt = true
	if not has_zhaoyun_alt:
		return {"ok": false, "message": "expected alternate source binding 2000501 for Zhao Yun portrait"}
	return {"ok": true}


func _test_rejects_source_gameplay_fields() -> Dictionary:
	var pool_result := _load_pool()
	if not pool_result.ok:
		return pool_result
	var copied: Dictionary = pool_result.data.duplicate(true)
	copied.records[0].skill_ids = [5]
	var validation: Dictionary = ReusableHeroPortraitPoolValidator.validate_pool(copied)
	return _expect_error_contains(validation, "leaked source gameplay field")


func _test_rejects_missing_portrait_resource() -> Dictionary:
	var pool_result := _load_pool()
	if not pool_result.ok:
		return pool_result
	var copied: Dictionary = pool_result.data.duplicate(true)
	copied.records[0].portrait_res_path = "res://assets/content_alpha/hero_portraits/missing_hero.png"
	var validation: Dictionary = ReusableHeroPortraitPoolValidator.validate_pool(copied)
	return _expect_error_contains(validation, "portrait_res_path missing file")


func _load_pool() -> Dictionary:
	if not FileAccess.file_exists(POOL_PATH):
		return {"ok": false, "message": "reusable hero portrait pool missing: %s" % POOL_PATH}
	var file := FileAccess.open(POOL_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "reusable hero portrait pool cannot be opened: %s" % POOL_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "reusable hero portrait pool root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
