extends PanelContainer

const SaveLoadPresenter = preload("res://scripts/ui/save_load_presenter.gd")

signal state_loaded(state)

@onready var _title_label: Label = $MarginContainer/VBoxContainer/Title
@onready var _summary_label: Label = $MarginContainer/VBoxContainer/RuntimeSummary
@onready var _save_file_label: Label = $MarginContainer/VBoxContainer/SaveFileSummary
@onready var _save_path_label: Label = $MarginContainer/VBoxContainer/SavePath
@onready var _message_label: Label = $MarginContainer/VBoxContainer/ValidationMessages
@onready var _save_button: Button = $MarginContainer/VBoxContainer/ActionRow/SaveButton
@onready var _load_button: Button = $MarginContainer/VBoxContainer/ActionRow/LoadButton
@onready var _close_button: Button = $MarginContainer/VBoxContainer/ActionRow/CloseButton

var _state: Dictionary = {}
var _base_dataset: Dictionary = {}
var _save_path := SaveLoadPresenter.DEFAULT_SAVE_PATH


func _ready() -> void:
	_save_button_node().pressed.connect(_on_save_pressed)
	_load_button_node().pressed.connect(_on_load_pressed)
	_close_button_node().pressed.connect(_on_close_pressed)


func open_with_state(state: Dictionary, base_dataset: Dictionary = {}, save_path: String = SaveLoadPresenter.DEFAULT_SAVE_PATH) -> Dictionary:
	_state = state
	_base_dataset = base_dataset
	_save_path = save_path
	_save_path_label_node().text = "路径: %s" % _save_path
	var result: Dictionary = SaveLoadPresenter.build_summary(_state, _save_path)
	if not result.ok:
		_show_errors(result.errors)
		visible = true
		return {"ok": false, "errors": result.errors}
	_apply_summary(result.summary)
	_message_label_node().text = "存档读档使用 SaveSystem 的真实动态状态格式。"
	visible = true
	return {"ok": true, "errors": []}


func save_current_state() -> Dictionary:
	var result: Dictionary = SaveLoadPresenter.save_state(_state, _save_path)
	if not result.ok:
		_show_errors(result.errors)
		return result
	_apply_summary(result.summary)
	_message_label_node().text = str(result.message)
	return result


func load_saved_state() -> Dictionary:
	var result: Dictionary = SaveLoadPresenter.load_state(_base_dataset, _save_path)
	if not result.ok:
		_show_errors(result.errors)
		return result
	_state = result.state
	_apply_summary(result.summary)
	_message_label_node().text = str(result.message)
	state_loaded.emit(_state)
	return result


func get_summary_text() -> String:
	return _summary_label_node().text


func get_save_file_text() -> String:
	return _save_file_label_node().text


func get_message_text() -> String:
	return _message_label_node().text


func get_save_path_text() -> String:
	return _save_path_label_node().text


func _apply_summary(summary: Dictionary) -> void:
	_title_label_node().text = "存档读档 | schema=%s" % str(summary.schema_version)
	_summary_label_node().text = str(summary.current_state_text)
	_save_file_label_node().text = str(summary.save_file_text)
	_save_path_label_node().text = "路径: %s" % str(summary.save_path)
	_load_button_node().disabled = not bool(summary.save_exists)


func _show_errors(errors: Array) -> void:
	_title_label_node().text = "存档读档异常"
	_summary_label_node().text = ""
	_save_file_label_node().text = ""
	_message_label_node().text = "存档读档异常:\n%s" % "\n".join(errors)
	_load_button_node().disabled = true


func _on_save_pressed() -> void:
	save_current_state()


func _on_load_pressed() -> void:
	load_saved_state()


func _on_close_pressed() -> void:
	visible = false


func _title_label_node() -> Label:
	if _title_label != null:
		return _title_label
	return get_node("MarginContainer/VBoxContainer/Title") as Label


func _summary_label_node() -> Label:
	if _summary_label != null:
		return _summary_label
	return get_node("MarginContainer/VBoxContainer/RuntimeSummary") as Label


func _save_file_label_node() -> Label:
	if _save_file_label != null:
		return _save_file_label
	return get_node("MarginContainer/VBoxContainer/SaveFileSummary") as Label


func _save_path_label_node() -> Label:
	if _save_path_label != null:
		return _save_path_label
	return get_node("MarginContainer/VBoxContainer/SavePath") as Label


func _message_label_node() -> Label:
	if _message_label != null:
		return _message_label
	return get_node("MarginContainer/VBoxContainer/ValidationMessages") as Label


func _save_button_node() -> Button:
	if _save_button != null:
		return _save_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/SaveButton") as Button


func _load_button_node() -> Button:
	if _load_button != null:
		return _load_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/LoadButton") as Button


func _close_button_node() -> Button:
	if _close_button != null:
		return _close_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/CloseButton") as Button
