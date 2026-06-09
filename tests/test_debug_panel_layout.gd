extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("debug panel keeps a readable right-side layout", _test_debug_panel_readable_layout)
	_run("debug panel exposes a dedicated selection text area", _test_debug_panel_selection_area)
	_run("debug panel transparent root does not block map clicks", _test_debug_panel_root_ignores_mouse)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_debug_panel_readable_layout() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	var background := panel.get_node_or_null("PanelBackground")
	if background == null:
		panel.queue_free()
		return {"ok": false, "message": "PanelBackground missing"}
	if background.custom_minimum_size.x < 420.0:
		panel.queue_free()
		return {"ok": false, "message": "right panel minimum width is too small"}
	var text := panel.get_node_or_null("PanelBackground/MarginContainer/VBoxContainer/ScrollContainer/DebugText")
	if text == null:
		panel.queue_free()
		return {"ok": false, "message": "debug text path missing"}
	if text.custom_minimum_size.x < 360.0:
		panel.queue_free()
		return {"ok": false, "message": "debug text minimum width is too small"}
	panel.queue_free()
	return {"ok": true}


func _test_debug_panel_selection_area() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	var selection_text := panel.get_node_or_null("PanelBackground/MarginContainer/VBoxContainer/SelectionText")
	if selection_text == null:
		panel.queue_free()
		return {"ok": false, "message": "SelectionText missing"}
	if selection_text.custom_minimum_size.y < 96.0:
		panel.queue_free()
		return {"ok": false, "message": "SelectionText height is too small"}
	panel.queue_free()
	return {"ok": true}


func _test_debug_panel_root_ignores_mouse() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	if panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		panel.queue_free()
		return {"ok": false, "message": "debug panel root must not consume map click input"}
	panel.queue_free()
	return {"ok": true}
