extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("main scene embeds hidden content alpha workbench", _test_main_embeds_hidden_workbench)
	_run("main scene toggles content alpha workbench from debug signal", _test_main_toggles_workbench)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_main_embeds_hidden_workbench() -> Dictionary:
	var main := _instantiate_main()
	if not main.ok:
		return main
	var root: Node3D = main.node
	var workbench := root.get_node_or_null("CanvasLayer/ContentAlphaWorkbench")
	if workbench == null:
		root.queue_free()
		return {"ok": false, "message": "main content alpha workbench missing"}
	if workbench.visible:
		root.queue_free()
		return {"ok": false, "message": "content alpha workbench must be hidden by default"}
	root.queue_free()
	return {"ok": true}


func _test_main_toggles_workbench() -> Dictionary:
	var main := _instantiate_main()
	if not main.ok:
		return main
	var root = main.node
	var workbench = root.get_node("CanvasLayer/ContentAlphaWorkbench")
	root._on_content_alpha_workbench_requested()
	if not workbench.visible:
		root.queue_free()
		return {"ok": false, "message": "content alpha workbench did not open"}
	if not workbench.get_validation_summary_text().contains("图池=212 候选=212"):
		root.queue_free()
		return {"ok": false, "message": "content alpha workbench did not load summary"}
	root._on_content_alpha_workbench_requested()
	if workbench.visible:
		root.queue_free()
		return {"ok": false, "message": "content alpha workbench did not close"}
	root.queue_free()
	return {"ok": true}


func _instantiate_main() -> Dictionary:
	var scene := load("res://scenes/main.tscn")
	if scene == null:
		return {"ok": false, "message": "main scene missing"}
	var main: Node3D = scene.instantiate()
	get_root().add_child(main)
	return {
		"ok": true,
		"node": main,
	}
