extends PanelContainer

const AppointmentSortiePresenter = preload("res://scripts/ui/appointment_sortie_presenter.gd")

signal state_changed

@onready var _city_summary: Label = $MarginContainer/VBoxContainer/CitySummary
@onready var _officer_option: OptionButton = $MarginContainer/VBoxContainer/OfficerOption
@onready var _route_option: OptionButton = $MarginContainer/VBoxContainer/RouteOption
@onready var _troop_spin: SpinBox = $MarginContainer/VBoxContainer/TroopFoodRow/TroopSpin
@onready var _food_spin: SpinBox = $MarginContainer/VBoxContainer/TroopFoodRow/FoodSpin
@onready var _message_label: Label = $MarginContainer/VBoxContainer/ValidationMessages
@onready var _appoint_button: Button = $MarginContainer/VBoxContainer/ActionRow/AppointButton
@onready var _sortie_button: Button = $MarginContainer/VBoxContainer/ActionRow/SortieButton
@onready var _close_button: Button = $MarginContainer/VBoxContainer/ActionRow/CloseButton

var _state: Dictionary = {}
var _city_id := ""
var _officer_ids: Array[String] = []
var _route_ids: Array[String] = []


func _ready() -> void:
	_appoint_button_node().pressed.connect(_on_appoint_pressed)
	_sortie_button_node().pressed.connect(_on_sortie_pressed)
	_close_button_node().pressed.connect(_on_close_pressed)


func open_for_city(state: Dictionary, city_id: String) -> Dictionary:
	_state = state
	_city_id = city_id
	var result: Dictionary = AppointmentSortiePresenter.build_form(state, city_id)
	if not result.ok:
		_show_errors(result.errors)
		visible = true
		return {"ok": false, "errors": result.errors}
	_apply_form(result.form)
	visible = true
	return {"ok": true, "errors": []}


func appoint_selected_governor() -> Dictionary:
	var officer_id := _selected_officer_id()
	var result: Dictionary = AppointmentSortiePresenter.appoint_governor(_state, _city_id, officer_id)
	if not result.ok:
		_show_errors(result.errors)
		return {"ok": false, "errors": result.errors}
	_message_label_node().text = str(result.message)
	state_changed.emit()
	return {"ok": true, "errors": [], "message": str(result.message)}


func create_sortie_from_inputs() -> Dictionary:
	var officer_id := _selected_officer_id()
	var route_id := _selected_route_id()
	var result: Dictionary = AppointmentSortiePresenter.create_sortie(
		_state,
		_city_id,
		officer_id,
		route_id,
		int(_troop_spin_node().value),
		int(_food_spin_node().value)
	)
	if not result.ok:
		_show_errors(result.errors)
		return {"ok": false, "errors": result.errors, "army_id": ""}
	_message_label_node().text = str(result.message)
	state_changed.emit()
	return {"ok": true, "errors": [], "army_id": str(result.army_id), "message": str(result.message)}


func get_message_text() -> String:
	return _message_label_node().text


func get_officer_count() -> int:
	return _officer_option_node().item_count


func get_route_count() -> int:
	return _route_option_node().item_count


func _apply_form(form: Dictionary) -> void:
	_city_summary_node().text = str(form.city_summary)
	_populate_options(_officer_option_node(), form.officers, _officer_ids)
	_populate_options(_route_option_node(), form.routes, _route_ids)
	_configure_spin(_troop_spin_node(), int(form.max_troops), int(form.default_troops))
	_configure_spin(_food_spin_node(), int(form.max_food), int(form.default_food))
	_message_label_node().text = "请选择武将、路线和兵粮后确认。"


func _populate_options(option: OptionButton, rows: Array, ids: Array[String]) -> void:
	option.clear()
	ids.clear()
	for row in rows:
		if not row is Dictionary:
			push_error("appointment sortie option row must be dictionary")
			continue
		ids.append(str(row.id))
		option.add_item(str(row.label))
	if option.item_count > 0:
		option.select(0)


func _configure_spin(spin: SpinBox, max_value: int, default_value: int) -> void:
	spin.min_value = 1
	spin.max_value = max_value
	spin.step = 1
	spin.value = max(default_value, 1)


func _selected_officer_id() -> String:
	var index := _officer_option_node().selected
	if index < 0 or index >= _officer_ids.size():
		return ""
	return _officer_ids[index]


func _selected_route_id() -> String:
	var index := _route_option_node().selected
	if index < 0 or index >= _route_ids.size():
		return ""
	return _route_ids[index]


func _show_errors(errors: Array) -> void:
	_message_label_node().text = "任命出阵异常:\n%s" % "\n".join(errors)


func _on_appoint_pressed() -> void:
	appoint_selected_governor()


func _on_sortie_pressed() -> void:
	create_sortie_from_inputs()


func _on_close_pressed() -> void:
	visible = false


func _city_summary_node() -> Label:
	if _city_summary != null:
		return _city_summary
	return get_node("MarginContainer/VBoxContainer/CitySummary") as Label


func _officer_option_node() -> OptionButton:
	if _officer_option != null:
		return _officer_option
	return get_node("MarginContainer/VBoxContainer/OfficerOption") as OptionButton


func _route_option_node() -> OptionButton:
	if _route_option != null:
		return _route_option
	return get_node("MarginContainer/VBoxContainer/RouteOption") as OptionButton


func _troop_spin_node() -> SpinBox:
	if _troop_spin != null:
		return _troop_spin
	return get_node("MarginContainer/VBoxContainer/TroopFoodRow/TroopSpin") as SpinBox


func _food_spin_node() -> SpinBox:
	if _food_spin != null:
		return _food_spin
	return get_node("MarginContainer/VBoxContainer/TroopFoodRow/FoodSpin") as SpinBox


func _message_label_node() -> Label:
	if _message_label != null:
		return _message_label
	return get_node("MarginContainer/VBoxContainer/ValidationMessages") as Label


func _appoint_button_node() -> Button:
	if _appoint_button != null:
		return _appoint_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/AppointButton") as Button


func _sortie_button_node() -> Button:
	if _sortie_button != null:
		return _sortie_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/SortieButton") as Button


func _close_button_node() -> Button:
	if _close_button != null:
		return _close_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/CloseButton") as Button
