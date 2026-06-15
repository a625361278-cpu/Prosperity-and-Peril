extends RefCounted

const REQUIRED_STATE_KEYS := [
	"current_day",
	"current_month",
	"forces",
	"cities",
	"officers",
	"routes",
	"armies",
	"battle_logs",
]


static func build_hud_state(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return _failure(errors)
	var leader_card := _leader_card_text(state)
	if not leader_card.ok:
		return _failure(leader_card.errors)
	var route_status := _route_status_text(state)
	if not route_status.ok:
		return _failure(route_status.errors)
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"date_text": "第 %d 日 / 第 %d 月" % [int(state.current_day), int(state.current_month)],
			"force_summary": _force_summary(state.forces),
			"playable_status": _playable_status(state),
			"map_mode_text": "战略地图 / 测试坐标切片",
			"route_status_text": route_status.text,
			"leader_card_text": leader_card.text,
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
	var city_errors := _require_fields(city, "city %s" % city_id, ["name", "force_id", "troops", "food", "morale_public", "public_order", "gentry_support", "recovery_state"])
	if not city_errors.is_empty():
		return _failure(city_errors)
	var force_id := str(city.force_id)
	if not state.forces.has(force_id):
		return _failure(["formal hud selected city force missing %s for city %s" % [force_id, city_id]])
	var force: Dictionary = state.forces[force_id]
	var force_errors := _require_fields(force, "force %s" % force_id, ["name"])
	if not force_errors.is_empty():
		return _failure(force_errors)
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"selection_title": "城市: %s" % str(city.name),
			"selection_body": "所属 %s\n兵力 %s  粮草 %s\n民心 %s / 100  治安 %s / 100\n士族 %s / 100\n状态 %s  整合 %s" % [
				str(force.name),
				_value_text(city.troops),
				_value_text(city.food),
				_value_text(city.morale_public),
				_value_text(city.public_order),
				_value_text(city.gentry_support),
				_city_state_label(str(city.recovery_state)),
				_integration_value(city),
			],
		},
	}


