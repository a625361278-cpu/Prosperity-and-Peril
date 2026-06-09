extends Control

const DebugStatePresenter = preload("res://scripts/ui/debug_state_presenter.gd")
const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")
const HeroPortraitPreviewPresenter = preload("res://scripts/ui/hero_portrait_preview_presenter.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

const HERO_PORTRAIT_INDEX_PATH := "res://data/content_alpha/hero_portrait_index.json"
const HERO_PORTRAIT_PREVIEW_LIMIT := 3

@onready var _selection_label: Label = $PanelBackground/MarginContainer/VBoxContainer/SelectionText
@onready var _portrait_preview_label: Label = $PanelBackground/MarginContainer/VBoxContainer/PortraitPreviewText
@onready var _portrait_preview_image: TextureRect = $PanelBackground/MarginContainer/VBoxContainer/PortraitPreviewImage
@onready var _label: Label = $PanelBackground/MarginContainer/VBoxContainer/ScrollContainer/DebugText


func set_runtime_state(state: Dictionary) -> void:
	var result: Dictionary = DebugStatePresenter.build_snapshot(state)
	if not result.ok:
		_label.text = "调试面板状态异常:\n%s" % "\n".join(result.errors)
		return
	_label.text = _format_snapshot(result.snapshot)
	if _selection_label.text.is_empty() or _selection_label.text == "等待选择...":
		_selection_label.text = "当前选择: 未选择"
	load_content_alpha_portrait_preview()


func set_map_selection(state: Dictionary, selection: Dictionary) -> void:
	var result: Dictionary = DebugStatePresenter.build_selection_detail(state, selection)
	if not result.ok:
		_selection_label.text = "当前选择异常:\n%s" % "\n".join(result.errors)
		return
	_selection_label.text = "%s\n%s" % [
		str(result.detail.title),
		str(result.detail.body),
	]


func load_content_alpha_portrait_preview() -> void:
	var preview_label := _portrait_preview_text()
	var load_result: Dictionary = HeroPortraitIndexLoader.load_and_build_lookup(HERO_PORTRAIT_INDEX_PATH)
	if not load_result.ok:
		preview_label.text = "半身像候选预览异常:\n%s" % "\n".join(load_result.errors)
		return
	var preview_result: Dictionary = HeroPortraitPreviewPresenter.build_default_preview_rows(
		load_result.lookup,
		HERO_PORTRAIT_PREVIEW_LIMIT
	)
	if not preview_result.ok:
		preview_label.text = "半身像候选预览异常:\n%s" % "\n".join(preview_result.errors)
		clear_portrait_preview_texture()
		return
	preview_label.text = _format_portrait_preview(preview_result.rows)
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(preview_result.rows[0])
	if not texture_result.ok:
		clear_portrait_preview_texture()
		preview_label.text = "半身像候选预览异常:\n%s" % "\n".join(texture_result.errors)
		return
	set_portrait_preview_texture(texture_result.texture)


func set_portrait_preview_rows(rows: Array) -> void:
	_portrait_preview_text().text = _format_portrait_preview(rows)


func set_portrait_preview_texture(texture: Texture2D) -> void:
	_portrait_preview_rect().texture = texture


func clear_portrait_preview_texture() -> void:
	_portrait_preview_rect().texture = null


func _format_snapshot(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("日期: 第 %d 日 / 第 %d 月" % [snapshot.current_day, snapshot.current_month])
	lines.append("")
	lines.append("势力:")
	for force in snapshot.forces:
		lines.append("- %s %s 正统=%s 名望=%s" % [
			force.id,
			force.name,
			force.legitimacy,
			force.prestige,
		])
	lines.append("")
	lines.append("城市:")
	for city in snapshot.cities:
		lines.append("- %s %s 势力=%s 兵=%s 粮=%s 民心=%s 治安=%s 士族=%s 状态=%s 整合=%s" % [
			city.id,
			city.name,
			city.force_id,
			city.troops,
			city.food,
			city.morale_public,
			city.public_order,
			city.gentry_support,
			city.recovery_state,
			city.integration_progress,
		])
	lines.append("")
	lines.append("武将:")
	for officer in snapshot.officers:
		lines.append("- %s %s 势力=%s 忠诚=%s" % [
			officer.id,
			officer.name,
			officer.force_id,
			officer.loyalty,
		])
	lines.append("")
	lines.append("部队:")
	for army in snapshot.armies:
		lines.append("- %s 状态=%s 出阵=%s 路线=%s 兵=%s 粮=%s 进度=%s 战果=%s" % [
			army.id,
			army.state,
			army.origin_city_id,
			army.route_id,
			army.troop_count,
			army.food_current,
			army.route_progress_days,
			army.last_battle_result,
		])
	lines.append("")
	lines.append("战斗日志:")
	for battle_log in snapshot.battle_logs:
		lines.append("- %s 目标=%s 胜者=%s 攻损=%s 守损=%s" % [
			battle_log.id,
			battle_log.target_city_id,
			battle_log.winner,
			battle_log.attacker_loss,
			battle_log.defender_loss,
		])
	return "\n".join(lines)


func _format_portrait_preview(rows: Array) -> String:
	var lines: Array[String] = ["半身像候选预览:"]
	for row in rows:
		lines.append("- %s %s halfBody=%s" % [
			row.hero_id,
			row.name_cn,
			row.half_body,
		])
	return "\n".join(lines)


func _portrait_preview_text() -> Label:
	if _portrait_preview_label != null:
		return _portrait_preview_label
	return get_node("PanelBackground/MarginContainer/VBoxContainer/PortraitPreviewText") as Label


func _portrait_preview_rect() -> TextureRect:
	if _portrait_preview_image != null:
		return _portrait_preview_image
	return get_node("PanelBackground/MarginContainer/VBoxContainer/PortraitPreviewImage") as TextureRect
