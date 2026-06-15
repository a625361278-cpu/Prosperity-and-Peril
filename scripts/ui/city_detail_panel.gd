extends VBoxContainer

const CityDetailPresenter = preload("res://scripts/ui/city_detail_presenter.gd")
const FormalUiComponentFactory = preload("res://scripts/ui/formal_ui_component_factory.gd")
const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")

signal city_action_requested(action_id)

@onready var _title: Label = $CityHeader
@onready var _force_summary: Label = $ForceSummary
@onready var _resources: Label = $ResourceStats
@onready var _governance: Label = $GovernanceStats
@onready var _governor: Label = $GovernorSummary
@onready var _officers: ItemList = $OfficerList
@onready var _actions: HBoxContainer = $ActionBar
@onready var _data_gaps: Label = $DataGapSummary


func show_city(state: Dictionary, city_id: String) -> Dictionary:
	var result: Dictionary = CityDetailPresenter.build_detail(state, city_id)
	if not result.ok:
		return _failure(result.errors)
	_apply_detail(result.detail)
	visible = true
	return {"ok": true, "errors": []}


func clear_city() -> void:
	visible = false


func get_title_text() -> String:
	return _title_node().text


func get_force_summary_text() -> String:
	return _force_summary_node().text


func get_data_gap_text() -> String:
	return _data_gaps_node().text


func get_action_count() -> int:
	return _actions_node().get_child_count()


func get_action_button_enabled(action_id: String) -> bool:
	for child in _actions_node().get_children():
		if child is Button and str(child.get_meta("action_id", "")) == action_id:
			return not child.disabled
	push_error("city detail missing action button %s" % action_id)
	return false


func _apply_detail(detail: Dictionary) -> void:
	_title_node().text = str(detail.title)
	_force_summary_node().text = str(detail.force_summary_text)
	_resources_node().text = "%s\n%s" % [str(detail.resource_section_title), _format_stat_lines(detail.resource_rows)]
	_governance_node().text = "%s\n%s" % [str(detail.governance_section_title), _format_stat_lines(detail.governance_rows)]
	_governor_node().text = str(detail.governor_text)
	_rebuild_officers(detail.officer_rows)
	_rebuild_actions(detail.actions)
	_data_gaps_node().text = _format_data_gaps(detail.data_gap_rows)


func _format_stat_lines(rows: Array) -> String:
	var parts: Array[String] = []
	for row in rows:
		if not row is Dictionary:
			push_error("city detail row must be dictionary")
			continue
		parts.append("%-4s  %s" % [str(row.label), str(row.value)])
	return "\n".join(parts)


func _format_data_gaps(rows: Array) -> String:
	if rows.is_empty():
		return "数据缺口\n当前城市详情所需字段已具备。"
	var parts: Array[String] = ["数据缺口"]
	for row in rows:
		if not row is Dictionary:
			push_error("city detail data gap row must be dictionary")
			continue
		parts.append("%s: %s" % [str(row.label), str(row.reason)])
	return "\n".join(parts)


func _rebuild_officers(rows: Array) -> void:
	var list := _officer_list_node()
	list.clear()
	for row in rows:
		if not row is Dictionary:
			push_error("city detail officer row must be dictionary")
			continue
		list.add_item("%s %s 忠诚=%s %s" % [
			str(row.id),
			str(row.name),
			str(row.loyalty),
			str(row.assignment),
		])


func _rebuild_actions(actions: Array) -> void:
	var bar := _actions_node()
	for child in bar.get_children():
		child.free()
	var factory_result := _build_component_factory()
	if not factory_result.ok:
		push_error("city detail action factory failed: %s" % [factory_result.errors])
		return
	var factory = factory_result.factory
	for action in actions:
		if not action is Dictionary:
			push_error("city detail action must be dictionary")
			continue
		var action_id := str(action.id)
		var button: Button = factory.create_action_button(action)
		button.pressed.connect(_on_action_pressed.bind(action_id))
		bar.add_child(button)


func _build_component_factory() -> Dictionary:
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return _failure(token_result.errors)
	return {
		"ok": true,
		"errors": [],
		"factory": FormalUiComponentFactory.new(token_result.tokens),
	}


func _on_action_pressed(action_id: String) -> void:
	city_action_requested.emit(action_id)


func _failure(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors}


func _title_node() -> Label:
	if _title != null:
		return _title
	return get_node("CityHeader") as Label


func _force_summary_node() -> Label:
	if _force_summary != null:
		return _force_summary
	return get_node("ForceSummary") as Label


func _resources_node() -> Label:
	if _resources != null:
		return _resources
	return get_node("ResourceStats") as Label


func _governance_node() -> Label:
	if _governance != null:
		return _governance
	return get_node("GovernanceStats") as Label


func _governor_node() -> Label:
	if _governor != null:
		return _governor
	return get_node("GovernorSummary") as Label


func _officer_list_node() -> ItemList:
	if _officers != null:
		return _officers
	return get_node("OfficerList") as ItemList


func _actions_node() -> HBoxContainer:
	if _actions != null:
		return _actions
	return get_node("ActionBar") as HBoxContainer


func _data_gaps_node() -> Label:
	if _data_gaps != null:
		return _data_gaps
	return get_node("DataGapSummary") as Label
