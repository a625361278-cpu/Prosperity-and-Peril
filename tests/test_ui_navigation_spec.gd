extends SceneTree

const UiNavigationSpecValidator = preload("res://scripts/data/ui_navigation_spec_validator.gd")
const UiNavigationSpecLoader = preload("res://scripts/data/ui_navigation_spec_loader.gd")

const SPEC_PATH := "res://data/content_alpha/ui_navigation_spec.json"


var _failed := 0


func _initialize() -> void:
	_run("ui navigation spec is valid", _test_spec_is_valid)
	_run("ui navigation spec loader resolves core screens", _test_loader_resolves_core_screens)
	_run("ui navigation spec rejects missing required screen", _test_rejects_missing_required_screen)
	_run("ui navigation spec rejects invalid status", _test_rejects_invalid_status)
	_run("ui navigation spec rejects missing res source", _test_rejects_missing_res_source)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_spec_is_valid() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var validation: Dictionary = UiNavigationSpecValidator.validate_spec(spec_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid ui navigation spec, got %s" % [validation.errors]}
	if spec_result.data.screens.size() != 8:
		return {"ok": false, "message": "expected 8 ui navigation screens"}
	return {"ok": true}


func _test_loader_resolves_core_screens() -> Dictionary:
	var load_result: Dictionary = UiNavigationSpecLoader.load_default_spec()
	if not load_result.ok:
		return {"ok": false, "message": "expected ui spec load success, got %s" % [load_result.errors]}
	var strategic_result: Dictionary = UiNavigationSpecLoader.resolve_screen(load_result.lookup, "strategic_map")
	if not strategic_result.ok:
		return {"ok": false, "message": "expected strategic_map screen"}
	if str(strategic_result.screen.implementation_status) != "debug_available":
		return {"ok": false, "message": "strategic_map status mismatch"}
	var city_result: Dictionary = UiNavigationSpecLoader.resolve_screen(load_result.lookup, "city_detail_panel")
	if not city_result.ok:
		return {"ok": false, "message": "expected city_detail_panel screen"}
	if str(city_result.screen.implementation_status) != "content_alpha_available":
		return {"ok": false, "message": "city_detail_panel status mismatch"}
	var roster_result: Dictionary = UiNavigationSpecLoader.resolve_screen(load_result.lookup, "formal_officer_roster")
	if not roster_result.ok:
		return {"ok": false, "message": "expected formal_officer_roster screen"}
	if str(roster_result.screen.implementation_status) != "planned":
		return {"ok": false, "message": "formal_officer_roster must remain planned"}
	if not str(load_result.source.boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "ui spec boundary rule missing"}
	return {"ok": true}


func _test_rejects_missing_required_screen() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.screens = copied.screens.filter(func(screen): return str(screen.id) != "save_load_panel")
	var validation: Dictionary = UiNavigationSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "missing required screen save_load_panel")


func _test_rejects_invalid_status() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.screens[0].implementation_status = "implemented"
	var validation: Dictionary = UiNavigationSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "implementation_status invalid")


func _test_rejects_missing_res_source() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.screens[0].primary_data_sources.append("res://data/content_alpha/missing_ui_source.json")
	var validation: Dictionary = UiNavigationSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "primary data source missing file")


func _load_spec() -> Dictionary:
	if not FileAccess.file_exists(SPEC_PATH):
		return {"ok": false, "message": "ui navigation spec missing: %s" % SPEC_PATH}
	var file := FileAccess.open(SPEC_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "ui navigation spec cannot be opened: %s" % SPEC_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "ui navigation spec root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
