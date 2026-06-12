extends Control

const ContentAlphaThemeLoader = preload("res://scripts/ui/content_alpha_theme_loader.gd")
const FormalHudPresenter = preload("res://scripts/ui/formal_hud_presenter.gd")

@onready var _date_label: Label = $TopBar/MarginContainer/HBoxContainer/DateLabel
@onready var _force_label: Label = $TopBar/MarginContainer/HBoxContainer/ForceSummaryLabel
@onready var _selection_title: Label = $RightPanel/MarginContainer/VBoxContainer/SelectionTitle
@onready var _selection_body: Label = $RightPanel/MarginContainer/VBoxContainer/SelectionBody
@onready var _city_detail_panel = $RightPanel/MarginContainer/VBoxContainer/CityDetailPanel
@onready var _command_bar: HBoxContainer = $BottomCommandBar/MarginContainer/CommandButtons
@onready var _appointment_sortie_panel = $AppointmentSortiePanel

var _state: Dictionary = {}
var _selected_city_id := ""


func _ready() -> void:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
	var theme_result := ContentAlphaThemeLoader.load_default_theme()
	if not theme_result.ok:
		push_error("Formal HUD theme failed: %s" % [theme_result.errors])
		return
	theme = theme_result.theme


func set_runtime_state(state: Dictionary) -> Dictionary:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
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


func set_map_selection(state: Dictionary, selection: Dictionary) -> Dictionary:
	_wire_city_detail_panel()
	_wire_appointment_sortie_panel()
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
		button.text = str(command.label)
		button.disabled = not bool(command.enabled)
		button.tooltip_text = str(command.blocked_reason)
		button.custom_minimum_size = Vector2(86, 34)
		bar.add_child(button)


func _wire_city_detail_panel() -> void:
	var panel = _city_detail_panel_node()
	if not panel.city_action_requested.is_connected(_on_city_action_requested):
		panel.city_action_requested.connect(_on_city_action_requested)


func _wire_appointment_sortie_panel() -> void:
	var panel = _appointment_sortie_panel_node()
	if not panel.state_changed.is_connected(_on_appointment_sortie_state_changed):
		panel.state_changed.connect(_on_appointment_sortie_state_changed)


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
