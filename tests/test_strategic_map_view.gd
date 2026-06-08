extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const StrategicMapView = preload("res://scripts/map/strategic_map_view.gd")


var _failed := 0


func _initialize() -> void:
	_run("strategic map renders cities routes and army markers", _test_renders_runtime_state)
	_run("strategic map fails when city position is missing", _test_missing_city_position_fails)
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
