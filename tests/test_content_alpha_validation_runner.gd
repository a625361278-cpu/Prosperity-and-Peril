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
	if int(summary.reusable_portraits) != 212:
		return {"ok": false, "message": "unexpected reusable portrait count %s" % str(summary.reusable_portraits)}
	if int(summary.candidate_officers) != 212:
		return {"ok": false, "message": "unexpected candidate officer count %s" % str(summary.candidate_officers)}
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
	if str(summary.first_texture_path_kind) != "imported_res":
		return {"ok": false, "message": "content alpha validation must use imported res texture path"}
	if not str(summary.first_texture_source_path).begins_with("res://assets/content_alpha/hero_portraits/"):
		return {"ok": false, "message": "content alpha validation did not use project imported portrait"}
	if str(summary.first_reusable_portrait_source_name_cn) != "刘备":
		return {"ok": false, "message": "content alpha validation did not resolve reusable portrait pool"}
	if str(summary.first_candidate_officer_id) != "CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1001":
		return {"ok": false, "message": "content alpha validation did not resolve candidate officer roster"}
	if str(summary.first_candidate_display_name_cn) != "刘备":
		return {"ok": false, "message": "content alpha validation candidate display name mismatch"}
	if not str(summary.portrait_pool_scope_rule).contains("do not import source gameplay fields"):
		return {"ok": false, "message": "content alpha validation did not expose portrait pool scope rule"}
	if not str(summary.candidate_roster_rule).contains("not the final officer database"):
		return {"ok": false, "message": "content alpha validation did not expose candidate roster boundary"}
	if int(summary.ui_navigation_screens) != 8:
		return {"ok": false, "message": "unexpected ui navigation screen count %s" % str(summary.ui_navigation_screens)}
	if int(summary.ui_navigation_available_screens) != 5:
		return {"ok": false, "message": "unexpected available ui navigation screen count"}
	if int(summary.ui_navigation_planned_screens) != 3:
		return {"ok": false, "message": "unexpected planned ui navigation screen count"}
	if not str(summary.ui_navigation_boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "content alpha validation did not expose ui navigation boundary"}
	if str(summary.ui_navigation_candidate_workbench_status) != "content_alpha_available":
		return {"ok": false, "message": "candidate workbench ui navigation status mismatch"}
	if int(summary.ui_wireframes) != 8:
		return {"ok": false, "message": "unexpected ui wireframe count %s" % str(summary.ui_wireframes)}
	if int(summary.ui_wireframe_specified) != 7:
		return {"ok": false, "message": "unexpected formal ui wireframe count"}
	if int(summary.ui_wireframe_content_alpha_tools) != 1:
		return {"ok": false, "message": "unexpected content alpha tool wireframe count"}
	if not str(summary.ui_wireframe_boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "content alpha validation did not expose ui wireframe boundary"}
	if not FileAccess.file_exists(str(summary.ui_wireframe_style_reference)):
		return {"ok": false, "message": "ui wireframe style reference missing"}
	if int(summary.ui_wireframe_sortie_components) < 5:
		return {"ok": false, "message": "sortie wireframe did not expose expected components"}
	if int(summary.ui_theme_palette_colors) < 12:
		return {"ok": false, "message": "unexpected ui theme palette color count"}
	if int(summary.ui_theme_corner_radius) != 6:
		return {"ok": false, "message": "ui theme corner radius mismatch"}
	if str(summary.ui_theme_accent_gold) != "#C69A3E":
		return {"ok": false, "message": "ui theme accent gold mismatch"}
	if not str(summary.ui_theme_boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "content alpha validation did not expose ui theme boundary"}
	if not FileAccess.file_exists(str(summary.ui_theme_style_reference)):
		return {"ok": false, "message": "ui theme style reference missing"}
	if str(summary.ui_theme_resource_path) != "res://themes/content_alpha_formal_theme.tres":
		return {"ok": false, "message": "content alpha theme resource path mismatch"}
	if int(summary.ui_theme_resource_control_types) != 3:
		return {"ok": false, "message": "content alpha theme control type count mismatch"}
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
