extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const StrategicMapView = preload("res://scripts/map/strategic_map_view.gd")


var _failed := 0


func _initialize() -> void:
	_run("strategic map renders cities routes and army markers", _test_renders_runtime_state)
	_run("strategic map uses readable city and army labels", _test_readable_map_labels)
	_run("strategic map exposes pass route and blocked passage markers", _test_pass_route_visual_state)
	_run("strategic map exposes selectable city and army hit areas", _test_selectable_hit_areas)
	_run("strategic map emits selection for rendered entities", _test_selection_signal)
	_run("strategic map fails when city position is missing", _test_missing_city_position_fails)
	_run("strategic map rejects broken force and commander labels", _test_broken_label_references_fail)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_renders_runtime_state() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var view := StrategicMapView.new()
	get_root().add_child(view)
	var render_result: Dictionary = view.render_state(state_result.state)
	if not render_result.ok:
		view.queue_free()
		return {"ok": false, "message": "render failed: %s" % [render_result.errors]}
	var generated := view.get_node_or_null("GeneratedStrategicMap")
	if generated == null:
		view.queue_free()
		return {"ok": false, "message": "generated map root missing"}
	if generated.get_node_or_null("City_CITY_TEST_A") == null:
		view.queue_free()
		return {"ok": false, "message": "city marker missing"}
	if generated.get_node_or_null("Route_ROUTE_TEST_A_B") == null:
		view.queue_free()
		return {"ok": false, "message": "route marker missing"}
	if generated.get_node_or_null("Army_ARMY_1") == null:
		view.queue_free()
		return {"ok": false, "message": "army marker missing"}
	view.queue_free()
	return {"ok": true}


func _test_selectable_hit_areas() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var view := StrategicMapView.new()
	get_root().add_child(view)
	var render_result: Dictionary = view.render_state(state_result.state)
	if not render_result.ok:
		view.queue_free()
		return {"ok": false, "message": "render failed: %s" % [render_result.errors]}
	var generated := view.get_node_or_null("GeneratedStrategicMap")
	if generated == null:
		view.queue_free()
		return {"ok": false, "message": "generated map root missing"}
	var city_hit := generated.get_node_or_null("City_CITY_TEST_A/HitArea")
	if city_hit == null:
		view.queue_free()
		return {"ok": false, "message": "city hit area missing"}
	if str(city_hit.get_meta("map_entity_type", "")) != "city" or str(city_hit.get_meta("map_entity_id", "")) != "CITY_TEST_A":
		view.queue_free()
		return {"ok": false, "message": "city hit area metadata invalid"}
	var army_hit := generated.get_node_or_null("Army_ARMY_1/HitArea")
	if army_hit == null:
		view.queue_free()
		return {"ok": false, "message": "army hit area missing"}
	if str(army_hit.get_meta("map_entity_type", "")) != "army" or str(army_hit.get_meta("map_entity_id", "")) != "ARMY_1":
		view.queue_free()
		return {"ok": false, "message": "army hit area metadata invalid"}
	view.queue_free()
	return {"ok": true}


func _test_readable_map_labels() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var view := StrategicMapView.new()
	get_root().add_child(view)
	var render_result: Dictionary = view.render_state(state_result.state)
	if not render_result.ok:
		view.queue_free()
		return {"ok": false, "message": "render failed: %s" % [render_result.errors]}
	var generated := view.get_node_or_null("GeneratedStrategicMap")
	if generated == null:
		view.queue_free()
		return {"ok": false, "message": "generated map root missing"}
	var city_label := generated.get_node_or_null("City_CITY_TEST_A/Label") as Label3D
	var army_label := generated.get_node_or_null("Army_ARMY_1/Label") as Label3D
	if city_label == null or army_label == null:
		view.queue_free()
		return {"ok": false, "message": "expected city and army labels"}
	if not city_label.text.contains("玩家测试势力"):
		view.queue_free()
		return {"ok": false, "message": "city label should show readable force name: %s" % city_label.text}
	if not army_label.text.contains("测试主将"):
		view.queue_free()
		return {"ok": false, "message": "army label should show commander name: %s" % army_label.text}
	if city_label.text.contains("FORCE_PLAYER") or army_label.text.contains("ARMY_1") or army_label.text.contains("OFF_TEST_PLAYER"):
		view.queue_free()
		return {"ok": false, "message": "map labels still expose raw ids: %s / %s" % [city_label.text, army_label.text]}
	view.queue_free()
	return {"ok": true}


