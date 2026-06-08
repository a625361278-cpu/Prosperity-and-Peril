extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("debug panel keeps a readable right-side layout", _test_debug_panel_readable_layout)
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
	var text := panel.get_node_or_null("PanelBackground/MarginContainer/ScrollContainer/DebugText")
	if text == null:
		panel.queue_free()
		return {"ok": false, "message": "debug text path missing"}
	if text.custom_minimum_size.x < 360.0:
		panel.queue_free()
		return {"ok": false, "message": "debug text minimum width is too small"}
	panel.queue_free()
	return {"ok": true}
