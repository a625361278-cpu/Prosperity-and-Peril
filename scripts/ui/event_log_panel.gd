extends PanelContainer

const EventLogPresenter = preload("res://scripts/ui/event_log_presenter.gd")

@onready var _category_option: OptionButton = $MarginContainer/VBoxContainer/CategoryOption
@onready var _event_list: ItemList = $MarginContainer/VBoxContainer/EventList
@onready var _detail_label: Label = $MarginContainer/VBoxContainer/EventDetail
@onready var _message_label: Label = $MarginContainer/VBoxContainer/ValidationMessages
@onready var _close_button: Button = $MarginContainer/VBoxContainer/ActionRow/CloseButton

var _state: Dictionary = {}
var _events: Array[Dictionary] = []
var _category_ids: Array[String] = ["all", "military", "domestic", "officer", "diplomacy"]


func _ready() -> void:
	_populate_categories()
	_category_option_node().item_selected.connect(_on_category_selected)
	_event_list_node().item_selected.connect(_on_event_selected)
	_close_button_node().pressed.connect(_on_close_pressed)


func open_with_state(state: Dictionary) -> Dictionary:
	_state = state
	var result := _load_category(_selected_category())
	visible = true
	return result


func get_event_count() -> int:
	return _event_list_node().item_count


func get_detail_text() -> String:
	return _detail_label_node().text


func get_message_text() -> String:
	return _message_label_node().text


func _load_category(category_id: String) -> Dictionary:
	var result: Dictionary = EventLogPresenter.build_event_index(_state, category_id)
	if not result.ok:
		_show_errors(result.errors)
		return {"ok": false, "errors": result.errors}
	_events = result.events
	_rebuild_events()
	return {"ok": true, "errors": []}


func _populate_categories() -> void:
	var option := _category_option_node()
	option.clear()
	var labels := {
		"all": "全部",
		"military": "军事",
		"domestic": "内政",
		"officer": "武将",
		"diplomacy": "外交谋略",
	}
	for category_id in _category_ids:
		option.add_item(str(labels[category_id]))
	option.select(0)


func _rebuild_events() -> void:
	var list := _event_list_node()
	list.clear()
	for event in _events:
		list.add_item(str(event.label))
	if _events.is_empty():
		_detail_label_node().text = "当前分类没有真实运行时日志。"
		_message_label_node().text = "事件日志为空。"
	else:
		list.select(0)
		_apply_event(_events[0])


func _apply_event(event: Dictionary) -> void:
	_detail_label_node().text = "%s\n%s" % [str(event.title), str(event.detail)]
	_message_label_node().text = "事件日志来自真实运行时日志字典。"


func _show_errors(errors: Array) -> void:
	_event_list_node().clear()
	_events.clear()
	_detail_label_node().text = "事件日志异常"
	_message_label_node().text = "事件日志异常:\n%s" % "\n".join(errors)


func _selected_category() -> String:
	var index := _category_option_node().selected
	if index < 0 or index >= _category_ids.size():
		return "all"
	return _category_ids[index]


func _on_category_selected(_index: int) -> void:
	_load_category(_selected_category())


func _on_event_selected(index: int) -> void:
	if index < 0 or index >= _events.size():
		_show_errors(["event log selected index invalid %s" % str(index)])
		return
	_apply_event(_events[index])


func _on_close_pressed() -> void:
	visible = false


func _category_option_node() -> OptionButton:
	if _category_option != null:
		return _category_option
	return get_node("MarginContainer/VBoxContainer/CategoryOption") as OptionButton


func _event_list_node() -> ItemList:
	if _event_list != null:
		return _event_list
	return get_node("MarginContainer/VBoxContainer/EventList") as ItemList


func _detail_label_node() -> Label:
	if _detail_label != null:
		return _detail_label
	return get_node("MarginContainer/VBoxContainer/EventDetail") as Label


func _message_label_node() -> Label:
	if _message_label != null:
		return _message_label
	return get_node("MarginContainer/VBoxContainer/ValidationMessages") as Label


func _close_button_node() -> Button:
	if _close_button != null:
		return _close_button
	return get_node("MarginContainer/VBoxContainer/ActionRow/CloseButton") as Button
