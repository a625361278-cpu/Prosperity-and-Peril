extends SceneTree

const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")
const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")
const HeroPortraitPreviewPresenter = preload("res://scripts/ui/hero_portrait_preview_presenter.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

const PORTRAIT_INDEX_PATH := "res://data/content_alpha/hero_portrait_index.json"


var _failed := 0


func _initialize() -> void:
	_run("hero portrait texture loader reads audited png", _test_loads_audited_png)
	_run("hero portrait texture loader prefers imported project png", _test_loads_imported_png)
	_run("hero portrait texture loader fails for non image file", _test_non_image_file_fails)
	_run("hero portrait texture loader fails for incomplete row", _test_incomplete_row_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_loads_audited_png() -> Dictionary:
	var row_result := _preview_row(1001)
	if not row_result.ok:
		return row_result
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(row_result.row)
	if not texture_result.ok:
		return {"ok": false, "message": "expected texture load success, got %s" % [texture_result.errors]}
	if texture_result.width != 1300 or texture_result.height != 1080:
		return {"ok": false, "message": "unexpected portrait texture size %sx%s" % [texture_result.width, texture_result.height]}
	if texture_result.texture == null:
		return {"ok": false, "message": "expected ImageTexture result"}
	if int(texture_result.hero_id) != 1001 or str(texture_result.half_body) != "UI_gj_gg_basemap_hero_1001":
		return {"ok": false, "message": "texture metadata did not preserve audited portrait row"}
	if str(texture_result.path_kind) != "source_path":
		return {"ok": false, "message": "audited index row should load from source path"}
	return {"ok": true}


func _test_loads_imported_png() -> Dictionary:
	var pack_result: Dictionary = HeroPortraitPackLoader.load_default_pack()
	if not pack_result.ok:
		return {"ok": false, "message": "portrait pack load failed: %s" % [pack_result.errors]}
	var preview_result: Dictionary = HeroPortraitPreviewPresenter.build_preview_rows(pack_result.lookup, [1001])
	if not preview_result.ok:
		return {"ok": false, "message": "preview row failed: %s" % [preview_result.errors]}
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(preview_result.rows[0])
	if not texture_result.ok:
		return {"ok": false, "message": "expected imported texture load success, got %s" % [texture_result.errors]}
	if str(texture_result.path_kind) != "imported_res":
		return {"ok": false, "message": "expected imported texture path to be preferred"}
	if str(texture_result.source_path) != "res://assets/content_alpha/hero_portraits/UI_gj_gg_basemap_hero_1001.png":
		return {"ok": false, "message": "unexpected imported texture source path"}
	return {"ok": true}


func _test_non_image_file_fails() -> Dictionary:
	var row_result := _preview_row(1001)
	if not row_result.ok:
		return row_result
	var row: Dictionary = row_result.row.duplicate(true)
	row.portrait_source_path = "E:/newsanguo/docs/ContentAlpha_任务列表.md"
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(row)
	if texture_result.ok:
		return {"ok": false, "message": "expected non image source to fail"}
	for error in texture_result.errors:
		if str(error).contains("hero portrait texture load failed"):
			return {"ok": true}
	return {"ok": false, "message": "expected texture load failure, got %s" % [texture_result.errors]}


func _test_incomplete_row_fails() -> Dictionary:
	var row_result := _preview_row(1001)
	if not row_result.ok:
		return row_result
	var row: Dictionary = row_result.row.duplicate(true)
	row.erase("half_body")
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(row)
	if texture_result.ok:
		return {"ok": false, "message": "expected incomplete row to fail"}
	for error in texture_result.errors:
		if str(error).contains("hero portrait texture row missing half_body"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing half_body error, got %s" % [texture_result.errors]}


func _preview_row(hero_id: int) -> Dictionary:
	var lookup_result: Dictionary = HeroPortraitIndexLoader.load_and_build_lookup(PORTRAIT_INDEX_PATH)
	if not lookup_result.ok:
		return {"ok": false, "message": "portrait index load failed: %s" % [lookup_result.errors]}
	var preview_result: Dictionary = HeroPortraitPreviewPresenter.build_preview_rows(lookup_result.lookup, [hero_id])
	if not preview_result.ok:
		return {"ok": false, "message": "preview row failed: %s" % [preview_result.errors]}
	if preview_result.rows.size() != 1:
		return {"ok": false, "message": "expected one preview row"}
	return {
		"ok": true,
		"row": preview_result.rows[0],
	}
