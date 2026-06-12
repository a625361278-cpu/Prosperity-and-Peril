extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const FormalHudPresenter = preload("res://scripts/ui/formal_hud_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("formal hud has expected layout nodes", _test_formal_hud_nodes)
	_run("formal hud loads real runtime state", _test_formal_hud_loads_state)
	_run("formal hud updates selected city", _test_formal_hud_city_selection)
	_run("formal hud rejects missing state", _test_formal_hud_rejects_missing_state)
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
		"RightPanel/MarginContainer/VBoxContainer/SelectionTitle",
		"RightPanel/MarginContainer/VBoxContainer/SelectionBody",
		"BottomCommandBar/MarginContainer/CommandButtons",
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
		if not button.disabled:
			root.queue_free()
			return {"ok": false, "message": "formal hud command must stay disabled before real screen implementation"}
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
	return {"ok": true, "state": state_result.state}
