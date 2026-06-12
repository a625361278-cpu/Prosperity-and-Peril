extends Control

const ContentAlphaThemeLoader = preload("res://scripts/ui/content_alpha_theme_loader.gd")
const FormalHudPresenter = preload("res://scripts/ui/formal_hud_presenter.gd")

signal runtime_state_replaced(state)

@onready var _date_label: Label = $TopBar/MarginContainer/HBoxContainer/DateLabel
@onready var _force_label: Label = $TopBar/MarginContainer/HBoxContainer/ForceSummaryLabel
@onready var _selection_title: Label = $RightPanel/MarginContainer/VBoxContainer/SelectionTitle
@onready var _selection_body: Label = $RightPanel/MarginContainer/VBoxContainer/SelectionBody
@onready var _city_detail_panel = $RightPanel/MarginContainer/VBoxContainer/CityDetailPanel
@onready var _command_bar: HBoxContainer = $BottomCommandBar/MarginContainer/CommandButtons
@onready var _appointment_sortie_panel = $AppointmentSortiePanel
@onready var _battle_report_panel = $BattleReportPanel
@onready var _event_log_panel = $EventLogPanel
@onready var _save_load_panel = $SaveLoadPanel

var _state: Dictionary = {}
var _base_dataset: Dictionary = {}
var _selected_city_id := ""


func _ready() -> void:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
	_wire_battle_report_panel()
	_wire_save_load_panel()
	var theme_result := ContentAlphaThemeLoader.load_default_theme()
	if not theme_result.ok:
		push_error("Formal HUD theme failed: %s" % [theme_result.errors])
		return
	theme = theme_result.theme


func set_runtime_state(state: Dictionary) -> Dictionary:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
	_wire_battle_report_panel()
	_wire_save_load_panel()
	_state = state
	_selected_city_id = ""
	var theme_result := ContentAlphaThemeLoader.load_default_theme()
	if not theme_result.ok:
		return _failure(theme_result.errors)
	theme = theme_result.theme
	var result: Dictionary = FormalHudPresenter.build_hud_state(state)
	if not result.ok:
		return _failure(result.errors)
	_apply_hud_state(result.hud)
	return {"ok": true, "errors": []}


func set_base_dataset(base_dataset: Dictionary) -> Dictionary:
	if base_dataset.is_empty():
		return _failure(["formal hud base dataset is empty"])
	_base_dataset = base_dataset
	return {"ok": true, "errors": []}


func set_map_selection(state: Dictionary, selection: Dictionary) -> Dictionary:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
	_wire_battle_report_panel()
	_wire_save_load_panel()
	_state = state
	var result: Dictionary = FormalHudPresenter.build_selection_detail(state, selection)
	if not result.ok:
		return _failure(result.errors)
	_selection_title_node().text = str(result.hud.selection_title)
	_selection_body_node().text = str(result.hud.selection_body)
	if str(selection.type) == "city":
		_selected_city_id = str(selection.id)
		var city_result: Dictionary = _city_detail_panel_node().show_city(state, str(selection.id))
		if not city_result.ok:
			return _failure(city_result.errors)
	else:
		_selected_city_id = ""
		_city_detail_panel_node().clear_city()
	return {"ok": true, "errors": []}


func get_selection_title_text() -> String:
	return _selection_title_node().text


func get_command_count() -> int:
	return _command_bar_node().get_child_count()


func get_city_detail_title_text() -> String:
	return _city_detail_panel_node().get_title_text()


func get_city_detail_action_count() -> int:
	return _city_detail_panel_node().get_action_count()


func get_city_detail_action_enabled(action_id: String) -> bool:
	return _city_detail_panel_node().get_action_button_enabled(action_id)


func is_appointment_sortie_panel_visible() -> bool:
	return bool(_appointment_sortie_panel_node().visible)


func get_appointment_sortie_panel_node():
	return _appointment_sortie_panel_node()


func get_appointment_sortie_message_text() -> String:
	return _appointment_sortie_panel_node().get_message_text()


func get_command_enabled(command_id: String) -> bool:
	for child in _command_bar_node().get_children():
		if child is Button and str(child.get_meta("command_id", "")) == command_id:
			return not child.disabled
	push_error("formal hud missing command button %s" % command_id)
	return false


func is_battle_report_panel_visible() -> bool:
	return bool(_battle_report_panel_node().visible)


func get_battle_report_panel_node():
	return _battle_report_panel_node()


func is_event_log_panel_visible() -> bool:
	return bool(_event_log_panel_node().visible)


func get_event_log_panel_node():
	return _event_log_panel_node()


func is_save_load_panel_visible() -> bool:
	return bool(_save_load_panel_node().visible)


func get_save_load_panel_node():
	return _save_load_panel_node()


func _apply_hud_state(hud: Dictionary) -> void:
	_date_label_node().text = str(hud.date_text)
	_force_label_node().text = str(hud.force_summary)
	_selection_title_node().text = str(hud.selection_title)
	_selection_body_node().text = str(hud.selection_body)
	_city_detail_panel_node().clear_city()
	_rebuild_commands(hud.commands)


func _rebuild_commands(commands: Array) -> void:
	var bar := _command_bar_node()
	for child in bar.get_children():
		child.free()
	for command in commands:
		if not command is Dictionary:
			push_error("formal hud command must be dictionary")
			continue
		var button := Button.new()
		var command_id := str(command.id)
		button.text = str(command.label)
		button.disabled = not bool(command.enabled)
		button.tooltip_text = str(command.blocked_reason)
		button.custom_minimum_size = Vector2(86, 34)
		button.set_meta("command_id", command_id)
		if not button.disabled:
			button.pressed.connect(_on_command_pressed.bind(command_id))
		bar.add_child(button)


