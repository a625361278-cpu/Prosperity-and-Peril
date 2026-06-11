extends SceneTree

const ContentAlphaResourceManifestValidator = preload("res://scripts/data/content_alpha_resource_manifest_validator.gd")
const ContentAlphaResourceManifestLoader = preload("res://scripts/data/content_alpha_resource_manifest_loader.gd")
const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")

const MANIFEST_PATH := "res://data/content_alpha/resource_manifest.json"


var _failed := 0


func _initialize() -> void:
	_run("content alpha resource manifest is valid", _test_manifest_is_valid)
	_run("resource manifest rejects missing ownership", _test_missing_ownership_fails)
	_run("resource manifest rejects invalid ownership", _test_invalid_ownership_fails)
	_run("resource manifest rejects missing index path", _test_missing_index_path_fails)
	_run("resource manifest rejects missing import manifest path", _test_missing_import_manifest_path_fails)
	_run("resource manifest rejects missing source project", _test_missing_source_project_fails)
	_run("resource manifest rejects missing source path", _test_missing_source_path_fails)
	_run("resource manifest loader indexes packs by id", _test_loader_indexes_packs)
	_run("resource manifest loader fails for missing pack id", _test_loader_missing_pack_fails)
	_run("hero portrait pack loader resolves lookup from manifest", _test_hero_portrait_pack_loader)
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


func _test_missing_import_manifest_path_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].import_manifest_path = "res://data/content_alpha/missing_import_manifest.json"
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "import_manifest_path missing file")


func _test_missing_source_project_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].source_project = "E:/newsanguo/missing_source_project"
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "source_project missing path")


func _test_missing_source_path_fails() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.ok:
		return manifest
	var copied: Dictionary = manifest.data.duplicate(true)
	copied.resource_packs[0].source_paths[0] = "E:/newsanguo/missing_hero_table.xlsx"
	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(copied)
	return _expect_error_contains(validation, "source_paths missing path")


func _test_loader_indexes_packs() -> Dictionary:
	var load_result: Dictionary = ContentAlphaResourceManifestLoader.load_and_validate(MANIFEST_PATH)
	if not load_result.ok:
		return {"ok": false, "message": "expected manifest loader success, got %s" % [load_result.errors]}
	var pack_result: Dictionary = ContentAlphaResourceManifestLoader.resolve_pack(load_result.packs, "candidate_hero_portraits")
	if not pack_result.ok:
		return {"ok": false, "message": "expected candidate_hero_portraits pack, got %s" % [pack_result.errors]}
	if str(pack_result.pack.ownership_status) != "project_owner_resource":
		return {"ok": false, "message": "expected project_owner_resource pack"}
	if str(pack_result.pack.index_path) != "res://data/content_alpha/hero_portrait_index.json":
		return {"ok": false, "message": "unexpected hero portrait index path"}
	if str(pack_result.pack.import_manifest_path) != "res://data/content_alpha/hero_portrait_import_manifest.json":
		return {"ok": false, "message": "unexpected hero portrait import manifest path"}
	return {"ok": true}


func _test_loader_missing_pack_fails() -> Dictionary:
	var load_result: Dictionary = ContentAlphaResourceManifestLoader.load_and_validate(MANIFEST_PATH)
	if not load_result.ok:
		return {"ok": false, "message": "expected manifest loader success, got %s" % [load_result.errors]}
	var pack_result: Dictionary = ContentAlphaResourceManifestLoader.resolve_pack(load_result.packs, "missing_pack")
	if pack_result.ok:
		return {"ok": false, "message": "expected missing pack to fail"}
	for error in pack_result.errors:
		if str(error).contains("content alpha resource pack missing missing_pack"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing pack error, got %s" % [pack_result.errors]}


func _test_hero_portrait_pack_loader() -> Dictionary:
	var pack_result: Dictionary = HeroPortraitPackLoader.load_default_pack()
	if not pack_result.ok:
		return {"ok": false, "message": "expected hero portrait pack load success, got %s" % [pack_result.errors]}
	if str(pack_result.pack.id) != "candidate_hero_portraits":
		return {"ok": false, "message": "unexpected hero portrait pack id"}
	if not pack_result.lookup.has("1001"):
		return {"ok": false, "message": "hero portrait pack lookup missing hero 1001"}
	if str(pack_result.lookup["1001"].half_body) != "UI_gj_gg_basemap_hero_1001":
		return {"ok": false, "message": "hero portrait pack lookup did not preserve halfBody mapping"}
	if str(pack_result.lookup["1001"].portrait_res_path) != "res://assets/content_alpha/hero_portraits/UI_gj_gg_basemap_hero_1001.png":
		return {"ok": false, "message": "hero portrait pack lookup did not attach imported res path"}
	return {"ok": true}


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
