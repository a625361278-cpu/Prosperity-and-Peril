extends SceneTree

const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("reusable hero portrait browser has expected nodes", _test_browser_nodes)
	_run("reusable hero portrait browser loads default pool", _test_browser_loads_default_pool)
	_run("reusable hero portrait browser selects alternate portrait", _test_browser_selects_alternate_portrait)
	_run("reusable hero portrait browser rejects missing imported resource", _test_browser_rejects_missing_resource)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_browser_nodes() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root: VBoxContainer = panel.node
	if root.get_node_or_null("PortraitList") == null:
		root.queue_free()
		return {"ok": false, "message": "portrait browser list missing"}
	if root.get_node_or_null("PortraitDetail") == null:
		root.queue_free()
		return {"ok": false, "message": "portrait browser detail missing"}
	var image: TextureRect = root.get_node("PortraitImage")
	if image.texture != null:
		root.queue_free()
		return {"ok": false, "message": "portrait browser must not start with default texture"}
	root.queue_free()
	return {"ok": true}


func _test_browser_loads_default_pool() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.load_default_pool()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected default pool load success, got %s" % [result.errors]}
	if root.get_item_count() != 212:
		root.queue_free()
		return {"ok": false, "message": "expected 212 reusable portrait list items"}
	if not root.get_selected_detail_text().contains("参考名: 刘备"):
		root.queue_free()
		return {"ok": false, "message": "expected first detail to show Liu Bei"}
	if not root.has_preview_texture():
		root.queue_free()
		return {"ok": false, "message": "expected first portrait texture"}
	root.queue_free()
	return {"ok": true}


func _test_browser_selects_alternate_portrait() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var load_result: Dictionary = root.load_default_pool()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected default pool load success, got %s" % [load_result.errors]}
	var select_result: Dictionary = root.select_half_body("UI_gj_gg_basemap_hero_1004")
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected select Zhao Yun portrait success, got %s" % [select_result.errors]}
	var detail: String = root.get_selected_detail_text()
	if not detail.contains("参考名: 赵云") or not detail.contains("源绑定: 2"):
		root.queue_free()
		return {"ok": false, "message": "expected Zhao Yun detail with two source bindings"}
	root.queue_free()
	return {"ok": true}


func _test_browser_rejects_missing_resource() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		return {"ok": false, "message": "expected reusable portrait pool load success, got %s" % [load_result.errors]}
	var records: Array = load_result.records.duplicate(true)
	records[0].portrait_res_path = "res://assets/content_alpha/hero_portraits/missing_hero.png"
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.set_records(records)
	if result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected missing imported resource to fail"}
	if not root.get_selected_detail_text().contains("imported file missing"):
		root.queue_free()
		return {"ok": false, "message": "expected missing imported resource detail"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/reusable_hero_portrait_browser_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "reusable hero portrait browser panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
