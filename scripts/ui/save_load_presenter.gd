extends RefCounted

const SaveSystem = preload("res://scripts/save/save_system.gd")

const DEFAULT_SAVE_PATH := "user://content_alpha_quick_save.json"
const REQUIRED_STATE_KEYS := [
	"current_day",
	"current_month",
	"next_army_seq",
	"next_battle_seq",
	"next_diplomacy_log_seq",
	"next_scheme_seq",
	"next_legitimacy_log_seq",
	"next_local_governance_log_seq",
	"next_loyalty_log_seq",
	"cities",
	"forces",
	"officers",
	"armies",
	"battle_logs",
	"legitimacy_logs",
	"local_governance_logs",
	"loyalty_logs",
	"defector_states",
	"active_policies",
	"diplomacy_states",
	"diplomacy_logs",
	"scheme_states",
]


static func build_summary(state: Dictionary, save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	var errors := _validate_state(state)
	errors.append_array(_validate_save_path(save_path))
	if not errors.is_empty():
		return _failure(errors)
	var file_summary := _read_save_file_summary(save_path)
	if not file_summary.ok:
		return _failure(file_summary.errors)
	return {
		"ok": true,
		"errors": [],
		"summary": {
			"schema_version": SaveSystem.SAVE_VERSION,
			"save_path": save_path,
			"save_exists": bool(file_summary.exists),
			"current_state_text": _current_state_text(state),
			"save_file_text": str(file_summary.text),
		},
	}


static func save_state(state: Dictionary, save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	var errors := _validate_state(state)
	errors.append_array(_validate_save_path(save_path))
	if not errors.is_empty():
		return _failure(errors)
	var save_result: Dictionary = SaveSystem.save_state(state, save_path)
	if not save_result.ok:
		return _failure(save_result.errors)
	var summary_result := build_summary(state, save_path)
	if not summary_result.ok:
		return summary_result
	return {
		"ok": true,
		"errors": [],
		"summary": summary_result.summary,
		"message": "已保存真实动态状态，schema=%s。" % str(SaveSystem.SAVE_VERSION),
	}


static func load_state(base_dataset: Dictionary, save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	var errors := _validate_base_dataset(base_dataset)
	errors.append_array(_validate_save_path(save_path))
	if not errors.is_empty():
		return _failure_with_state(errors)
	var load_result: Dictionary = SaveSystem.load_state(base_dataset, save_path)
	if not load_result.ok:
		return _failure_with_state(load_result.errors)
	var summary_result := build_summary(load_result.state, save_path)
	if not summary_result.ok:
		return _failure_with_state(summary_result.errors)
	return {
		"ok": true,
		"errors": [],
		"state": load_result.state,
		"summary": summary_result.summary,
		"message": "已读取存档并重建运行时状态。",
	}


static func _current_state_text(state: Dictionary) -> String:
	return "当前: 第 %d 日 / 第 %d 月 | 城市=%d 势力=%d 武将=%d 部队=%d 战报=%d 日志=%d" % [
		int(state.current_day),
		int(state.current_month),
		state.cities.size(),
		state.forces.size(),
		state.officers.size(),
		state.armies.size(),
		state.battle_logs.size(),
		_log_count(state),
	]


static func _read_save_file_summary(save_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {
			"ok": true,
			"errors": [],
			"exists": false,
			"text": "存档文件: 不存在",
		}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _failure(["save file cannot be opened: %s" % save_path])
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return _failure(["save file is not valid JSON: %s" % save_path])
	for key in ["version", "current_day", "current_month", "cities", "forces", "officers", "armies", "battle_logs"]:
		if not parsed.has(key):
			return _failure(["save file missing key %s: %s" % [key, save_path]])
	var cities: Dictionary = parsed.cities
	var forces: Dictionary = parsed.forces
	var officers: Dictionary = parsed.officers
	var armies: Dictionary = parsed.armies
	var battle_logs: Dictionary = parsed.battle_logs
	return {
		"ok": true,
		"errors": [],
		"exists": true,
		"text": "存档文件: schema=%s 第 %d 日 / 第 %d 月 | 城市=%d 势力=%d 武将=%d 部队=%d 战报=%d" % [
			str(parsed.version),
			int(parsed.current_day),
			int(parsed.current_month),
			cities.size(),
			forces.size(),
			officers.size(),
			armies.size(),
			battle_logs.size(),
		],
	}


static func _log_count(state: Dictionary) -> int:
	return state.legitimacy_logs.size() + state.local_governance_logs.size() + state.loyalty_logs.size() + state.diplomacy_logs.size() + state.scheme_states.size()


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("save load state missing key %s" % key)
	return errors


static func _validate_base_dataset(base_dataset: Dictionary) -> Array[String]:
	if base_dataset.is_empty():
		return ["save load base dataset is empty; load requires validated core dataset"]
	return []


static func _validate_save_path(save_path: String) -> Array[String]:
	if save_path.strip_edges().is_empty():
		return ["save load path is empty"]
	if not save_path.begins_with("user://"):
		return ["save load path must use user://: %s" % save_path]
	return []


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"summary": {},
	}


static func _failure_with_state(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"state": {},
		"summary": {},
	}
