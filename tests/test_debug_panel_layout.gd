extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("debug panel keeps a readable right-side layout", _test_debug_panel_readable_layout)
	_run("debug panel exposes a dedicated selection text area", _test_debug_panel_selection_area)
	_run("debug panel transparent root does not block map clicks", _test_debug_panel_root_ignores_mouse)
	_run("debug panel exposes content alpha portrait preview area", _test_debug_panel_portrait_preview_area)
	_run("debug panel formats portrait preview rows", _test_debug_panel_formats_portrait_preview)
	_run("debug panel exposes portrait texture preview node", _test_debug_panel_portrait_texture_node)
	_run("debug panel can assign and clear portrait texture", _test_debug_panel_assigns_portrait_texture)
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


func _test_debug_panel_portrait_preview_area() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	var preview_text := panel.get_node_or_null("PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel/PortraitPreviewText")
	if preview_text == null:
		panel.queue_free()
		return {"ok": false, "message": "PortraitPreviewText missing"}
	if preview_text.custom_minimum_size.y < 80.0:
		panel.queue_free()
		return {"ok": false, "message": "PortraitPreviewText height is too small"}
	panel.queue_free()
	return {"ok": true}


func _test_debug_panel_formats_portrait_preview() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	panel.set_portrait_preview_rows([
		{"hero_id": 1001, "name_cn": "刘备", "half_body": "UI_gj_gg_basemap_hero_1001"},
		{"hero_id": 2000501, "name_cn": "赵云", "half_body": "UI_gj_gg_basemap_hero_1004"},
	])
	var preview_text: Label = panel.get_node("PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel/PortraitPreviewText")
	if not preview_text.text.contains("1001 刘备 halfBody=UI_gj_gg_basemap_hero_1001"):
		panel.queue_free()
		return {"ok": false, "message": "portrait preview missing 刘备 row"}
	if not preview_text.text.contains("2000501 赵云 halfBody=UI_gj_gg_basemap_hero_1004"):
		panel.queue_free()
		return {"ok": false, "message": "portrait preview missing audited 赵云 mapping"}
	panel.queue_free()
	return {"ok": true}


func _test_debug_panel_portrait_texture_node() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	var preview_image := panel.get_node_or_null("PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel/PortraitPreviewImage")
	if preview_image == null:
		panel.queue_free()
		return {"ok": false, "message": "PortraitPreviewImage missing"}
	if preview_image.custom_minimum_size.x < 120.0 or preview_image.custom_minimum_size.y < 100.0:
		panel.queue_free()
		return {"ok": false, "message": "PortraitPreviewImage minimum size is too small"}
	if preview_image.texture != null:
		panel.queue_free()
		return {"ok": false, "message": "PortraitPreviewImage must not start with a default texture"}
	panel.queue_free()
	return {"ok": true}


func _test_debug_panel_assigns_portrait_texture() -> Dictionary:
	var scene := load("res://scenes/debug_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "debug panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.0, 0.0, 1.0))
	var texture := ImageTexture.create_from_image(image)
	panel.set_portrait_preview_texture(texture)
	var preview_image: TextureRect = panel.get_node("PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel/PortraitPreviewImage")
	if preview_image.texture == null:
		panel.queue_free()
		return {"ok": false, "message": "portrait preview texture was not assigned"}
	panel.clear_portrait_preview_texture()
	if preview_image.texture != null:
		panel.queue_free()
		return {"ok": false, "message": "portrait preview texture was not cleared"}
	panel.queue_free()
	return {"ok": true}
