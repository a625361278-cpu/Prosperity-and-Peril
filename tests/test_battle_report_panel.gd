extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const BattleReportPresenter = preload("res://scripts/ui/battle_report_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("battle report presenter builds real battle detail", _test_presenter_builds_detail)
	_run("battle report panel opens real battle log", _test_panel_opens_battle_log)
	_run("battle report panel exposes empty battle logs", _test_panel_exposes_empty_logs)
	_run("battle report panel rejects broken references", _test_panel_rejects_broken_references)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_presenter_builds_detail() -> Dictionary:
	var setup := _create_battle_state()
	if not setup.ok:
		return setup
	var result: Dictionary = BattleReportPresenter.build_report_detail(setup.state, "BATTLE_1")
	if not result.ok:
		return {"ok": false, "message": "expected battle report success, got %s" % [result.errors]}
	if not str(result.report.title).contains("测试乙城"):
		return {"ok": false, "message": "battle report title missing target city"}
	if not str(result.report.casualties).contains("进攻损失"):
		return {"ok": false, "message": "battle report missing casualties"}
	return {"ok": true}


func _test_panel_opens_battle_log() -> Dictionary:
	var setup := _create_battle_state()
	if not setup.ok:
		return setup
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_with_state(setup.state)
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected battle report panel open success, got %s" % [open_result.errors]}
	if panel.get_report_count() != 1:
		panel.queue_free()
		return {"ok": false, "message": "expected one battle report"}
	if not panel.get_summary_text().contains("进攻方胜利"):
		panel.queue_free()
		return {"ok": false, "message": "battle report summary mismatch"}
	panel.queue_free()
	return {"ok": true}


func _test_panel_exposes_empty_logs() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_with_state(state_result.state)
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "empty battle_logs should be a visible empty state"}
	if panel.get_report_count() != 0:
		panel.queue_free()
		return {"ok": false, "message": "expected no battle reports"}
	if not panel.get_message_text().contains("没有生成过战斗结果"):
		panel.queue_free()
		return {"ok": false, "message": "empty state message mismatch"}
	panel.queue_free()
	return {"ok": true}


func _test_panel_rejects_broken_references() -> Dictionary:
	var setup := _create_battle_state()
	if not setup.ok:
		return setup
	setup.state.armies.erase("ARMY_1")
	var result: Dictionary = BattleReportPresenter.build_report_detail(setup.state, "BATTLE_1")
	if result.ok:
		return {"ok": false, "message": "expected broken battle report reference to fail"}
	for error in result.errors:
		if str(error).contains("battle report army missing ARMY_1"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing army error, got %s" % [result.errors]}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/battle_report_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "battle report panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	return {"ok": true, "node": panel}


func _create_battle_state() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var sortie: Dictionary = SortieSystem.create_sortie(state_result.state, "CITY_TEST_A", "OFF_TEST_PLAYER", "ROUTE_TEST_A_B", 8000, 16000)
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	var march_result: Dictionary = MarchSystem.start_march(state_result.state, sortie.army_id, 12.0, 1000)
	if not march_result.ok:
		return {"ok": false, "message": "march start failed: %s" % [march_result.errors]}
	for _i in 5:
		var advance: Dictionary = MarchSystem.advance_army_one_day(state_result.state, sortie.army_id)
		if not advance.ok:
			return {"ok": false, "message": "march advance failed: %s" % [advance.errors]}
	var battle: Dictionary = BattleSystem.resolve_city_battle(state_result.state, sortie.army_id, "CITY_TEST_B")
	if not battle.ok:
		return {"ok": false, "message": "battle failed: %s" % [battle.errors]}
	return {"ok": true, "state": state_result.state}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "core data failed %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state build failed %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
