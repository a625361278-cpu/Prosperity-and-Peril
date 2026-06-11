extends SceneTree

const CandidateOfficerRosterLoader = preload("res://scripts/data/candidate_officer_roster_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("candidate officer roster browser has expected nodes", _test_browser_nodes)
	_run("candidate officer roster browser loads default roster", _test_loads_default_roster)
	_run("candidate officer roster browser filters selection status", _test_filters_selection_status)
	_run("candidate officer roster browser selects Zhao Yun candidate", _test_selects_zhao_yun_candidate)
	_run("candidate officer roster browser rejects missing portrait resource", _test_rejects_missing_resource)
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
	for node_name in ["StatusFilter", "RosterSummary", "CandidateList", "CandidateDetail", "CandidateImage"]:
		if root.get_node_or_null(node_name) == null:
			root.queue_free()
			return {"ok": false, "message": "candidate roster browser node missing %s" % node_name}
	var image: TextureRect = root.get_node("CandidateImage")
	if image.texture != null:
		root.queue_free()
		return {"ok": false, "message": "candidate roster browser must not start with default texture"}
	root.queue_free()
	return {"ok": true}


func _test_loads_default_roster() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.load_default_roster()
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected default roster load success, got %s" % [result.errors]}
	if root.get_item_count() != 212:
		root.queue_free()
		return {"ok": false, "message": "expected 212 candidate roster items"}
	if not root.get_summary_text().contains("总数=212 候选=212 已选=0 排除=0 当前显示=212"):
		root.queue_free()
		return {"ok": false, "message": "expected default summary counts"}
	if not root.get_selected_detail_text().contains("候选ID: CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1001"):
		root.queue_free()
		return {"ok": false, "message": "expected first candidate detail"}
	if not root.has_preview_texture():
		root.queue_free()
		return {"ok": false, "message": "expected first candidate texture"}
	root.queue_free()
	return {"ok": true}


func _test_filters_selection_status() -> Dictionary:
	var load_result: Dictionary = CandidateOfficerRosterLoader.load_default_roster()
	if not load_result.ok:
		return {"ok": false, "message": "expected candidate roster load success, got %s" % [load_result.errors]}
	var records: Array = load_result.records.duplicate(true)
	records[0].selection_status = "selected"
	records[1].selection_status = "rejected"
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var set_result: Dictionary = root.set_records(records)
	if not set_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected set records success, got %s" % [set_result.errors]}
	var selected_result: Dictionary = root.set_status_filter("selected")
	if not selected_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected selected filter success, got %s" % [selected_result.errors]}
	if root.get_item_count() != 1 or not root.get_summary_text().contains("已选=1"):
		root.queue_free()
		return {"ok": false, "message": "expected selected filter count"}
	var rejected_result: Dictionary = root.set_status_filter("rejected")
	if not rejected_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected rejected filter success, got %s" % [rejected_result.errors]}
	if root.get_item_count() != 1 or not root.get_summary_text().contains("排除=1"):
		root.queue_free()
		return {"ok": false, "message": "expected rejected filter count"}
	root.queue_free()
	return {"ok": true}


func _test_selects_zhao_yun_candidate() -> Dictionary:
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var load_result: Dictionary = root.load_default_roster()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected default roster load success, got %s" % [load_result.errors]}
	var select_result: Dictionary = root.select_candidate("CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1004")
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected select Zhao Yun candidate success, got %s" % [select_result.errors]}
	var detail: String = root.get_selected_detail_text()
	if not detail.contains("显示名: 赵云") or not detail.contains("源绑定: 2"):
		root.queue_free()
		return {"ok": false, "message": "expected Zhao Yun candidate detail with two source bindings"}
	root.queue_free()
	return {"ok": true}


func _test_rejects_missing_resource() -> Dictionary:
	var load_result: Dictionary = CandidateOfficerRosterLoader.load_default_roster()
	if not load_result.ok:
		return {"ok": false, "message": "expected candidate roster load success, got %s" % [load_result.errors]}
	var records: Array = load_result.records.duplicate(true)
	records[0].portrait_res_path = "res://assets/content_alpha/hero_portraits/missing_hero.png"
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var result: Dictionary = root.set_records(records)
	if result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected missing portrait resource to fail"}
	if not root.get_selected_detail_text().contains("imported file missing"):
		root.queue_free()
		return {"ok": false, "message": "expected missing imported resource detail"}
	root.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/candidate_officer_roster_browser_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "candidate officer roster browser panel scene missing"}
	var panel: VBoxContainer = scene.instantiate()
	get_root().add_child(panel)
	return {
		"ok": true,
		"node": panel,
	}
