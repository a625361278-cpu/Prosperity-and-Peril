extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("ui theme token panel has expected nodes", _test_panel_nodes)
	_run("ui theme token panel loads default tokens", _test_panel_loads_default_tokens)
	_run("ui theme token panel selects controls", _test_panel_selects_controls)
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
	if root.get_node_or_null("ThemeSummary") == null:
		root.queue_free()
		return {"ok": false, "message": "theme summary missing"}
	if root.get_node_or_null("TokenList") == null:
		root.queue_free()
		return {"ok": false, "message": "token list missing"}
	if root.get_node_or_null("TokenDetail") == null:
		root.queue_free()
		return {"ok": false, "message": "token detail missing"}
	root.queue_free()
	return {"ok": true}


func _test_panel_loads_default_tokens() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.load_default_tokens()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected theme token panel load success, got %s" % [result.errors]}
	if root.get_item_count() != 6:
		root.queue_free()
		return {"ok": false, "message": "expected 6 ui theme token groups"}
	if not root.get_summary_text().contains("色板=15 控件=5 圆角=6"):
		root.queue_free()
		return {"ok": false, "message": "summary missing ui theme token counts"}
	if not root.get_selected_detail_text().contains("#C69A3E"):
		root.queue_free()
		return {"ok": false, "message": "default selection detail missing accent gold"}
	root.queue_free()
	return {"ok": true}


func _test_panel_selects_controls() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var load_result: Dictionary = root.load_default_tokens()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected theme token panel load success"}
	var select_result: Dictionary = root.select_token("controls")
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected controls token selection success"}
	var detail: String = root.get_selected_detail_text()
	if not detail.contains("按钮") or not detail.contains("pressed=accent_red"):
		root.queue_free()
		return {"ok": false, "message": "controls detail missing button state"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/ui_theme_token_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "ui theme token panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
