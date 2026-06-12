extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const AppointmentSortiePresenter = preload("res://scripts/ui/appointment_sortie_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("appointment sortie presenter builds real city form", _test_presenter_builds_form)
	_run("appointment sortie panel appoints governor", _test_panel_appoints_governor)
	_run("appointment sortie panel creates sortie", _test_panel_creates_sortie)
	_run("appointment sortie panel exposes invalid state", _test_panel_exposes_invalid_state)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_presenter_builds_form() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = AppointmentSortiePresenter.build_form(state_result.state, "CITY_TEST_A")
	if not result.ok:
		return {"ok": false, "message": "expected form build success, got %s" % [result.errors]}
	if str(result.form.city_summary).contains("测试甲城") == false:
		return {"ok": false, "message": "city summary missing real city"}
	if result.form.officers.size() != 1:
		return {"ok": false, "message": "expected one eligible player officer"}
	if result.form.routes.size() != 2:
		return {"ok": false, "message": "expected two routes from CITY_TEST_A"}
	return {"ok": true}


func _test_panel_appoints_governor() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_for_city(state_result.state, "CITY_TEST_A")
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected panel open success, got %s" % [open_result.errors]}
	var appoint_result: Dictionary = panel.appoint_selected_governor()
	if not appoint_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected appointment success, got %s" % [appoint_result.errors]}
	if str(state_result.state.cities.CITY_TEST_A.governor_officer_id) != "OFF_TEST_PLAYER":
		panel.queue_free()
		return {"ok": false, "message": "governor was not written to runtime state"}
	if not panel.get_message_text().contains("任命完成"):
		panel.queue_free()
		return {"ok": false, "message": "panel did not show appointment result"}
	panel.queue_free()
	return {"ok": true}


func _test_panel_creates_sortie() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_for_city(state_result.state, "CITY_TEST_A")
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected panel open success, got %s" % [open_result.errors]}
	var sortie_result: Dictionary = panel.create_sortie_from_inputs()
	if not sortie_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected sortie success, got %s" % [sortie_result.errors]}
	if str(sortie_result.army_id) != "ARMY_1":
		panel.queue_free()
		return {"ok": false, "message": "expected ARMY_1, got %s" % str(sortie_result.army_id)}
	if not state_result.state.armies.has("ARMY_1"):
		panel.queue_free()
		return {"ok": false, "message": "sortie did not create runtime army"}
	if str(state_result.state.armies.ARMY_1.state) != "marching":
		panel.queue_free()
		return {"ok": false, "message": "sortie panel should start march for playable slice"}
	if not state_result.state.armies.ARMY_1.has("days_required"):
		panel.queue_free()
		return {"ok": false, "message": "march metadata missing after sortie"}
	if int(state_result.state.cities.CITY_TEST_A.troops) != 19000:
		panel.queue_free()
		return {"ok": false, "message": "city troop deduction mismatch: %s" % str(state_result.state.cities.CITY_TEST_A.troops)}
	if int(state_result.state.cities.CITY_TEST_A.food) != 49000:
		panel.queue_free()
		return {"ok": false, "message": "city food deduction mismatch: %s" % str(state_result.state.cities.CITY_TEST_A.food)}
	panel.queue_free()
	return {"ok": true}


func _test_panel_exposes_invalid_state() -> Dictionary:
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var result: Dictionary = panel.open_for_city({"current_day": 1}, "CITY_TEST_A")
	if result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected invalid state to fail"}
	if not panel.get_message_text().contains("appointment sortie missing state key cities"):
		panel.queue_free()
		return {"ok": false, "message": "panel did not expose missing state key"}
	panel.queue_free()
	return {"ok": true}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/appointment_sortie_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "appointment sortie panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	return {"ok": true, "node": panel}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "core data failed %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state build failed %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
