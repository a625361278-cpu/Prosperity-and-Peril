extends SceneTree

const ContentAlphaValidationRunner = preload("res://scripts/data/content_alpha_validation_runner.gd")
const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("content alpha validation runner checks default hero portrait chain", _test_default_chain)
	_run("content alpha validation runner exposes missing manifest", _test_missing_manifest_fails)
	_run("content alpha validation runner exposes invalid preview limit", _test_invalid_preview_limit_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_default_chain() -> Dictionary:
	var result: Dictionary = ContentAlphaValidationRunner.validate_default_content()
	if not result.ok:
		return {"ok": false, "message": "expected default content validation success, got %s" % [result.errors]}
	var summary: Dictionary = result.summary
	if str(summary.pack_id) != HeroPortraitPackLoader.HERO_PORTRAIT_PACK_ID:
		return {"ok": false, "message": "unexpected pack id %s" % str(summary.pack_id)}
	if int(summary.indexed_heroes) != 426:
		return {"ok": false, "message": "unexpected indexed hero count %s" % str(summary.indexed_heroes)}
	if int(summary.preview_rows) != ContentAlphaValidationRunner.DEFAULT_PREVIEW_LIMIT:
		return {"ok": false, "message": "unexpected preview row count"}
	if int(summary.first_hero_id) != 1001 or str(summary.first_hero_name_cn) != "刘备":
		return {"ok": false, "message": "unexpected first validated hero"}
	if str(summary.first_half_body) != "UI_gj_gg_basemap_hero_1001":
		return {"ok": false, "message": "first halfBody mapping was not preserved"}
	if int(summary.first_texture_width) != 1300 or int(summary.first_texture_height) != 1080:
		return {"ok": false, "message": "unexpected first texture size"}
	if not FileAccess.file_exists(str(summary.first_texture_source_path)):
		return {"ok": false, "message": "expected first texture source path to exist"}
	return {"ok": true}


func _test_missing_manifest_fails() -> Dictionary:
	var result: Dictionary = ContentAlphaValidationRunner.validate_hero_portrait_pack(
		"res://data/content_alpha/missing_resource_manifest.json",
		HeroPortraitPackLoader.HERO_PORTRAIT_PACK_ID,
		ContentAlphaValidationRunner.DEFAULT_PREVIEW_LIMIT
	)
	return _expect_error_contains(result, "content alpha resource manifest file not found")


func _test_invalid_preview_limit_fails() -> Dictionary:
	var result: Dictionary = ContentAlphaValidationRunner.validate_hero_portrait_pack(
		HeroPortraitPackLoader.RESOURCE_MANIFEST_PATH,
		HeroPortraitPackLoader.HERO_PORTRAIT_PACK_ID,
		0
	)
	return _expect_error_contains(result, "hero portrait preview limit must be positive")


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
