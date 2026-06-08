extends Control

const DebugStatePresenter = preload("res://scripts/ui/debug_state_presenter.gd")

@onready var _label: Label = $PanelBackground/MarginContainer/ScrollContainer/DebugText


func set_runtime_state(state: Dictionary) -> void:
	var result: Dictionary = DebugStatePresenter.build_snapshot(state)
	if not result.ok:
		_label.text = "调试面板状态异常:\n%s" % "\n".join(result.errors)
		return
	_label.text = _format_snapshot(result.snapshot)


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
	for log in snapshot.battle_logs:
		lines.append("- %s 目标=%s 胜者=%s 攻损=%s 守损=%s" % [
			log.id,
			log.target_city_id,
			log.winner,
			log.attacker_loss,
			log.defender_loss,
		])
	return "\n".join(lines)
