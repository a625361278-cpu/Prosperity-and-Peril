extends Control

const DebugStatePresenter = preload("res://scripts/ui/debug_state_presenter.gd")

signal content_alpha_workbench_requested

@onready var _selection_label: Label = $PanelBackground/MarginContainer/VBoxContainer/SelectionText
@onready var _workbench_button: Button = $PanelBackground/MarginContainer/VBoxContainer/ContentAlphaWorkbenchButton
@onready var _portrait_preview_panel: VBoxContainer = $PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel
@onready var _label: Label = $PanelBackground/MarginContainer/VBoxContainer/ScrollContainer/DebugText


func _ready() -> void:
	_workbench_button_node().pressed.connect(_on_content_alpha_workbench_pressed)


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
	_portrait_preview().load_default_preview()


func set_portrait_preview_rows(rows: Array) -> void:
	_portrait_preview().set_preview_rows(rows)


func set_portrait_preview_texture(texture: Texture2D) -> void:
	_portrait_preview().set_preview_texture(texture)


func clear_portrait_preview_texture() -> void:
	_portrait_preview().clear_preview_texture()


func _on_content_alpha_workbench_pressed() -> void:
	content_alpha_workbench_requested.emit()


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


func _portrait_preview() -> VBoxContainer:
	if _portrait_preview_panel != null:
		return _portrait_preview_panel
	return get_node("PanelBackground/MarginContainer/VBoxContainer/HeroPortraitPreviewPanel") as VBoxContainer


func _workbench_button_node() -> Button:
	if _workbench_button != null:
		return _workbench_button
	return get_node("PanelBackground/MarginContainer/VBoxContainer/ContentAlphaWorkbenchButton") as Button