static func _army_detail(state: Dictionary, army_id: String) -> Dictionary:
	if not state.armies.has(army_id):
		return _failure(["formal hud selected army missing %s" % army_id])
	var army: Dictionary = state.armies[army_id]
	var army_errors := _require_fields(army, "army %s" % army_id, ["state", "origin_city_id", "route_id", "commander_officer_id", "troop_count", "food_current", "route_progress_days"])
	if not army_errors.is_empty():
		return _failure(army_errors)
	var route_id := str(army.route_id)
	if not state.routes.has(route_id):
		return _failure(["formal hud selected army route missing %s for army %s" % [route_id, army_id]])
	var route: Dictionary = state.routes[route_id]
	var route_errors := _require_fields(route, "route %s" % route_id, ["from_city_id", "to_city_id", "route_type"])
	if not route_errors.is_empty():
		return _failure(route_errors)
	var from_city := _city_name_for_route(state, str(route.from_city_id), route_id)
	if not from_city.ok:
		return _failure(from_city.errors)
	var to_city := _city_name_for_route(state, str(route.to_city_id), route_id)
	if not to_city.ok:
		return _failure(to_city.errors)
	var commander_id := str(army.commander_officer_id)
	if not state.officers.has(commander_id):
		return _failure(["formal hud selected army commander missing %s for army %s" % [commander_id, army_id]])
	var commander: Dictionary = state.officers[commander_id]
	var commander_errors := _require_fields(commander, "officer %s" % commander_id, ["name"])
	if not commander_errors.is_empty():
		return _failure(commander_errors)
	return {
		"ok": true,
		"errors": [],
		"hud": {
			"selection_title": "部队: %s" % army_id,
			"selection_body": "状态 %s\n主将 %s\n路线 %s -> %s\n兵力 %s  粮草 %s\n进度 %s\n战果 %s" % [
				_army_state_label(str(army.state)),
				str(commander.name),
				str(from_city.name),
				str(to_city.name),
				_value_text(army.troop_count),
				_value_text(army.food_current),
				_army_progress_text(army),
				_battle_result_text(army),
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


static func _leader_card_text(state: Dictionary) -> Dictionary:
	var force_id := _primary_force_id(state.forces)
	if force_id.is_empty():
		return {"ok": false, "errors": ["formal hud has no force for leader card"], "text": ""}
	var force: Dictionary = state.forces[force_id]
	var force_errors := _require_fields(force, "force %s" % force_id, ["name", "ruler_officer_id", "legitimacy", "prestige"])
	if not force_errors.is_empty():
		return {"ok": false, "errors": force_errors, "text": ""}
	var ruler_id := str(force.ruler_officer_id)
	if not state.officers.has(ruler_id):
		return {"ok": false, "errors": ["formal hud ruler officer missing %s for force %s" % [ruler_id, force_id]], "text": ""}
	var officer: Dictionary = state.officers[ruler_id]
	var officer_errors := _require_fields(officer, "officer %s" % ruler_id, ["name", "leadership", "politics", "loyalty"])
	if not officer_errors.is_empty():
		return {"ok": false, "errors": officer_errors, "text": ""}
	return {
		"ok": true,
		"errors": [],
		"text": "势力领袖  %s\n所属  %s\n正统 %s  名望 %s\n忠诚 %s  统率 %s  政治 %s\n半身像: 候选资源示例，未绑定正式武将" % [
			str(officer.name),
			str(force.name),
			str(force.legitimacy),
			str(force.prestige),
			str(officer.loyalty),
			str(officer.leadership),
			str(officer.politics),
		],
	}


static func _primary_force_id(forces: Dictionary) -> String:
	if forces.has("FORCE_PLAYER"):
		return "FORCE_PLAYER"
	var keys := _sorted_keys(forces)
	if keys.is_empty():
		return ""
	return str(keys[0])


static func _require_fields(values: Dictionary, context: String, fields: Array) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		if not values.has(field):
			errors.append("formal hud %s missing %s" % [context, str(field)])
	return errors


static func _city_name_for_route(state: Dictionary, city_id: String, route_id: String) -> Dictionary:
	if not state.cities.has(city_id):
		return {"ok": false, "errors": ["formal hud route %s city missing %s" % [route_id, city_id]], "name": ""}
	var city: Dictionary = state.cities[city_id]
	var errors := _require_fields(city, "city %s" % city_id, ["name"])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "name": ""}
	return {"ok": true, "errors": [], "name": str(city.name)}


static func _integration_value(city: Dictionary) -> String:
	if not city.has("integration_progress"):
		return "未进入战后整合"
	return "%s / 100" % _value_text(city.integration_progress)


static func _city_state_label(state: String) -> String:
	if state == "normal":
		return "正常"
	if state == "occupied":
		return "占领整合中"
	if state == "unrest":
		return "动荡"
	if state == "recovering":
		return "恢复中"
	return state


static func _army_state_label(state: String) -> String:
	if state == "marching":
		return "行军中"
	if state == "engaged":
		return "接敌"
	if state == "victorious":
		return "胜利"
	if state == "defeated":
		return "战败"
	if state == "out_of_supply":
		return "断粮"
	return state


static func _army_progress_text(army: Dictionary) -> String:
	if army.has("days_required") and int(army.days_required) > 0:
		return "%s / %s 日" % [_value_text(army.route_progress_days), _value_text(army.days_required)]
	return "%s 日" % _value_text(army.route_progress_days)


static func _battle_result_text(army: Dictionary) -> String:
	if not army.has("last_battle_result") or str(army.last_battle_result).is_empty():
		return "未结算"
	return str(army.last_battle_result)


static func _value_text(value) -> String:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), float(int(value))):
		return str(int(value))
	return str(value)


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


static func _route_status_text(state: Dictionary) -> Dictionary:
	var pass_routes := 0
	var blocked_passes := 0
	for route_id in state.routes.keys():
		var route: Dictionary = state.routes[route_id]
		var route_errors := _require_fields(route, "route %s" % str(route_id), ["route_type", "blocks_enemy_passage"])
		if not route_errors.is_empty():
			return {"ok": false, "errors": route_errors, "text": ""}
		var route_type := str(route.route_type)
		if route_type == "pass":
			pass_routes += 1
			if bool(route.blocks_enemy_passage):
				blocked_passes += 1
	var marching := 0
	for army_id in state.armies.keys():
		var army: Dictionary = state.armies[army_id]
		var army_errors := _require_fields(army, "army %s" % str(army_id), ["state"])
		if not army_errors.is_empty():
			return {"ok": false, "errors": army_errors, "text": ""}
		if str(army.state) == "marching":
			marching += 1
	return {
		"ok": true,
		"errors": [],
		"text": "城市 %d  路线 %d  关隘 %d  阻断 %d  行军 %d" % [
			int(state.cities.size()),
			int(state.routes.size()),
			pass_routes,
			blocked_passes,
			marching,
		],
	}


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
