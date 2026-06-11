extends VBoxContainer

const UiNavigationSpecLoader = preload("res://scripts/data/ui_navigation_spec_loader.gd")

@onready var _summary: Label = $SpecSummary
@onready var _list: ItemList = $ScreenList
@onready var _detail: Label = $ScreenDetail

var _screens: Array[Dictionary] = []
var _source: Dictionary = {}


func _ready() -> void:
	_screen_list().item_selected.connect(_on_screen_selected)


func load_default_spec() -> Dictionary:
	var load_result: Dictionary = UiNavigationSpecLoader.load_default_spec()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	return set_spec(load_result.source, load_result.screens)


func set_spec(source: Dictionary, screens: Array) -> Dictionary:
	if screens.is_empty():
		var errors := ["ui navigation spec panel requires at least one screen"]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_source = source.duplicate(true)
	_screens.clear()
	for screen in screens:
		if not screen is Dictionary:
			var errors := ["ui navigation spec panel screen must be a dictionary"]
			_show_error(errors)
			return {
				"ok": false,
				"errors": errors,
			}
		_screens.append(screen.duplicate(true))
	_populate_list()
	return select_index(0)


func select_screen(screen_id: String) -> Dictionary:
	for index in _screens.size():
		if str(_screens[index].id) == screen_id:
			return select_index(index)
	var errors := ["ui navigation spec panel missing screen %s" % screen_id]
	_show_error(errors)
	return {
		"ok": false,
		"errors": errors,
	}


func select_index(index: int) -> Dictionary:
	if index < 0 or index >= _screens.size():
		var errors := ["ui navigation spec panel selection index out of range %d" % index]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_screen_list().select(index)
	_detail_label().text = _format_detail(_screens[index])
	return {
		"ok": true,
		"errors": [],
		"screen": _screens[index].duplicate(true),
	}


func get_item_count() -> int:
	return _screen_list().item_count


func get_summary_text() -> String:
	return _summary_label().text


func get_selected_detail_text() -> String:
	return _detail_label().text


func _populate_list() -> void:
	var list := _screen_list()
	list.clear()
	for screen in _screens:
		list.add_item("%s  %s" % [
			str(screen.title_cn),
			str(screen.implementation_status),
		])
	_summary_label().text = _format_summary()


func _format_summary() -> String:
	var counts := {
		"debug_available": 0,
		"content_alpha_available": 0,
		"planned": 0,
	}
	for screen in _screens:
		var status := str(screen.implementation_status)
		if counts.has(status):
			counts[status] = int(counts[status]) + 1
	return "UI 信息架构: 总数=%s 调试可用=%s Alpha可用=%s 规划=%s" % [
		_screens.size(),
		counts.debug_available,
		counts.content_alpha_available,
		counts.planned,
	]


func _format_detail(screen: Dictionary) -> String:
	return "界面ID: %s\n标题: %s\n分类: %s\n状态: %s\n数据源: %s\n入口: %s\n动作: %s\n阻塞项: %s\n边界: %s" % [
		str(screen.id),
		str(screen.title_cn),
		str(screen.category),
		str(screen.implementation_status),
		", ".join(screen.primary_data_sources),
		", ".join(screen.entry_points),
		", ".join(screen.allowed_actions),
		", ".join(screen.blocked_until),
		str(_source.get("boundary_rule", "")),
	]


func _show_error(errors: Array) -> void:
	_detail_label().text = "UI 信息架构异常:\n%s" % "\n".join(errors)


func _on_screen_selected(index: int) -> void:
	select_index(index)


func _summary_label() -> Label:
	if _summary != null:
		return _summary
	return get_node("SpecSummary") as Label


func _screen_list() -> ItemList:
	if _list != null:
		return _list
	return get_node("ScreenList") as ItemList


func _detail_label() -> Label:
	if _detail != null:
		return _detail
	return get_node("ScreenDetail") as Label
