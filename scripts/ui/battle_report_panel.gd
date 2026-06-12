extends PanelContainer

const BattleReportPresenter = preload("res://scripts/ui/battle_report_presenter.gd")

signal city_jump_requested(city_id)

@onready var _report_option: OptionButton = $MarginContainer/VBoxContainer/ReportOption
@onready var _title_label: Label = $MarginContainer/VBoxContainer/ReportTitle
@onready var _summary_label: Label = $MarginContainer/VBoxContainer/Summary
@onready var _casualty_label: Label = $MarginContainer/VBoxContainer/Casualties
@onready var _ownership_label: Label = $MarginContainer/VBoxContainer/Ownership
@onready var _message_label: Label = $MarginContainer/VBoxContainer/ValidationMessages
@onready var _jump_button: Button = $MarginContainer/VBoxContainer/ActionRow/JumpButton
@onready var _close_button: Button = $MarginContainer/VBoxContainer/ActionRow/CloseButton

var _state: Dictionary = {}
var _report_ids: Array[String] = []
var _jump_city_id := ""


func _ready() -> void:
	_report_option_node().item_selected.connect(_on_report_selected)
	_jump_button_node().pressed.connect(_on_jump_pressed)
	_close_button_node().pressed.connect(_on_close_pressed)


func open_with_state(state: Dictionary) -> Dictionary:
	_state = state
	var result: Dictionary = BattleReportPresenter.build_report_index(state)
	if not result.ok:
		_show_errors(result.errors)
		visible = true
		return {"ok": false, "errors": result.errors}
	_populate_reports(result.reports)
	if _report_ids.is_empty():
		_show_empty()
	else:
		var select_result := select_report(_report_ids[0])
		if not select_result.ok:
			visible = true
			return select_result
	visible = true
	return {"ok": true, "errors": []}


func select_report(battle_id: String) -> Dictionary:
	var result: Dictionary = BattleReportPresenter.build_report_detail(_state, battle_id)
	if not result.ok:
		_show_errors(result.errors)
		return {"ok": false, "errors": result.errors}
	_apply_report(result.report)
	return {"ok": true, "errors": []}


func get_report_count() -> int:
	return _report_option_node().item_count


func get_summary_text() -> String:
	return _summary_label_node().text


func get_message_text() -> String:
	return _message_label_node().text


func _populate_reports(reports: Array) -> void:
	var option := _report_option_node()
	option.clear()
	_report_ids.clear()
	for row in reports:
		if not row is Dictionary:
			push_error("battle report row must be dictionary")
			continue
		_report_ids.append(str(row.id))
		option.add_item(str(row.label))
	if option.item_count > 0:
		option.select(0)


func _apply_report(report: Dictionary) -> void:
	_title_label_node().text = str(report.title)
	_summary_label_node().text = str(report.summary)
	_casualty_label_node().text = str(report.casualties)
	_ownership_label_node().text = str(report.ownership)
	_message_label_node().text = "战报来自真实 battle_logs。"
	_jump_city_id = str(report.jump_city_id)
	_jump_button_node().disabled = _jump_city_id.is_empty()


func _show_empty() -> void:
	_title_label_node().text = "暂无战报"
	_summary_label_node().text = "当前运行时 battle_logs 为空。"
	_casualty_label_node().text = ""
	_ownership_label_node().text = ""
	_message_label_node().text = "没有生成过战斗结果。"
	_jump_city_id = ""
	_jump_button_node().disabled = true


func _show_errors(errors: Array) -> void:
	_title_label_node().text = "战报异常"
	_summary_label_node().text = ""
	_casualty_label_node().text = ""
	_ownership_label_node().text = ""
	_message_label_node().text = "战报异常:\n%s" % "\n".join(errors)
	_jump_city_id = ""
	_jump_button_node().disabled = true


func _on_report_selected(index: int) -> void:
	if index < 0 or index >= _report_ids.size():
		_show_errors(["battle report selected index invalid %s" % str(index)])
		return
	select_report(_report_ids[index])


func _on_jump_pressed() -> void:
	if _jump_city_id.is_empty():
		push_error("battle report cannot jump without city id")
		return
	city_jump_requested.emit(_jump_city_id)


func _on_close_pressed() -> void:
	visible = false


func _report_option_node() -> OptionButton:
	if _report_option != null:
		return _report_option
	return get_node("MarginContainer/VBoxContainer/ReportOption") as OptionButton


func _title_label_node() -> Label:
	if _title_label != null:
		return _title_label
	return get_node("MarginContainer/VBoxContainer/ReportTitle") as Label


func _summary_label_node() -> Label:
	if _summary_label != null:
		return _summary_label
	return get_node("MarginContainer/VBoxContainer/Summary") as Label


func _casualty_label_node() -> Label:
	if _casualty_label != null:
		return _casualty_label
	return get_node("MarginContainer/VBoxContainer/Casualties") as Label


func _ownership_label_node() -> Label:
	if _ownership_label != null:
		return _ownership_label
	return get_node("MarginContainer/VBoxContainer/Ownership") as Label


func _message_label_node() -> Label:
	if _message_label != null:
		return _message_label
	return get_node("MarginContainer/VBoxContainer/ValidationMessages") as Label


func _jump_button_node() -> Button:
	if _jump_button != null:
		return _jump_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/JumpButton") as Button


func _close_button_node() -> Button:
	if _close_button != null:
		return _close_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/CloseButton") as Button
