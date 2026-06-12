extends SceneTree

const UiWireframeSpecValidator = preload("res://scripts/data/ui_wireframe_spec_validator.gd")
const UiWireframeSpecLoader = preload("res://scripts/data/ui_wireframe_spec_loader.gd")

const SPEC_PATH := "res://data/content_alpha/ui_wireframe_spec.json"


var _failed := 0


func _initialize() -> void:
	_run("ui wireframe spec is valid", _test_spec_is_valid)
	_run("ui wireframe spec loader resolves core wireframes", _test_loader_resolves_core_wireframes)
	_run("ui wireframe spec rejects missing required wireframe", _test_rejects_missing_required_wireframe)
	_run("ui wireframe spec rejects invalid status", _test_rejects_invalid_status)
	_run("ui wireframe spec rejects missing style reference", _test_rejects_missing_style_reference)
	_run("ui wireframe spec rejects underspecified layout", _test_rejects_underspecified_layout)
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
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(spec_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid ui wireframe spec, got %s" % [validation.errors]}
	if spec_result.data.wireframes.size() != 8:
		return {"ok": false, "message": "expected 8 ui wireframes"}
	return {"ok": true}


func _test_loader_resolves_core_wireframes() -> Dictionary:
	var load_result: Dictionary = UiWireframeSpecLoader.load_default_spec()
	if not load_result.ok:
		return {"ok": false, "message": "expected ui wireframe load success, got %s" % [load_result.errors]}
	var strategic_result: Dictionary = UiWireframeSpecLoader.resolve_wireframe(load_result.lookup, "strategic_map")
	if not strategic_result.ok:
		return {"ok": false, "message": "expected strategic_map wireframe"}
	if not str(strategic_result.wireframe.layout_regions[0]).contains("3D"):
		return {"ok": false, "message": "strategic map wireframe missing map region"}
	var sortie_result: Dictionary = UiWireframeSpecLoader.resolve_wireframe(load_result.lookup, "appointment_sortie_panel")
	if not sortie_result.ok:
		return {"ok": false, "message": "expected appointment_sortie_panel wireframe"}
	if not str(sortie_result.wireframe.interactions[2]).contains("时间"):
		return {"ok": false, "message": "sortie wireframe must expose time and food risk"}
	if not str(load_result.source.boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "ui wireframe boundary rule missing"}
	return {"ok": true}


func _test_rejects_missing_required_wireframe() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.wireframes = copied.wireframes.filter(func(wireframe): return str(wireframe.id) != "save_load_panel")
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "missing required wireframe save_load_panel")


func _test_rejects_invalid_status() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.wireframes[0].implementation_status = "implemented"
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "implementation_status invalid")


func _test_rejects_missing_style_reference() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.source.style_reference = "res://docs/资源/ui_style_concepts/missing_style.png"
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "source.style_reference missing file")


func _test_rejects_underspecified_layout() -> Dictionary:
	var spec_result := _load_spec()
	if not spec_result.ok:
		return spec_result
	var copied: Dictionary = spec_result.data.duplicate(true)
	copied.wireframes[0].layout_regions = ["只有一个区域"]
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(copied)
	return _expect_error_contains(validation, "at least three layout regions")


func _load_spec() -> Dictionary:
	if not FileAccess.file_exists(SPEC_PATH):
		return {"ok": false, "message": "ui wireframe spec missing: %s" % SPEC_PATH}
	var file := FileAccess.open(SPEC_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "ui wireframe spec cannot be opened: %s" % SPEC_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "ui wireframe spec root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
