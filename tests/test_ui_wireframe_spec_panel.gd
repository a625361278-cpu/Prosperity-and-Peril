extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("ui wireframe spec panel has expected nodes", _test_panel_nodes)
	_run("ui wireframe spec panel loads default spec", _test_panel_loads_default_spec)
	_run("ui wireframe spec panel selects sortie panel", _test_panel_selects_sortie_panel)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_panel_nodes() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root: VBoxContainer = panel.node
	if root.get_node_or_null("WireframeSummary") == null:
		root.queue_free()
		return {"ok": false, "message": "wireframe summary missing"}
	if root.get_node_or_null("WireframeList") == null:
		root.queue_free()
		return {"ok": false, "message": "wireframe list missing"}
	if root.get_node_or_null("WireframeDetail") == null:
		root.queue_free()
		return {"ok": false, "message": "wireframe detail missing"}
	root.queue_free()
	return {"ok": true}


func _test_panel_loads_default_spec() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.load_default_spec()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected wireframe panel load success, got %s" % [result.errors]}
	if root.get_item_count() != 8:
		root.queue_free()
		return {"ok": false, "message": "expected 8 ui wireframe items"}
	if not root.get_summary_text().contains("总数=8 正式线框=7 Alpha工具=1"):
		root.queue_free()
		return {"ok": false, "message": "summary missing ui wireframe counts"}
	if not root.get_selected_detail_text().contains("战略大地图"):
		root.queue_free()
		return {"ok": false, "message": "default selection detail missing strategic map"}
	root.queue_free()
	return {"ok": true}


func _test_panel_selects_sortie_panel() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var load_result: Dictionary = root.load_default_spec()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected wireframe panel load success"}
	var select_result: Dictionary = root.select_wireframe("appointment_sortie_panel")
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected sortie wireframe selection success"}
	var detail: String = root.get_selected_detail_text()
	if not detail.contains("任命与出阵") or not detail.contains("RouteRiskPreview"):
		root.queue_free()
		return {"ok": false, "message": "sortie wireframe detail missing title or component"}
	if not detail.contains("not a finished Beta UI"):
		root.queue_free()
		return {"ok": false, "message": "sortie wireframe detail missing beta boundary"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/ui_wireframe_spec_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "ui wireframe spec panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
