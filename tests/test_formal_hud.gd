extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const AppointmentSystem = preload("res://scripts/simulation/appointment_system.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const CityDetailPresenter = preload("res://scripts/ui/city_detail_presenter.gd")
const FormalHudPresenter = preload("res://scripts/ui/formal_hud_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("formal hud has expected layout nodes", _test_formal_hud_nodes)
	_run("formal hud loads real runtime state", _test_formal_hud_loads_state)
	_run("formal hud updates selected city", _test_formal_hud_city_selection)
	_run("formal hud opens battle report command", _test_formal_hud_battle_report_command)
	_run("formal hud opens event log command", _test_formal_hud_event_log_command)
	_run("formal hud opens save load command", _test_formal_hud_save_load_command)
	_run("formal hud rejects missing state", _test_formal_hud_rejects_missing_state)
	_run("formal hud rejects missing ruler officer", _test_formal_hud_rejects_missing_ruler_officer)
	_run("city detail presenter exposes governor and rejects missing force", _test_city_detail_presenter)
	_run("city detail presenter rejects missing city fields", _test_city_detail_presenter_rejects_missing_city_field)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_formal_hud_nodes() -> Dictionary:
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root: Control = hud.node
	for path in [
		"TopBar/MarginContainer/HBoxContainer/DateLabel",
		"TopBar/MarginContainer/HBoxContainer/ForceSummaryLabel",
		"LeftPanel/MarginContainer/VBoxContainer/ObjectiveValue",
		"LeftPanel/MarginContainer/VBoxContainer/EventValue",
		"OfficerPanel/MarginContainer/HBoxContainer/Portrait",
		"OfficerPanel/MarginContainer/HBoxContainer/OfficerText",
		"RightPanel/MarginContainer/VBoxContainer/SelectionTitle",
		"RightPanel/MarginContainer/VBoxContainer/SelectionBody",
		"RightPanel/MarginContainer/VBoxContainer/CityDetailPanel",
		"BottomCommandBar/MarginContainer/CommandButtons",
		"AppointmentSortiePanel",
		"BattleReportPanel",
		"EventLogPanel",
		"SaveLoadPanel",
	]:
		if root.get_node_or_null(path) == null:
			root.queue_free()
			return {"ok": false, "message": "formal hud missing node %s" % path}
	if root.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		root.queue_free()
		return {"ok": false, "message": "formal hud root must ignore mouse"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_loads_state() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root = hud.node
	var result: Dictionary = root.set_runtime_state(state_result.state)
	if not result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal hud load success, got %s" % [result.errors]}
	if root.get_command_count() != 5:
		root.queue_free()
		return {"ok": false, "message": "formal hud expected five command buttons"}
	var command_bar: HBoxContainer = root.get_node("BottomCommandBar/MarginContainer/CommandButtons")
	for button in command_bar.get_children():
		if str(button.get_meta("command_id", "")) in ["advance_day", "battle_report", "event_log", "save_load"]:
			if button.disabled:
				root.queue_free()
				return {"ok": false, "message": "available formal command should be enabled"}
			continue
		if not button.disabled:
			root.queue_free()
			return {"ok": false, "message": "unfinished formal hud command must stay disabled"}
	if not root.get_command_enabled("battle_report"):
		root.queue_free()
		return {"ok": false, "message": "battle report command getter mismatch"}
	if not root.get_command_enabled("event_log"):
		root.queue_free()
		return {"ok": false, "message": "event log command getter mismatch"}
	if not root.get_command_enabled("save_load"):
		root.queue_free()
		return {"ok": false, "message": "save load command getter mismatch"}
	if not root.get_playable_status_text().contains("目标:"):
		root.queue_free()
		return {"ok": false, "message": "playable status missing"}
	var officer_card_text: String = root.get_officer_card_text()
	if not officer_card_text.contains("测试主将") or not officer_card_text.contains("正统 62") or not officer_card_text.contains("名望 48"):
		root.queue_free()
		return {"ok": false, "message": "leader card did not use real runtime state: %s" % officer_card_text}
	if officer_card_text.contains("刘备") or officer_card_text.contains("1800/3000"):
		root.queue_free()
		return {"ok": false, "message": "leader card still contains static placeholder data"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_city_selection() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root = hud.node
	var load_result: Dictionary = root.set_runtime_state(state_result.state)
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal hud load success"}
	var select_result: Dictionary = root.set_map_selection(state_result.state, {"type": "city", "id": "CITY_TEST_A"})
	if not select_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected city selection success, got %s" % [select_result.errors]}
	if not root.get_selection_title_text().contains("城市: 测试甲城"):
		root.queue_free()
		return {"ok": false, "message": "formal hud selection title mismatch"}
	if not root.get_city_detail_title_text().contains("测试甲城 / 玩家测试势力"):
		root.queue_free()
		return {"ok": false, "message": "formal hud city detail title mismatch"}
	if root.get_city_detail_action_count() != 2:
		root.queue_free()
		return {"ok": false, "message": "formal hud city detail action count mismatch"}
	var action_bar: HBoxContainer = root.get_node("RightPanel/MarginContainer/VBoxContainer/CityDetailPanel/ActionBar")
	for button in action_bar.get_children():
		if button.disabled:
			root.queue_free()
			return {"ok": false, "message": "city detail actions must open appointment sortie panel"}
	if not root.get_city_detail_action_enabled("appointment") or not root.get_city_detail_action_enabled("sortie"):
		root.queue_free()
		return {"ok": false, "message": "city detail action getter mismatch"}
	action_bar.get_child(0).emit_signal("pressed")
	if not root.is_appointment_sortie_panel_visible():
		root.queue_free()
		return {"ok": false, "message": "appointment sortie panel did not open from city detail"}
	var appoint_result: Dictionary = root.get_appointment_sortie_panel_node().appoint_selected_governor()
	if not appoint_result.ok:
		root.queue_free()
		return {"ok": false, "message": "hud appointment failed %s" % [appoint_result.errors]}
	if str(state_result.state.cities.CITY_TEST_A.governor_officer_id) != "OFF_TEST_PLAYER":
		root.queue_free()
		return {"ok": false, "message": "hud appointment did not mutate runtime state"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_battle_report_command() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var battle_result := _create_battle_log(state_result.state)
	if not battle_result.ok:
		return battle_result
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root = hud.node
	var load_result: Dictionary = root.set_runtime_state(state_result.state)
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal hud load success"}
	var command_bar: HBoxContainer = root.get_node("BottomCommandBar/MarginContainer/CommandButtons")
	for button in command_bar.get_children():
		if str(button.get_meta("command_id", "")) == "battle_report":
			button.emit_signal("pressed")
			break
	if not root.is_battle_report_panel_visible():
		root.queue_free()
		return {"ok": false, "message": "battle report panel did not open from command"}
	if root.get_battle_report_panel_node().get_report_count() != 1:
		root.queue_free()
		return {"ok": false, "message": "battle report panel did not load battle log"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_event_log_command() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root = hud.node
	var load_result: Dictionary = root.set_runtime_state(state_result.state)
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal hud load success"}
	var command_bar: HBoxContainer = root.get_node("BottomCommandBar/MarginContainer/CommandButtons")
	for button in command_bar.get_children():
		if str(button.get_meta("command_id", "")) == "event_log":
			button.emit_signal("pressed")
			break
	if not root.is_event_log_panel_visible():
		root.queue_free()
		return {"ok": false, "message": "event log panel did not open from command"}
	if root.get_event_log_panel_node().get_event_count() != 0:
		root.queue_free()
		return {"ok": false, "message": "new runtime state should have no event rows"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_save_load_command() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var hud := _instantiate_hud()
	if not hud.ok:
		return hud
	var root = hud.node
	var base_result: Dictionary = root.set_base_dataset(state_result.dataset)
	if not base_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected base dataset success, got %s" % [base_result.errors]}
	var load_result: Dictionary = root.set_runtime_state(state_result.state)
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected formal hud load success"}
	var command_bar: HBoxContainer = root.get_node("BottomCommandBar/MarginContainer/CommandButtons")
	for button in command_bar.get_children():
		if str(button.get_meta("command_id", "")) == "save_load":
			button.emit_signal("pressed")
			break
	if not root.is_save_load_panel_visible():
		root.queue_free()
		return {"ok": false, "message": "save load panel did not open from command"}
	if not root.get_save_load_panel_node().get_summary_text().contains("当前: 第 0 日 / 第 1 月"):
		root.queue_free()
		return {"ok": false, "message": "save load panel did not load runtime summary"}
	root.queue_free()
	return {"ok": true}


func _test_formal_hud_rejects_missing_state() -> Dictionary:
	var result: Dictionary = FormalHudPresenter.build_hud_state({"current_day": 1})
	if result.ok:
		return {"ok": false, "message": "expected missing state to fail"}
	for error in result.errors:
		if str(error).contains("formal hud missing state key cities"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing cities error, got %s" % [result.errors]}


func _test_formal_hud_rejects_missing_ruler_officer() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var copied: Dictionary = state_result.state.duplicate(true)
	copied.officers.erase("OFF_TEST_PLAYER")
	var result: Dictionary = FormalHudPresenter.build_hud_state(copied)
	if result.ok:
		return {"ok": false, "message": "expected missing ruler officer to fail"}
	for error in result.errors:
		if str(error).contains("formal hud ruler officer missing OFF_TEST_PLAYER"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing ruler officer error, got %s" % [result.errors]}


func _test_city_detail_presenter() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var appointment: Dictionary = AppointmentSystem.appoint_governor(state_result.state, "CITY_TEST_A", "OFF_TEST_PLAYER")
	if not appointment.ok:
		return {"ok": false, "message": "expected appointment success, got %s" % [appointment.errors]}
	var result: Dictionary = CityDetailPresenter.build_detail(state_result.state, "CITY_TEST_A")
	if not result.ok:
		return {"ok": false, "message": "expected city detail success, got %s" % [result.errors]}
	if not str(result.detail.governor_text).contains("测试主将"):
		return {"ok": false, "message": "city detail governor mismatch"}
	var copied: Dictionary = state_result.state.duplicate(true)
	copied.forces.erase("FORCE_PLAYER")
	var missing_force: Dictionary = CityDetailPresenter.build_detail(copied, "CITY_TEST_A")
	if missing_force.ok:
		return {"ok": false, "message": "expected city detail to reject missing force"}
	for error in missing_force.errors:
		if str(error).contains("city detail missing force FORCE_PLAYER"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing force error, got %s" % [missing_force.errors]}


func _test_city_detail_presenter_rejects_missing_city_field() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var copied: Dictionary = state_result.state.duplicate(true)
	copied.cities.CITY_TEST_A.erase("troops")
	var result: Dictionary = CityDetailPresenter.build_detail(copied, "CITY_TEST_A")
	if result.ok:
		return {"ok": false, "message": "expected city detail to reject missing troops"}
	for error in result.errors:
		if str(error).contains("city detail city CITY_TEST_A missing troops"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing troops error, got %s" % [result.errors]}


func _instantiate_hud() -> Dictionary:
	var scene := load("res://scenes/formal_hud.tscn")
	if scene == null:
		return {"ok": false, "message": "formal hud scene missing"}
	var hud: Control = scene.instantiate()
	get_root().add_child(hud)
	return {"ok": true, "node": hud}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "core data failed %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state build failed %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state, "dataset": loaded.dataset}


func _create_battle_log(state: Dictionary) -> Dictionary:
	var sortie: Dictionary = SortieSystem.create_sortie(state, "CITY_TEST_A", "OFF_TEST_PLAYER", "ROUTE_TEST_A_B", 8000, 16000)
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	var march_result: Dictionary = MarchSystem.start_march(state, sortie.army_id, 12.0, 1000)
	if not march_result.ok:
		return {"ok": false, "message": "march start failed: %s" % [march_result.errors]}
	for _i in 5:
		var advance: Dictionary = MarchSystem.advance_army_one_day(state, sortie.army_id)
		if not advance.ok:
			return {"ok": false, "message": "march advance failed: %s" % [advance.errors]}
	var battle: Dictionary = BattleSystem.resolve_city_battle(state, sortie.army_id, "CITY_TEST_B")
	if not battle.ok:
		return {"ok": false, "message": "battle failed: %s" % [battle.errors]}
	return {"ok": true}
