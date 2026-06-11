extends SceneTree

const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")
const ReusableHeroPortraitPoolPresenter = preload("res://scripts/ui/reusable_hero_portrait_pool_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("reusable hero portrait presenter exposes imported rows", _test_preview_rows)
	_run("reusable hero portrait presenter rejects invalid limit", _test_invalid_limit_fails)
	_run("reusable hero portrait presenter rejects missing imported resource", _test_missing_imported_resource_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_preview_rows() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var result: Dictionary = ReusableHeroPortraitPoolPresenter.build_default_preview_rows(load_result.records, 3)
	if not result.ok:
		return {"ok": false, "message": "expected preview rows, got %s" % [result.errors]}
	if result.rows.size() != 3:
		return {"ok": false, "message": "expected 3 reusable preview rows"}
	if int(result.rows[0].hero_id) != 1001 or str(result.rows[0].name_cn) != "刘备":
		return {"ok": false, "message": "expected first reusable preview row to be 刘备"}
	if not FileAccess.file_exists(str(result.rows[0].portrait_res_path)):
		return {"ok": false, "message": "expected first reusable preview portrait file to exist"}
	if int(result.rows[0].source_binding_count) < 1:
		return {"ok": false, "message": "expected source binding count"}
	return {"ok": true}


func _test_invalid_limit_fails() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var result: Dictionary = ReusableHeroPortraitPoolPresenter.build_default_preview_rows(load_result.records, 0)
	return _expect_error_contains(result, "preview limit must be positive")


func _test_missing_imported_resource_fails() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var records: Array = load_result.records.duplicate(true)
	records[0].portrait_res_path = "res://assets/content_alpha/hero_portraits/missing_hero.png"
	var result: Dictionary = ReusableHeroPortraitPoolPresenter.build_default_preview_rows(records, 1)
	return _expect_error_contains(result, "imported file missing")


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
