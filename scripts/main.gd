extends Node3D

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const TimeSystem = preload("res://scripts/simulation/time_system.gd")

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
	if not _formal_hud_node().is_connected("advance_day_requested", _on_advance_day_requested):
		_formal_hud_node().connect("advance_day_requested", _on_advance_day_requested)
	var render_result: Dictionary = _map_view_node().render_state(state_result.state)
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
	var render_result: Dictionary = _map_view_node().render_state(_runtime_state)
	if not render_result.ok:
		push_error("Strategic map render after load failed: %s" % [render_result.errors])
	_debug_panel_node().set_runtime_state(_runtime_state)


func _on_advance_day_requested() -> void:
	if _runtime_state.is_empty():
		push_error("advance day requested before runtime state initialized")
		return
	var result: Dictionary = _advance_playable_day()
	if not result.ok:
		push_error("advance playable day failed: %s" % [result.errors])
		_formal_hud_node().set_playable_message("推进失败: %s" % "\n".join(result.errors))
		return
	var render_result: Dictionary = _map_view_node().render_state(_runtime_state)
	if not render_result.ok:
		push_error("Strategic map render after day advance failed: %s" % [render_result.errors])
		return
	var hud_result: Dictionary = _formal_hud_node().set_runtime_state(_runtime_state)
	if not hud_result.ok:
		push_error("Formal HUD after day advance failed: %s" % [hud_result.errors])
		return
	_formal_hud_node().set_playable_message(str(result.message))
	_debug_panel_node().set_runtime_state(_runtime_state)


func _advance_playable_day() -> Dictionary:
	var errors: Array[String] = []
	var messages: Array[String] = []
	var time_result: Dictionary = TimeSystem.advance_days(_runtime_state, 1)
	if not time_result.ok:
		return {"ok": false, "errors": time_result.errors, "message": ""}
	messages.append("第 %d 日: 时间推进完成。" % int(_runtime_state.current_day))
	var army_ids: Array = _runtime_state.armies.keys()
	army_ids.sort()
	for army_id in army_ids:
		var army: Dictionary = _runtime_state.armies[army_id]
		if str(army.state) == "marching":
			var march_result: Dictionary = MarchSystem.advance_army_one_day(_runtime_state, str(army_id))
			if not march_result.ok:
				errors.append_array(march_result.errors)
				continue
			army = _runtime_state.armies[army_id]
			messages.append("%s 行军进度 %s/%s，粮=%s。" % [
				str(army_id),
				str(army.route_progress_days),
				str(army.days_required),
				str(army.food_current),
			])
		if str(army.state) == "engaged":
			var route: Dictionary = _runtime_state.routes[army.route_id]
			var battle_result: Dictionary = BattleSystem.resolve_city_battle(_runtime_state, str(army_id), str(route.to_city_id))
			if not battle_result.ok:
				errors.append_array(battle_result.errors)
				continue
			messages.append("%s 接敌结算: %s 胜者=%s。" % [
				str(army_id),
				str(battle_result.battle_id),
				str(battle_result.winner),
			])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "message": ""}
	return {
		"ok": true,
		"errors": [],
		"message": " ".join(messages),
	}


func _content_alpha_workbench_node() -> Control:
	if _content_alpha_workbench != null:
		return _content_alpha_workbench
	return get_node("CanvasLayer/ContentAlphaWorkbench") as Control


func _map_view_node() -> Node:
	if _map_view != null:
		return _map_view
	return get_node("StrategicMapView")


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
