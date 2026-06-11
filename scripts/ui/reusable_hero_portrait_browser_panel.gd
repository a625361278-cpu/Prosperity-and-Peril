extends VBoxContainer

const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

@onready var _list: ItemList = $PortraitList
@onready var _detail: Label = $PortraitDetail
@onready var _image: TextureRect = $PortraitImage

var _records: Array[Dictionary] = []


func _ready() -> void:
	_portrait_list().item_selected.connect(_on_portrait_selected)


func load_default_pool() -> Dictionary:
	var load_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	return set_records(load_result.records)


func set_records(records: Array) -> Dictionary:
	if records.is_empty():
		var errors := ["reusable portrait browser requires at least one record"]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_records.clear()
	for record in records:
		if not record is Dictionary:
			var errors := ["reusable portrait browser record must be a dictionary"]
			_show_error(errors)
			return {
				"ok": false,
				"errors": errors,
			}
		_records.append(record.duplicate(true))
	_populate_list()
	return select_index(0)


func select_half_body(half_body: String) -> Dictionary:
	for index in _records.size():
		if str(_records[index].half_body) == half_body:
			return select_index(index)
	var errors := ["reusable portrait browser missing half_body %s" % half_body]
	_show_error(errors)
	return {
		"ok": false,
		"errors": errors,
	}


func select_index(index: int) -> Dictionary:
	if index < 0 or index >= _records.size():
		var errors := ["reusable portrait browser selection index out of range %d" % index]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_portrait_list().select(index)
	return _apply_record(index)


func get_item_count() -> int:
	return _portrait_list().item_count


func get_selected_detail_text() -> String:
	return _detail_label().text


func has_preview_texture() -> bool:
	return _preview_image().texture != null


func _populate_list() -> void:
	var list := _portrait_list()
	list.clear()
	for record in _records:
		list.add_item("%s  %s" % [
			str(record.representative_source_name_cn),
			str(record.half_body),
		])


func _apply_record(index: int) -> Dictionary:
	var record: Dictionary = _records[index]
	var row := {
		"hero_id": int(record.representative_source_hero_id),
		"name_cn": str(record.representative_source_name_cn),
		"half_body": str(record.half_body),
		"portrait_res_path": str(record.portrait_res_path),
	}
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(row)
	if not texture_result.ok:
		_show_error(texture_result.errors)
		return {
			"ok": false,
			"errors": texture_result.errors,
		}
	_preview_image().texture = texture_result.texture
	_detail_label().text = _format_detail(record, texture_result)
	return {
		"ok": true,
		"errors": [],
		"record": record.duplicate(true),
	}


func _format_detail(record: Dictionary, texture_result: Dictionary) -> String:
	var binding_count := 0
	if record.has("source_hero_bindings") and record.source_hero_bindings is Array:
		binding_count = record.source_hero_bindings.size()
	return "半身像: %s\n参考名: %s\n源绑定: %s\n尺寸: %sx%s\n资源: %s" % [
		str(record.half_body),
		str(record.representative_source_name_cn),
		binding_count,
		int(texture_result.width),
		int(texture_result.height),
		str(record.portrait_res_path),
	]


func _show_error(errors: Array) -> void:
	_preview_image().texture = null
	_detail_label().text = "可复用半身像浏览异常:\n%s" % "\n".join(errors)


func _on_portrait_selected(index: int) -> void:
	_apply_record(index)


func _portrait_list() -> ItemList:
	if _list != null:
		return _list
	return get_node("PortraitList") as ItemList


func _detail_label() -> Label:
	if _detail != null:
		return _detail
	return get_node("PortraitDetail") as Label


func _preview_image() -> TextureRect:
	if _image != null:
		return _image
	return get_node("PortraitImage") as TextureRect
