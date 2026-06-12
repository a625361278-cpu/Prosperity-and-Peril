extends VBoxContainer

const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")

@onready var _summary: Label = $ThemeSummary
@onready var _list: ItemList = $TokenList
@onready var _detail: Label = $TokenDetail

var _tokens: Dictionary = {}
var _items: Array[Dictionary] = []


func _ready() -> void:
	_token_list().item_selected.connect(_on_token_selected)


func load_default_tokens() -> Dictionary:
	var load_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	return set_tokens(load_result.tokens)


func set_tokens(tokens: Dictionary) -> Dictionary:
	if tokens.is_empty():
		var errors := ["ui theme token panel requires tokens"]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_tokens = tokens.duplicate(true)
	_build_items()
	_populate_list()
	return select_index(0)


func select_token(token_id: String) -> Dictionary:
	for index in _items.size():
		if str(_items[index].id) == token_id:
			return select_index(index)
	var errors := ["ui theme token panel missing token %s" % token_id]
	_show_error(errors)
	return {
		"ok": false,
		"errors": errors,
	}


func select_index(index: int) -> Dictionary:
	if index < 0 or index >= _items.size():
		var errors := ["ui theme token panel selection index out of range %d" % index]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_token_list().select(index)
	var item: Dictionary = _items[index]
	_detail_label().text = "%s\n%s" % [
		str(item.title),
		str(item.detail),
	]
	return {
		"ok": true,
		"errors": [],
		"item": item.duplicate(true),
	}


func get_item_count() -> int:
	return _token_list().item_count


func get_summary_text() -> String:
	return _summary_label().text


func get_selected_detail_text() -> String:
	return _detail_label().text


func _build_items() -> void:
	_items.clear()
	_items.append({
		"id": "palette",
		"title": "色板",
		"detail": "颜色数量=%s 金色=%s 红色=%s 文本=%s" % [
			_tokens.palette.size(),
			str(_tokens.palette.accent_gold),
			str(_tokens.palette.accent_red),
			str(_tokens.palette.ink_text),
		],
	})
	_items.append({
		"id": "typography",
		"title": "字体",
		"detail": "标题=%s 正文=%s 注释=%s 策略=%s" % [
			str(_tokens.typography.sizes.title),
			str(_tokens.typography.sizes.body),
			str(_tokens.typography.sizes.caption),
			str(_tokens.typography.font_policy),
		],
	})
	_items.append({
		"id": "spacing",
		"title": "间距",
		"detail": "面板=%s 区块=%s 行距=%s 控件=%s" % [
			str(_tokens.spacing.panel_padding),
			str(_tokens.spacing.section_gap),
			str(_tokens.spacing.row_gap),
			str(_tokens.spacing.control_gap),
		],
	})
	_items.append({
		"id": "shape",
		"title": "形状",
		"detail": "圆角=%s 边框=%s 聚焦边框=%s" % [
			str(_tokens.shape.corner_radius),
			str(_tokens.shape.panel_border_width),
			str(_tokens.shape.focus_border_width),
		],
	})
	_items.append({
		"id": "controls",
		"title": "控件状态",
		"detail": "按钮 normal=%s hover=%s pressed=%s disabled=%s" % [
			str(_tokens.controls.button.normal),
			str(_tokens.controls.button.hover),
			str(_tokens.controls.button.pressed),
			str(_tokens.controls.button.disabled),
		],
	})
	_items.append({
		"id": "responsive",
		"title": "响应式规则",
		"detail": "\n".join(_tokens.responsive_rules),
	})


func _populate_list() -> void:
	var list := _token_list()
	list.clear()
	for item in _items:
		list.add_item(str(item.title))
	_summary_label().text = "UI 主题 Token: 色板=%s 控件=%s 圆角=%s" % [
		_tokens.palette.size(),
		_tokens.controls.size(),
		str(_tokens.shape.corner_radius),
	]


func _show_error(errors: Array) -> void:
	_detail_label().text = "UI 主题 Token 异常:\n%s" % "\n".join(errors)


func _on_token_selected(index: int) -> void:
	select_index(index)


func _summary_label() -> Label:
	if _summary != null:
		return _summary
	return get_node("ThemeSummary") as Label


func _token_list() -> ItemList:
	if _list != null:
		return _list
	return get_node("TokenList") as ItemList


func _detail_label() -> Label:
	if _detail != null:
		return _detail
	return get_node("TokenDetail") as Label