func _wire_city_detail_panel() -> void:
	var panel = _city_detail_panel_node()
	if not panel.city_action_requested.is_connected(_on_city_action_requested):
		panel.city_action_requested.connect(_on_city_action_requested)


func _wire_appointment_sortie_panel() -> void:
	var panel = _appointment_sortie_panel_node()
	if not panel.state_changed.is_connected(_on_appointment_sortie_state_changed):
		panel.state_changed.connect(_on_appointment_sortie_state_changed)


func _wire_battle_report_panel() -> void:
	var panel = _battle_report_panel_node()
	if not panel.city_jump_requested.is_connected(_on_battle_report_city_jump_requested):
		panel.city_jump_requested.connect(_on_battle_report_city_jump_requested)


func _wire_save_load_panel() -> void:
	var panel = _save_load_panel_node()
	if not panel.state_loaded.is_connected(_on_save_load_state_loaded):
		panel.state_loaded.connect(_on_save_load_state_loaded)


func _on_command_pressed(command_id: String) -> void:
	if command_id == "battle_report":
		_open_battle_report_panel()
		return
	if command_id == "event_log":
		_open_event_log_panel()
		return
	if command_id == "save_load":
		_open_save_load_panel()
		return
	push_error("formal hud unsupported command %s" % command_id)


func _on_city_action_requested(action_id: String) -> void:
	if _state.is_empty():
		push_error("formal hud cannot open city action without runtime state")
		return
	if _selected_city_id.is_empty():
		push_error("formal hud cannot open city action without selected city")
		return
	if action_id != "appointment" and action_id != "sortie":
		push_error("formal hud unsupported city action %s" % action_id)
		return
	var result: Dictionary = _appointment_sortie_panel_node().open_for_city(_state, _selected_city_id)
	if not result.ok:
		push_error("formal hud appointment sortie open failed: %s" % [result.errors])


func _on_appointment_sortie_state_changed() -> void:
	if _state.is_empty() or _selected_city_id.is_empty():
		push_error("formal hud cannot refresh city detail after action without state and selected city")
		return
	var city_result: Dictionary = _city_detail_panel_node().show_city(_state, _selected_city_id)
	if not city_result.ok:
		push_error("formal hud city detail refresh failed: %s" % [city_result.errors])


func _open_battle_report_panel() -> void:
	if _state.is_empty():
		push_error("formal hud cannot open battle report without runtime state")
		return
	var result: Dictionary = _battle_report_panel_node().open_with_state(_state)
	if not result.ok:
		push_error("formal hud battle report open failed: %s" % [result.errors])


func _open_event_log_panel() -> void:
	if _state.is_empty():
		push_error("formal hud cannot open event log without runtime state")
		return
	var result: Dictionary = _event_log_panel_node().open_with_state(_state)
	if not result.ok:
		push_error("formal hud event log open failed: %s" % [result.errors])


func _open_save_load_panel() -> void:
	if _state.is_empty():
		push_error("formal hud cannot open save load without runtime state")
		return
	var result: Dictionary = _save_load_panel_node().open_with_state(_state, _base_dataset)
	if not result.ok:
		push_error("formal hud save load open failed: %s" % [result.errors])


func _on_save_load_state_loaded(state: Dictionary) -> void:
	var selected_city_id := _selected_city_id
	var result: Dictionary = set_runtime_state(state)
	if not result.ok:
		push_error("formal hud save load state refresh failed: %s" % [result.errors])
		return
	runtime_state_replaced.emit(_state)
	if not selected_city_id.is_empty():
		var select_result: Dictionary = set_map_selection(_state, {"type": "city", "id": selected_city_id})
		if not select_result.ok:
			push_error("formal hud save load selection refresh failed: %s" % [select_result.errors])


func _on_battle_report_city_jump_requested(city_id: String) -> void:
	if _state.is_empty():
		push_error("formal hud cannot jump battle report without runtime state")
		return
	var result: Dictionary = set_map_selection(_state, {"type": "city", "id": city_id})
	if not result.ok:
		push_error("formal hud battle report city jump failed: %s" % [result.errors])


func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
	}


func _date_label_node() -> Label:
	if _date_label != null:
		return _date_label
	return get_node("TopBar/MarginContainer/HBoxContainer/DateLabel") as Label


func _force_label_node() -> Label:
	if _force_label != null:
		return _force_label
	return get_node("TopBar/MarginContainer/HBoxContainer/ForceSummaryLabel") as Label


func _selection_title_node() -> Label:
	if _selection_title != null:
		return _selection_title
	return get_node("RightPanel/MarginContainer/VBoxContainer/SelectionTitle") as Label


func _selection_body_node() -> Label:
	if _selection_body != null:
		return _selection_body
	return get_node("RightPanel/MarginContainer/VBoxContainer/SelectionBody") as Label


func _city_detail_panel_node():
	if _city_detail_panel != null:
		return _city_detail_panel
	return get_node("RightPanel/MarginContainer/VBoxContainer/CityDetailPanel")


func _command_bar_node() -> HBoxContainer:
	if _command_bar != null:
		return _command_bar
	return get_node("BottomCommandBar/MarginContainer/CommandButtons") as HBoxContainer


func _appointment_sortie_panel_node():
	if _appointment_sortie_panel != null:
		return _appointment_sortie_panel
	return get_node("AppointmentSortiePanel")


func _battle_report_panel_node():
	if _battle_report_panel != null:
		return _battle_report_panel
	return get_node("BattleReportPanel")


func _event_log_panel_node():
	if _event_log_panel != null:
		return _event_log_panel
	return get_node("EventLogPanel")


func _save_load_panel_node():
	if _save_load_panel != null:
		return _save_load_panel
	return get_node("SaveLoadPanel")
