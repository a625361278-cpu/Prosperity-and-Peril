extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("hero portrait preview panel has text and image nodes", _test_panel_nodes)
	_run("hero portrait preview panel formats rows and texture", _test_panel_setters)
	_run("hero portrait preview panel loads default audited portrait", _test_panel_loads_default_preview)
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
	var text := root.get_node_or_null("PortraitPreviewText")
	var validation_text := root.get_node_or_null("ContentAlphaValidationText")
	var image := root.get_node_or_null("PortraitPreviewImage")
	if text == null or validation_text == null or image == null:
		root.queue_free()
		return {"ok": false, "message": "portrait preview panel nodes missing"}
	if image.texture != null:
		root.queue_free()
		return {"ok": false, "message": "portrait preview panel must not start with default texture"}
	root.queue_free()
	return {"ok": true}


func _test_panel_setters() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root: VBoxContainer = panel.node
	root.set_preview_rows([
		{"hero_id": 2000501, "name_cn": "赵云", "half_body": "UI_gj_gg_basemap_hero_1004"},
	])
	var text: Label = root.get_node("PortraitPreviewText")
	if not text.text.contains("2000501 赵云 halfBody=UI_gj_gg_basemap_hero_1004"):
		root.queue_free()
		return {"ok": false, "message": "panel did not format audited portrait row"}
	root.set_validation_summary({
		"pack_id": "candidate_hero_portraits",
		"indexed_heroes": 426,
		"preview_rows": 3,
		"first_hero_id": 1001,
		"first_hero_name_cn": "刘备",
		"first_texture_width": 1300,
		"first_texture_height": 1080,
	})
	var validation_text: Label = root.get_node("ContentAlphaValidationText")
	if not validation_text.text.contains("资源包=candidate_hero_portraits 英雄=426 预览=3 首图=1001 刘备 1300x1080"):
		root.queue_free()
		return {"ok": false, "message": "panel did not format content alpha validation summary"}
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 1.0, 0.0, 1.0))
	root.set_preview_texture(ImageTexture.create_from_image(image))
	var preview_image: TextureRect = root.get_node("PortraitPreviewImage")
	if preview_image.texture == null:
		root.queue_free()
		return {"ok": false, "message": "panel did not set preview texture"}
	root.clear_preview_texture()
	if preview_image.texture != null:
		root.queue_free()
		return {"ok": false, "message": "panel did not clear preview texture"}
	root.queue_free()
	return {"ok": true}


func _test_panel_loads_default_preview() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root: VBoxContainer = panel.node
	var result: Dictionary = root.load_default_preview()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected default preview load success, got %s" % [result.errors]}
	var text: Label = root.get_node("PortraitPreviewText")
	var image: TextureRect = root.get_node("PortraitPreviewImage")
	if not text.text.contains("1001 刘备 halfBody=UI_gj_gg_basemap_hero_1001"):
		root.queue_free()
		return {"ok": false, "message": "default preview text missing first audited row"}
	var validation_text: Label = root.get_node("ContentAlphaValidationText")
	if not validation_text.text.contains("资源包=candidate_hero_portraits 英雄=426 预览=3 首图=1001 刘备 1300x1080"):
		root.queue_free()
		return {"ok": false, "message": "default preview validation summary missing"}
	if image.texture == null:
		root.queue_free()
		return {"ok": false, "message": "default preview image texture missing"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/hero_portrait_preview_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "hero portrait preview panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
