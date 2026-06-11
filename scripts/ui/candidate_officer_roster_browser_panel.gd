extends VBoxContainer

const CandidateOfficerRosterLoader = preload("res://scripts/data/candidate_officer_roster_loader.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

@onready var _filter: OptionButton = $StatusFilter
@onready var _summary: Label = $RosterSummary
@onready var _list: ItemList = $CandidateList
@onready var _detail: Label = $CandidateDetail
@onready var _image: TextureRect = $CandidateImage

var _records: Array[Dictionary] = []
var _visible_indices: Array[int] = []
var _active_status_filter := "all"


func _ready() -> void:
	_setup_filter()
	_status_filter().item_selected.connect(_on_status_filter_selected)
	_candidate_list().item_selected.connect(_on_candidate_selected)


func load_default_roster() -> Dictionary:
	var load_result: Dictionary = CandidateOfficerRosterLoader.load_default_roster()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	return set_records(load_result.records)


func set_records(records: Array) -> Dictionary:
	if records.is_empty():
		var errors := ["candidate officer browser requires at least one record"]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_records.clear()
	for record in records:
		if not record is Dictionary:
			var errors := ["candidate officer browser record must be a dictionary"]
			_show_error(errors)
			return {
				"ok": false,
				"errors": errors,
			}
		_records.append(record.duplicate(true))
	_refresh_list()
	if _visible_indices.is_empty():
		return {
			"ok": true,
			"errors": [],
		}
	return select_visible_index(0)


func set_status_filter(status_filter: String) -> Dictionary:
	if not ["all", "candidate", "selected", "rejected"].has(status_filter):
		var errors := ["candidate officer browser status filter invalid %s" % status_filter]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_active_status_filter = status_filter
	_select_filter_option(status_filter)
	_refresh_list()
	if _visible_indices.is_empty():
		_candidate_detail().text = "候选武将: 当前筛选无记录"
		_candidate_image().texture = null
		return {
			"ok": true,
			"errors": [],
		}
	return select_visible_index(0)


func select_candidate(candidate_officer_id: String) -> Dictionary:
	for visible_index in _visible_indices.size():
		var record_index := _visible_indices[visible_index]
		if str(_records[record_index].candidate_officer_id) == candidate_officer_id:
			return select_visible_index(visible_index)
	var errors := ["candidate officer browser missing visible candidate %s" % candidate_officer_id]
	_show_error(errors)
	return {
		"ok": false,
		"errors": errors,
	}


func select_visible_index(visible_index: int) -> Dictionary:
	if visible_index < 0 or visible_index >= _visible_indices.size():
		var errors := ["candidate officer browser selection index out of range %d" % visible_index]
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	_candidate_list().select(visible_index)
	return _apply_record(_visible_indices[visible_index])


func get_item_count() -> int:
	return _candidate_list().item_count


func get_summary_text() -> String:
	return _summary_label().text


func get_selected_detail_text() -> String:
	return _candidate_detail().text


func has_preview_texture() -> bool:
	return _candidate_image().texture != null


func _setup_filter() -> void:
	var filter := _status_filter()
	if filter.item_count > 0:
		return
	filter.add_item("全部", 0)
	filter.set_item_metadata(0, "all")
	filter.add_item("候选", 1)
	filter.set_item_metadata(1, "candidate")
	filter.add_item("已选", 2)
	filter.set_item_metadata(2, "selected")
	filter.add_item("排除", 3)
	filter.set_item_metadata(3, "rejected")


func _refresh_list() -> void:
	var list := _candidate_list()
	list.clear()
	_visible_indices.clear()
	for index in _records.size():
		var record: Dictionary = _records[index]
		if _active_status_filter != "all" and str(record.selection_status) != _active_status_filter:
			continue
		_visible_indices.append(index)
		list.add_item("%s  %s" % [
			str(record.display_name_cn),
			str(record.selection_status),
		])
	_summary_label().text = _format_summary()


func _format_summary() -> String:
	var counts := {
		"candidate": 0,
		"selected": 0,
		"rejected": 0,
	}
	for record in _records:
		var status := str(record.selection_status)
		if counts.has(status):
			counts[status] += 1
	return "候选武将名册: 总数=%s 候选=%s 已选=%s 排除=%s 当前显示=%s" % [
		_records.size(),
		counts.candidate,
		counts.selected,
		counts.rejected,
		_visible_indices.size(),
	]


func _apply_record(record_index: int) -> Dictionary:
	var record: Dictionary = _records[record_index]
	var row := {
		"hero_id": int(record.source_reference.representative_source_hero_id),
		"name_cn": str(record.display_name_cn),
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
	_candidate_image().texture = texture_result.texture
	_candidate_detail().text = _format_detail(record, texture_result)
	return {
		"ok": true,
		"errors": [],
		"record": record.duplicate(true),
	}


func _format_detail(record: Dictionary, texture_result: Dictionary) -> String:
	var binding_count := 0
	if record.source_reference.has("source_hero_bindings") and record.source_reference.source_hero_bindings is Array:
		binding_count = record.source_reference.source_hero_bindings.size()
	return "候选ID: %s\n显示名: %s\n状态: %s\n半身像: %s\n源绑定: %s\n尺寸: %sx%s" % [
		str(record.candidate_officer_id),
		str(record.display_name_cn),
		str(record.selection_status),
		str(record.half_body),
		binding_count,
		int(texture_result.width),
		int(texture_result.height),
	]


func _show_error(errors: Array) -> void:
	_candidate_image().texture = null
	_candidate_detail().text = "候选武将名册异常:\n%s" % "\n".join(errors)


func _on_status_filter_selected(index: int) -> void:
	var metadata = _status_filter().get_item_metadata(index)
	set_status_filter(str(metadata))


func _on_candidate_selected(index: int) -> void:
	select_visible_index(index)


func _select_filter_option(status_filter: String) -> void:
	var filter := _status_filter()
	for index in filter.item_count:
		if str(filter.get_item_metadata(index)) == status_filter:
			filter.select(index)
			return


func _status_filter() -> OptionButton:
	if _filter != null:
		return _filter
	return get_node("StatusFilter") as OptionButton


func _summary_label() -> Label:
	if _summary != null:
		return _summary
	return get_node("RosterSummary") as Label


func _candidate_list() -> ItemList:
	if _list != null:
		return _list
	return get_node("CandidateList") as ItemList


func _candidate_detail() -> Label:
	if _detail != null:
		return _detail
	return get_node("CandidateDetail") as Label


func _candidate_image() -> TextureRect:
	if _image != null:
		return _image
	return get_node("CandidateImage") as TextureRect
