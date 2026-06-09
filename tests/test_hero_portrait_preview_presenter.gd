extends SceneTree

const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")
const HeroPortraitPreviewPresenter = preload("res://scripts/ui/hero_portrait_preview_presenter.gd")

const PORTRAIT_INDEX_PATH := "res://data/content_alpha/hero_portrait_index.json"


var _failed := 0


func _initialize() -> void:
	_run("hero portrait preview exposes audited rows", _test_preview_rows)
	_run("hero portrait preview keeps non id-derived mapping", _test_preview_keeps_half_body_mapping)
	_run("hero portrait preview fails for missing source file", _test_missing_source_file_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_preview_rows() -> Dictionary:
	var lookup_result := _load_lookup()
	if not lookup_result.ok:
		return lookup_result
	var result: Dictionary = HeroPortraitPreviewPresenter.build_default_preview_rows(lookup_result.lookup, 3)
	if not result.ok:
		return {"ok": false, "message": "expected preview rows, got %s" % [result.errors]}
	if result.rows.size() != 3:
		return {"ok": false, "message": "expected 3 preview rows"}
	if result.rows[0].hero_id != 1001 or result.rows[0].name_cn != "刘备":
		return {"ok": false, "message": "expected first preview row to be 刘备"}
	if not FileAccess.file_exists(str(result.rows[0].portrait_source_path)):
		return {"ok": false, "message": "expected first preview portrait file to exist"}
	return {"ok": true}


func _test_preview_keeps_half_body_mapping() -> Dictionary:
	var lookup_result := _load_lookup()
	if not lookup_result.ok:
		return lookup_result
	var result: Dictionary = HeroPortraitPreviewPresenter.build_preview_rows(lookup_result.lookup, [2000501])
	if not result.ok:
		return {"ok": false, "message": "expected preview row, got %s" % [result.errors]}
	if result.rows[0].half_body != "UI_gj_gg_basemap_hero_1004":
		return {"ok": false, "message": "expected hero 2000501 to keep audited halfBody"}
	return {"ok": true}


func _test_missing_source_file_fails() -> Dictionary:
	var lookup_result := _load_lookup()
	if not lookup_result.ok:
		return lookup_result
	var copied: Dictionary = lookup_result.lookup.duplicate(true)
	var record: Dictionary = copied["1001"].duplicate(true)
	record.portrait_source_path = "E:/newsanguo/missing_portrait_file.png"
	copied["1001"] = record
	var result: Dictionary = HeroPortraitPreviewPresenter.build_preview_rows(copied, [1001])
	if result.ok:
		return {"ok": false, "message": "expected missing source file to fail"}
	for error in result.errors:
		if str(error).contains("hero portrait preview source file missing"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing source file error, got %s" % [result.errors]}


func _load_lookup() -> Dictionary:
	var result: Dictionary = HeroPortraitIndexLoader.load_and_build_lookup(PORTRAIT_INDEX_PATH)
	if not result.ok:
		return {"ok": false, "message": "portrait index load failed: %s" % [result.errors]}
	return {
		"ok": true,
		"lookup": result.lookup,
	}
