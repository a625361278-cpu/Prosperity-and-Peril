extends SceneTree

const HeroPortraitImportManifestValidator = preload("res://scripts/data/hero_portrait_import_manifest_validator.gd")
const HeroPortraitImportManifestLoader = preload("res://scripts/data/hero_portrait_import_manifest_loader.gd")

const IMPORT_MANIFEST_PATH := "res://data/content_alpha/hero_portrait_import_manifest.json"


var _failed := 0


func _initialize() -> void:
	_run("hero portrait import manifest validates imported pngs", _test_import_manifest_is_valid)
	_run("hero portrait import manifest loader indexes bindings", _test_loader_indexes_bindings)
	_run("hero portrait import manifest rejects missing target file", _test_missing_target_file_fails)
	_run("hero portrait import manifest rejects sha mismatch", _test_sha_mismatch_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_import_manifest_is_valid() -> Dictionary:
	var manifest_result := _load_manifest()
	if not manifest_result.ok:
		return manifest_result
	var validation: Dictionary = HeroPortraitImportManifestValidator.validate_manifest(manifest_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid import manifest, got %s" % [validation.errors]}
	if int(manifest_result.data.asset_count) != 212:
		return {"ok": false, "message": "expected 212 imported unique assets"}
	if int(manifest_result.data.hero_binding_count) != 426:
		return {"ok": false, "message": "expected 426 imported hero bindings"}
	return {"ok": true}


func _test_loader_indexes_bindings() -> Dictionary:
	var load_result: Dictionary = HeroPortraitImportManifestLoader.load_default_manifest()
	if not load_result.ok:
		return {"ok": false, "message": "expected import manifest load success, got %s" % [load_result.errors]}
	var binding_result: Dictionary = HeroPortraitImportManifestLoader.resolve_binding(load_result.bindings_by_hero_id, 2000501)
	if not binding_result.ok:
		return {"ok": false, "message": "expected imported binding for 2000501"}
	if str(binding_result.binding.half_body) != "UI_gj_gg_basemap_hero_1004":
		return {"ok": false, "message": "imported binding did not preserve audited halfBody mapping"}
	if str(binding_result.binding.target_res_path) != "res://assets/content_alpha/hero_portraits/UI_gj_gg_basemap_hero_1004.png":
		return {"ok": false, "message": "unexpected imported target path"}
	if not FileAccess.file_exists(str(binding_result.binding.target_res_path)):
		return {"ok": false, "message": "imported target path missing"}
	return {"ok": true}


func _test_missing_target_file_fails() -> Dictionary:
	var manifest_result := _load_manifest()
	if not manifest_result.ok:
		return manifest_result
	var copied: Dictionary = manifest_result.data.duplicate(true)
	copied.assets[0].target_res_path = "res://assets/content_alpha/hero_portraits/missing_portrait.png"
	var validation: Dictionary = HeroPortraitImportManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "target_res_path missing file")


func _test_sha_mismatch_fails() -> Dictionary:
	var manifest_result := _load_manifest()
	if not manifest_result.ok:
		return manifest_result
	var copied: Dictionary = manifest_result.data.duplicate(true)
	copied.assets[0].sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
	var validation: Dictionary = HeroPortraitImportManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "sha256 mismatch")


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(IMPORT_MANIFEST_PATH):
		return {"ok": false, "message": "hero portrait import manifest missing: %s" % IMPORT_MANIFEST_PATH}
	var file := FileAccess.open(IMPORT_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "hero portrait import manifest cannot be opened: %s" % IMPORT_MANIFEST_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "hero portrait import manifest root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
