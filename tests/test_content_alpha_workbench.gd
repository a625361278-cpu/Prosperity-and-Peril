extends SceneTree


var _failed := 0


func _initialize() -> void:
	_run("content alpha workbench has expected panels", _test_workbench_nodes)
	_run("content alpha workbench loads default content", _test_workbench_loads_default_content)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_workbench_nodes() -> Dictionary:
	var panel := _instantiate_workbench()
	if not panel.ok:
		return panel
	var root: Control = panel.node
	if root.get_node_or_null("Root/ValidationSummary") == null:
		root.queue_free()
		return {"ok": false, "message": "workbench validation summary missing"}
	if root.get_node_or_null("Root/WorkbenchTabs/CandidateRoster/CandidateOfficerRosterBrowserPanel") == null:
		root.queue_free()
		return {"ok": false, "message": "workbench candidate browser missing"}
	if root.get_node_or_null("Root/WorkbenchTabs/PortraitPool/ReusableHeroPortraitBrowserPanel") == null:
		root.queue_free()
		return {"ok": false, "message": "workbench portrait browser missing"}
	if root.get_tab_count() != 2:
		root.queue_free()
		return {"ok": false, "message": "workbench expected two tabs"}
	root.queue_free()
	return {"ok": true}


func _test_workbench_loads_default_content() -> Dictionary:
	var panel := _instantiate_workbench()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.load_default_workbench()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected workbench load success, got %s" % [result.errors]}
	if root.get_candidate_item_count() != 212:
		root.queue_free()
		return {"ok": false, "message": "expected 212 candidate items"}
	if root.get_portrait_item_count() != 212:
		root.queue_free()
		return {"ok": false, "message": "expected 212 portrait items"}
	var summary: String = root.get_validation_summary_text()
	if not summary.contains("图池=212 候选=212 源绑定=426"):
		root.queue_free()
		return {"ok": false, "message": "workbench summary missing content alpha counts"}
	if not summary.contains("CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1001 刘备"):
		root.queue_free()
		return {"ok": false, "message": "workbench summary missing first candidate"}
	root.queue_free()
	return {"ok": true}


func _instantiate_workbench() -> Dictionary:
	var scene := load("res://scenes/content_alpha_workbench.tscn")
	if scene == null:
		return {"ok": false, "message": "content alpha workbench scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
