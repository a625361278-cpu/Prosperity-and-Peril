extends Node3D

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")

@onready var _map_view: Node = $StrategicMapView
@onready var _formal_hud: Control = $CanvasLayer/FormalHud
@onready var _debug_panel: Control = $CanvasLayer/DebugPanel
@onready var _content_alpha_workbench: Control = $CanvasLayer/ContentAlphaWorkbench

var _runtime_state: Dictionary = {}
var _base_dataset: Dictionary = {}


func _ready() -> void:
	var state_result := _build_visual_slice_state()
	if not state_result.ok:
		push_error("Prototype visual slice failed: %s" % [state_result.errors])
		return
	_runtime_state = state_result.state
	_base_dataset = state_result.dataset
	if not _map_view.is_connected("map_entity_selected", _on_map_entity_selected):
		_map_view.connect("map_entity_selected", _on_map_entity_selected)
	if not _debug_panel_node().is_connected("content_alpha_workbench_requested", _on_content_alpha_workbench_requested):
		_debug_panel_node().connect("content_alpha_workbench_requested", _on_content_alpha_workbench_requested)
	if not _formal_hud_node().is_connected("runtime_state_replaced", _on_runtime_state_replaced):
		_formal_hud_node().connect("runtime_state_replaced", _on_runtime_state_replaced)
	var render_result: Dictionary = _map_view.render_state(state_result.state)
	if not render_result.ok:
		push_error("Strategic map render failed: %s" % [render_result.errors])
		return
	var base_dataset_result: Dictionary = _formal_hud_node().set_base_dataset(_base_dataset)
	if not base_dataset_result.ok:
		push_error("Formal HUD base dataset failed: %s" % [base_dataset_result.errors])
		return
	var hud_result: Dictionary = _formal_hud_node().set_runtime_state(state_result.state)
	if not hud_result.ok:
		push_error("Formal HUD failed: %s" % [hud_result.errors])
		return
	_debug_panel_node().set_runtime_state(state_result.state)
	print("三国志：治世与乱世 Prototype V0.3 visual slice booted.")


func _on_map_entity_selected(selection: Dictionary) -> void:
	if _runtime_state.is_empty():
		push_error("map selection received before runtime state was initialized")
		return
	var hud_result: Dictionary = _formal_hud_node().set_map_selection(_runtime_state, selection)
	if not hud_result.ok:
		push_error("Formal HUD selection failed: %s" % [hud_result.errors])
	_debug_panel_node().set_map_selection(_runtime_state, selection)


func _on_content_alpha_workbench_requested() -> void:
	var workbench := _content_alpha_workbench_node()
	workbench.visible = not workbench.visible
	if workbench.visible:
		var load_result: Dictionary = workbench.load_default_workbench()
		if not load_result.ok:
			push_error("Content Alpha workbench failed: %s" % [load_result.errors])


func _on_runtime_state_replaced(state: Dictionary) -> void:
	if state.is_empty():
		push_error("runtime state replacement cannot be empty")
		return
	_runtime_state = state
	var render_result: Dictionary = _map_view.render_state(_runtime_state)
	if not render_result.ok:
		push_error("Strategic map render after load failed: %s" % [render_result.errors])
	_debug_panel_node().set_runtime_state(_runtime_state)


func _content_alpha_workbench_node() -> Control:
	if _content_alpha_workbench != null:
		return _content_alpha_workbench
	return get_node("CanvasLayer/ContentAlphaWorkbench") as Control


func _formal_hud_node() -> Control:
	if _formal_hud != null:
		return _formal_hud
	return get_node("CanvasLayer/FormalHud") as Control


func _debug_panel_node() -> Control:
	if _debug_panel != null:
		return _debug_panel
	return get_node("CanvasLayer/DebugPanel") as Control


func _build_visual_slice_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "errors": loaded.errors, "state": {}}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "errors": state_result.errors, "state": {}}

	var sortie: Dictionary = SortieSystem.create_sortie(
		state_result.state,
		"CITY_TEST_A",
		"OFF_TEST_PLAYER",
		"ROUTE_TEST_A_B",
		8000,
		16000
	)
	if not sortie.ok:
		return {"ok": false, "errors": sortie.errors, "state": {}}
	var march: Dictionary = MarchSystem.start_march(state_result.state, sortie.army_id, 12.0, 1000)
	if not march.ok:
		return {"ok": false, "errors": march.errors, "state": {}}
	for _i in 2:
		var advance: Dictionary = MarchSystem.advance_army_one_day(state_result.state, sortie.army_id)
		if not advance.ok:
			return {"ok": false, "errors": advance.errors, "state": {}}
	return {"ok": true, "errors": [], "state": state_result.state, "dataset": loaded.dataset}