func _test_selection_signal() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var view := StrategicMapView.new()
	get_root().add_child(view)
	view.render_state(state_result.state)
	var emitted: Array[Dictionary] = []
	view.map_entity_selected.connect(func(selection: Dictionary) -> void:
		emitted.append(selection.duplicate(true))
	)
	var select_result: Dictionary = view.select_entity("city", "CITY_TEST_A")
	if not select_result.ok:
		view.queue_free()
		return {"ok": false, "message": "selection failed: %s" % [select_result.errors]}
	if emitted.size() != 1:
		view.queue_free()
		return {"ok": false, "message": "selection signal was not emitted once"}
	if emitted[0].type != "city" or emitted[0].id != "CITY_TEST_A":
		view.queue_free()
		return {"ok": false, "message": "selection payload invalid"}
	if view.get_current_selection().id != "CITY_TEST_A":
		view.queue_free()
		return {"ok": false, "message": "current selection not stored"}
	var missing_result: Dictionary = view.select_entity("army", "ARMY_MISSING")
	view.queue_free()
	if missing_result.ok:
		return {"ok": false, "message": "missing army selection should fail"}
	return {"ok": true}


func _test_pass_route_visual_state() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var view := StrategicMapView.new()
	get_root().add_child(view)
	var render_result: Dictionary = view.render_state(state_result.state)
	if not render_result.ok:
		view.queue_free()
		return {"ok": false, "message": "render failed: %s" % [render_result.errors]}
	var generated := view.get_node_or_null("GeneratedStrategicMap")
	if generated == null:
		view.queue_free()
		return {"ok": false, "message": "generated map root missing"}
	var road_route := generated.get_node_or_null("Route_ROUTE_TEST_A_B")
	var pass_route := generated.get_node_or_null("Route_ROUTE_TEST_A_B_PASS")
	if road_route == null or pass_route == null:
		view.queue_free()
		return {"ok": false, "message": "expected road and pass route nodes"}
	if str(pass_route.get_meta("route_type", "")) != "pass":
		view.queue_free()
		return {"ok": false, "message": "pass route missing route_type metadata"}
	if not bool(pass_route.get_meta("blocks_enemy_passage", false)):
		view.queue_free()
		return {"ok": false, "message": "blocked pass route missing block metadata"}
	if road_route.get_meta("route_visual_offset", Vector3.ZERO) == pass_route.get_meta("route_visual_offset", Vector3.ZERO):
		view.queue_free()
		return {"ok": false, "message": "road and pass routes share the same visual offset"}
	if pass_route.get_node_or_null("BlockMarker") == null:
		view.queue_free()
		return {"ok": false, "message": "blocked pass route marker missing"}
	view.queue_free()
	return {"ok": true}


func _test_broken_label_references_fail() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	var broken_force_state: Dictionary = state_result.state.duplicate(true)
	broken_force_state.forces.erase("FORCE_PLAYER")
	var force_view := StrategicMapView.new()
	get_root().add_child(force_view)
	var force_result: Dictionary = force_view.render_state(broken_force_state)
	force_view.queue_free()
	if force_result.ok:
		return {"ok": false, "message": "expected missing force to fail"}
	var found_force_error := false
	for error in force_result.errors:
		if str(error).contains("strategic map city force missing FORCE_PLAYER CITY_TEST_A"):
			found_force_error = true
	if not found_force_error:
		return {"ok": false, "message": "expected missing force error, got %s" % [force_result.errors]}

	var broken_commander_state: Dictionary = state_result.state.duplicate(true)
	broken_commander_state.officers.erase("OFF_TEST_PLAYER")
	var commander_view := StrategicMapView.new()
	get_root().add_child(commander_view)
	var commander_result: Dictionary = commander_view.render_state(broken_commander_state)
	commander_view.queue_free()
	if commander_result.ok:
		return {"ok": false, "message": "expected missing commander to fail"}
	for error in commander_result.errors:
		if str(error).contains("strategic map army commander missing OFF_TEST_PLAYER ARMY_1"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing commander error, got %s" % [commander_result.errors]}


func _test_missing_city_position_fails() -> Dictionary:
	var state_result := _build_state_with_army()
	if not state_result.ok:
		return state_result
	state_result.state.cities.CITY_TEST_C = {
		"id": "CITY_TEST_C",
		"name": "测试丙城",
		"force_id": "FORCE_ENEMY",
		"troops": 1000,
		"food": 1000,
		"public_order": 50,
		"morale_public": 50,
		"recovery_state": "normal",
	}
	var view := StrategicMapView.new()
	get_root().add_child(view)
	var render_result: Dictionary = view.render_state(state_result.state)
	view.queue_free()
	if render_result.ok:
		return {"ok": false, "message": "expected missing position failure"}
	for error in render_result.errors:
		if str(error).contains("strategic map missing city position CITY_TEST_C"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing position error, got %s" % [render_result.errors]}


func _build_state_with_army() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	var sortie: Dictionary = SortieSystem.create_sortie(
		state_result.state,
		"CITY_TEST_A",
		"OFF_TEST_PLAYER",
		"ROUTE_TEST_A_B",
		8000,
		16000
	)
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	var march: Dictionary = MarchSystem.start_march(state_result.state, sortie.army_id, 12.0, 1000)
	if not march.ok:
		return {"ok": false, "message": "march failed: %s" % [march.errors]}
	MarchSystem.advance_army_one_day(state_result.state, sortie.army_id)
	return {"ok": true, "state": state_result.state}
