extends VBoxContainer

const UiWireframeSpecLoader = preload("res://scripts/data/ui_wireframe_spec_loader.gd")

@onready var _summary: Label = $WireframeSummary
@onready var _list: ItemList = $WireframeList
@onready var _detail: Label = $WireframeDetail

var _wireframes: Array[Dictionary] = []
var _source: Dictionary = {}


func _ready() -> void:
	_wireframe_list().item_selected.connect(_on_wireframe_selected)


func load_default_spec() -> Dictionary:
	var load_result: Dictionary = UiWireframeSpecLoader.load_default_spec()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	return set_spec(load_result.source, load_result.wireframes)


func set_spec(source: Dictionary, wireframes: Array) -> Dictionary:
	if wireframes.is_empty():
		var errors := ["ui wireframe spec panel requires at least one wireframe"]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_source = source.duplicate(true)
	_wireframes.clear()
	for wireframe in wireframes:
		if not wireframe is Dictionary:
			var errors := ["ui wireframe spec panel wireframe must be a dictionary"]
			_show_error(errors)
			return {
				"ok": false,
				"errors": errors,
			}
		_wireframes.append(wireframe.duplicate(true))
	_populate_list()
	return select_index(0)


func select_wireframe(wireframe_id: String) -> Dictionary:
	for index in _wireframes.size():
		if str(_wireframes[index].id) == wireframe_id:
			return select_index(index)
	var errors := ["ui wireframe spec panel missing wireframe %s" % wireframe_id]
	_show_error(errors)
	return {
		"ok": false,
		"errors": errors,
	}


func select_index(index: int) -> Dictionary:
	if index < 0 or index >= _wireframes.size():
		var errors := ["ui wireframe spec panel selection index out of range %d" % index]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_wireframe_list().select(index)
	_detail_label().text = _format_detail(_wireframes[index])
	return {
		"ok": true,
		"errors": [],
		"wireframe": _wireframes[index].duplicate(true),
	}


func get_item_count() -> int:
	return _wireframe_list().item_count


func get_summary_text() -> String:
	return _summary_label().text


func get_selected_detail_text() -> String:
	return _detail_label().text


func _populate_list() -> void:
	var list := _wireframe_list()
	list.clear()
	for wireframe in _wireframes:
		list.add_item("%s  %s" % [
			str(wireframe.title_cn),
			str(wireframe.implementation_status),
		])
	_summary_label().text = _format_summary()


func _format_summary() -> String:
	var counts := {
		"wireframe_specified": 0,
		"content_alpha_tool": 0,
	}
	for wireframe in _wireframes:
		var status := str(wireframe.implementation_status)
		if counts.has(status):
			counts[status] = int(counts[status]) + 1
	return "UI 线框规格: 总数=%s 正式线框=%s Alpha工具=%s" % [
		_wireframes.size(),
		counts.wireframe_specified,
		counts.content_alpha_tool,
	]


func _format_detail(wireframe: Dictionary) -> String:
	return "线框ID: %s\n标题: %s\n状态: %s\n布局区域: %s\n组件: %s\n状态绑定: %s\n交互: %s\n阻塞项: %s\n风格图: %s\n边界: %s" % [
		str(wireframe.id),
		str(wireframe.title_cn),
		str(wireframe.implementation_status),
		", ".join(wireframe.layout_regions),
		", ".join(wireframe.primary_components),
		", ".join(wireframe.state_bindings),
		", ".join(wireframe.interactions),
		", ".join(wireframe.blocked_until),
		str(_source.get("style_reference", "")),
		str(_source.get("boundary_rule", "")),
	]


func _show_error(errors: Array) -> void:
	_detail_label().text = "UI 线框规格异常:\n%s" % "\n".join(errors)


func _on_wireframe_selected(index: int) -> void:
	select_index(index)


func _summary_label() -> Label:
	if _summary != null:
		return _summary
	return get_node("WireframeSummary") as Label


func _wireframe_list() -> ItemList:
	if _list != null:
		return _list
	return get_node("WireframeList") as ItemList


func _detail_label() -> Label:
	if _detail != null:
		return _detail
	return get_node("WireframeDetail") as Label
