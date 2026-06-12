extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const SaveLoadPresenter = preload("res://scripts/ui/save_load_presenter.gd")

const SAVE_PATH := "user://content_alpha_save_load_panel_test.json"
const MISSING_PATH := "user://content_alpha_save_load_panel_missing.json"

var _failed := 0


func _initialize() -> void:
	_cleanup(SAVE_PATH)
	_cleanup(MISSING_PATH)
	_run("save load panel shows runtime summary", _test_panel_shows_summary)
	_run("save load panel saves and loads real state", _test_panel_saves_and_loads_state)
	_run("save load presenter rejects missing base dataset", _test_presenter_rejects_missing_base_dataset)
	_run("save load presenter rejects missing state key", _test_presenter_rejects_missing_state_key)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_panel_shows_summary() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var open_result: Dictionary = root.open_with_state(setup.state, setup.dataset, SAVE_PATH)
	if not open_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected panel open success, got %s" % [open_result.errors]}
	if not root.get_summary_text().contains("当前: 第 0 日 / 第 1 月"):
		root.queue_free()
		return {"ok": false, "message": "runtime summary mismatch"}
	if not root.get_save_file_text().contains("不存在"):
		root.queue_free()
		return {"ok": false, "message": "missing save file summary mismatch"}
	if not root.get_save_path_text().contains(SAVE_PATH):
		root.queue_free()
		return {"ok": false, "message": "save path label mismatch"}
	root.queue_free()
	return {"ok": true}


func _test_panel_saves_and_loads_state() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var march_result: Dictionary = _create_marching_army(setup.state)
	if not march_result.ok:
		return march_result
	setup.state.current_day = 12
	var panel := _instantiate_panel()
	if not panel.ok:
		return panel
	var root = panel.node
	var open_result: Dictionary = root.open_with_state(setup.state, setup.dataset, SAVE_PATH)
	if not open_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected panel open success"}
	var save_result: Dictionary = root.save_current_state()
	if not save_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected save success, got %s" % [save_result.errors]}
	if not FileAccess.file_exists(SAVE_PATH):
		root.queue_free()
		return {"ok": false, "message": "save file was not written"}
	setup.state.current_day = 99
	setup.state.armies.ARMY_1.food_current = 1
	var signal_capture := {"state": {}}
	root.state_loaded.connect(func(state): signal_capture.state = state)
	var load_result: Dictionary = root.load_saved_state()
	if not load_result.ok:
		root.queue_free()
		return {"ok": false, "message": "expected load success, got %s" % [load_result.errors]}
	if (signal_capture.state as Dictionary).is_empty():
		root.queue_free()
		return {"ok": false, "message": "state_loaded signal did not emit"}
	var loaded_state: Dictionary = signal_capture.state
	if int(loaded_state.current_day) != 12:
		root.queue_free()
		return {"ok": false, "message": "loaded day mismatch"}
	if int(loaded_state.armies.ARMY_1.food_current) == 1:
		root.queue_free()
		return {"ok": false, "message": "loaded army still has mutated value"}
	root.queue_free()
	return {"ok": true}


func _test_presenter_rejects_missing_base_dataset() -> Dictionary:
	var result: Dictionary = SaveLoadPresenter.load_state({}, MISSING_PATH)
	return _expect_error_contains(result, "base dataset is empty")


func _test_presenter_rejects_missing_state_key() -> Dictionary:
	var setup := _build_state()
	if not setup.ok:
		return setup
	var copied: Dictionary = setup.state.duplicate(true)
	copied.erase("cities")
	var result: Dictionary = SaveLoadPresenter.build_summary(copied, SAVE_PATH)
	return _expect_error_contains(result, "save load state missing key cities")


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/save_load_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "save load panel scene missing"}
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
	return {"ok": true, "state": state_result.state, "dataset": loaded.dataset}


func _create_marching_army(state: Dictionary) -> Dictionary:
	var sortie: Dictionary = SortieSystem.create_sortie(state, "CITY_TEST_A", "OFF_TEST_PLAYER", "ROUTE_TEST_A_B", 8000, 16000)
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	var march_result: Dictionary = MarchSystem.start_march(state, sortie.army_id, 12.0, 1000)
	if not march_result.ok:
		return {"ok": false, "message": "march start failed: %s" % [march_result.errors]}
	return {"ok": true}


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
