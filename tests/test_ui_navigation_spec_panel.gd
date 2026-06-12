extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("ui navigation spec panel has expected nodes", _test_panel_nodes)
	_run("ui navigation spec panel loads default spec", _test_panel_loads_default_spec)
	_run("ui navigation spec panel selects planned formal roster", _test_panel_selects_formal_roster)
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
	if root.get_node_or_null("SpecSummary") == null:
		root.queue_free()
		return {"ok": false, "message": "spec summary missing"}
	if root.get_node_or_null("ScreenList") == null:
		root.queue_free()
		return {"ok": false, "message": "screen list missing"}
	if root.get_node_or_null("ScreenDetail") == null:
		root.queue_free()
		return {"ok": false, "message": "screen detail missing"}
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
		return {"ok": false, "message": "expected spec panel load success, got %s" % [result.errors]}
	if root.get_item_count() != 8:
		root.queue_free()
		return {"ok": false, "message": "expected 8 ui spec items"}
	if not root.get_summary_text().contains("总数=8 调试可用=1 Alpha可用=5 规划=2"):
		root.queue_free()
		return {"ok": false, "message": "summary missing ui spec counts"}
	if not root.get_selected_detail_text().contains("战略大地图"):
		root.queue_free()
		return {"ok": false, "message": "default selection detail missing strategic map"}
	root.queue_free()
	return {"ok": true}


func _test_panel_selects_formal_roster() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var load_result: Dictionary = root.load_default_spec()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected spec panel load success"}
	var select_result: Dictionary = root.select_screen("formal_officer_roster")
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal roster selection success"}
	var detail: String = root.get_selected_detail_text()
	if not detail.contains("正式武将名册") or not detail.contains("planned"):
		root.queue_free()
		return {"ok": false, "message": "formal roster detail missing title or status"}
	if not detail.contains("not a finished Beta UI"):
		root.queue_free()
		return {"ok": false, "message": "formal roster detail missing beta boundary"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/ui_navigation_spec_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "ui navigation spec panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
