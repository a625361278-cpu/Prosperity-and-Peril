extends SceneTree

const ContentAlphaResourceManifestValidator = preload("res://scripts/data/content_alpha_resource_manifest_validator.gd")

const MANIFEST_PATH := "res://data/content_alpha/resource_manifest.json"


var _failed := 0


func _initialize() -> void:
	_run("content alpha resource manifest is valid", _test_manifest_is_valid)
	_run("resource manifest rejects missing ownership", _test_missing_ownership_fails)
	_run("resource manifest rejects invalid ownership", _test_invalid_ownership_fails)
	_run("resource manifest rejects missing index path", _test_missing_index_path_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_manifest_is_valid() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(manifest.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid manifest, got %s" % [validation.errors]}
	var pack: Dictionary = manifest.data.resource_packs[0]
	if str(pack.ownership_status) != "project_owner_resource":
		return {"ok": false, "message": "candidate portraits must be marked as project owner resource"}
	if not pack.allowed_contexts.has("content_alpha_ui"):
		return {"ok": false, "message": "candidate portraits must allow content_alpha_ui"}
	return {"ok": true}


func _test_missing_ownership_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].erase("ownership_status")
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "ownership_status missing required field")


func _test_invalid_ownership_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].ownership_status = "unknown_external_resource"
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "ownership_status invalid unknown_external_resource")


func _test_missing_index_path_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].index_path = "res://data/content_alpha/missing_index.json"
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "index_path missing file")


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"ok": false, "message": "content alpha resource manifest missing: %s" % MANIFEST_PATH}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "content alpha resource manifest cannot be opened: %s" % MANIFEST_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "content alpha resource manifest root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
