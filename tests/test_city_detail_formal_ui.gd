extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const CityDetailPresenter = preload("res://scripts/ui/city_detail_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("city detail presenter exposes formal sections and force summary", _test_presenter_formal_sections)
	_run("city detail presenter exposes missing data gaps", _test_presenter_data_gaps)
	_run("city detail panel renders missing data gaps", _test_panel_renders_data_gaps)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_presenter_formal_sections() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var result: Dictionary = CityDetailPresenter.build_detail(setup.state, "CITY_TEST_A")
	if not result.ok:
		return {"ok": false, "message": "expected city detail success, got %s" % [result.errors]}
	var detail: Dictionary = result.detail
	for key in ["force_summary_text", "section_order", "resource_section_title", "governance_section_title", "officer_section_title", "action_section_title"]:
		if not detail.has(key):
			return {"ok": false, "message": "formal city detail missing %s" % key}
	if str(detail.force_summary_text) != "势力 玩家测试势力  正统 62  名望 48":
		return {"ok": false, "message": "force summary did not use real force state: %s" % str(detail.force_summary_text)}
	if detail.section_order != ["resource", "governance", "officer", "actions", "data_gaps"]:
		return {"ok": false, "message": "unexpected formal section order %s" % [detail.section_order]}
	return {"ok": true}


func _test_presenter_data_gaps() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var result: Dictionary = CityDetailPresenter.build_detail(setup.state, "CITY_TEST_A")
	if not result.ok:
		return {"ok": false, "message": "expected city detail success, got %s" % [result.errors]}
	var gaps: Array = result.detail.get("data_gap_rows", [])
	for expected in ["兵力上限", "粮草上限", "资源产量", "建筑列表"]:
		if not _contains_gap(gaps, expected):
			return {"ok": false, "message": "missing expected data gap %s in %s" % [expected, gaps]}
	var copied: Dictionary = setup.state.duplicate(true)
	copied.cities.CITY_TEST_A.troop_capacity = 30000
	copied.cities.CITY_TEST_A.food_capacity = 70000
	copied.cities.CITY_TEST_A.resource_yield = {"gold": 120}
	copied.cities.CITY_TEST_A.buildings = ["官府"]
	var filled: Dictionary = CityDetailPresenter.build_detail(copied, "CITY_TEST_A")
	if not filled.ok:
		return {"ok": false, "message": "expected filled city detail success, got %s" % [filled.errors]}
	if not filled.detail.data_gap_rows.is_empty():
		return {"ok": false, "message": "filled optional fields should clear formal gaps, got %s" % [filled.detail.data_gap_rows]}
	return {"ok": true}


func _test_panel_renders_data_gaps() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var scene := load("res://scenes/city_detail_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "city detail panel scene missing"}
	var panel = scene.instantiate()
	get_root().add_child(panel)
	var show_result: Dictionary = panel.show_city(setup.state, "CITY_TEST_A")
	if not show_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected panel show success, got %s" % [show_result.errors]}
	var gap_text: String = panel.get_data_gap_text()
	panel.queue_free()
	if not gap_text.contains("数据缺口") or not gap_text.contains("兵力上限"):
		return {"ok": false, "message": "panel did not render data gaps: %s" % gap_text}
	return {"ok": true}


func _contains_gap(gaps: Array, label: String) -> bool:
	for gap in gaps:
		if gap is Dictionary and str(gap.get("label", "")) == label:
			return true
	return false


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "core data failed %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state build failed %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
