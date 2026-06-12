extends RefCounted

const REQUIRED_STATE_KEYS := [
	"current_day",
	"current_month",
	"forces",
	"cities",
	"armies",
	"battle_logs",
]


static func build_hud_state(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return _failure(errors)
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"date_text": "第 %d 日 / 第 %d 月" % [int(state.current_day), int(state.current_month)],
			"force_summary": _force_summary(state.forces),
			"playable_status": _playable_status(state),
			"selection_title": "当前选择: 未选择",
			"selection_body": "点击地图城市或部队查看真实状态。",
			"commands": _command_rows(),
		},
	}


static func build_selection_detail(state: Dictionary, selection: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	errors.append_array(_validate_selection(selection))
	if not errors.is_empty():
		return _failure(errors)
	var selection_type := str(selection.type)
	var selection_id := str(selection.id)
	if selection_type == "city":
		return _city_detail(state, selection_id)
	if selection_type == "army":
		return _army_detail(state, selection_id)
	return _failure(["formal hud unsupported selection type %s" % selection_type])


static func _city_detail(state: Dictionary, city_id: String) -> Dictionary:
	if not state.cities.has(city_id):
		return _failure(["formal hud selected city missing %s" % city_id])
	var city: Dictionary = state.cities[city_id]
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"selection_title": "城市: %s" % str(city.name),
			"selection_body": "ID=%s\n势力=%s\n兵=%s 粮=%s\n民心=%s 治安=%s 士族=%s\n状态=%s 整合=%s" % [
				city_id,
				str(city.force_id),
				str(city.troops),
				str(city.food),
				str(city.morale_public),
				str(city.public_order),
				str(city.gentry_support),
				str(city.recovery_state),
				str(city.get("integration_progress", -1)),
			],
		},
	}


static func _army_detail(state: Dictionary, army_id: String) -> Dictionary:
	if not state.armies.has(army_id):
		return _failure(["formal hud selected army missing %s" % army_id])
	var army: Dictionary = state.armies[army_id]
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"selection_title": "部队: %s" % army_id,
			"selection_body": "状态=%s\n出阵=%s 路线=%s\n主将=%s\n兵=%s 粮=%s\n进度=%s 战果=%s" % [
				str(army.state),
				str(army.origin_city_id),
				str(army.route_id),
				str(army.commander_officer_id),
				str(army.troop_count),
				str(army.food_current),
				str(army.route_progress_days),
				str(army.get("last_battle_result", "")),
			],
		},
	}


static func _force_summary(forces: Dictionary) -> String:
	var lines: Array[String] = []
	for force_id in _sorted_keys(forces):
		var force: Dictionary = forces[force_id]
		lines.append("%s 正统=%s 名望=%s" % [
			str(force.name),
			str(force.legitimacy),
			str(force.prestige),
		])
	return "  |  ".join(lines)


static func _playable_status(state: Dictionary) -> String:
	var marching := 0
	var engaged := 0
	var resolved := 0
	for army_id in state.armies.keys():
		var army: Dictionary = state.armies[army_id]
		var army_state := str(army.state)
		if army_state == "marching":
			marching += 1
		elif army_state == "engaged":
			engaged += 1
		elif ["victorious", "defeated", "out_of_supply"].has(army_state):
			resolved += 1
	if engaged > 0:
		return "目标: 有部队已经接敌，点击推进一日会结算战斗。"
	if marching > 0:
		return "目标: 部队行军中，点击推进一日观察路线和粮草变化。"
	if int(state.battle_logs.size()) > 0:
		return "目标: 战斗已产生，打开战报查看结果，也可以继续从城市出阵。"
	if resolved > 0:
		return "目标: 部队状态已变化，选择部队或打开战报查看详情。"
	return "目标: 点击己方城市，任命太守或出阵，形成一条完整作战链路。"


static func _command_rows() -> Array[Dictionary]:
	return [
		{"id": "advance_day", "label": "推进一日", "enabled": true, "blocked_reason": "推进时间、行军和自动接战"},
		{"id": "battle_report", "label": "战报", "enabled": true, "blocked_reason": "打开正式战报面板"},
		{"id": "event_log", "label": "事件", "enabled": true, "blocked_reason": "打开正式事件日志面板"},
		{"id": "save_load", "label": "存档", "enabled": true, "blocked_reason": "打开正式存档读档面板"},
		{"id": "reserved_roster", "label": "武将", "enabled": false, "blocked_reason": "正式武将名册留作后续版本"},
	]


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("formal hud missing state key %s" % key)
	return errors


static func _validate_selection(selection: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["type", "id"]:
		if not selection.has(key):
			errors.append("formal hud selection missing %s" % key)
	return errors


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"hud": {},
	}
