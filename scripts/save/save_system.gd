extends RefCounted

const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")

const CITY_DYNAMIC_FIELDS := [
	"force_id",
	"troops",
	"food",
	"public_order",
	"morale_public",
	"recovery_state",
	"integration_progress",
	"previous_force_id",
	"governor_officer_id",
]

const OFFICER_DYNAMIC_FIELDS := [
	"assignment_type",
	"assignment_target_id",
]

const FORCE_DYNAMIC_FIELDS := [
	"legitimacy",
	"prestige",
]

const SAVE_VERSION := 3


static func save_state(state: Dictionary, path: String) -> Dictionary:
	var errors := _validate_state_for_save(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var save_data := {
		"version": SAVE_VERSION,
		"current_day": state.current_day,
		"current_month": state.current_month,
		"next_army_seq": state.next_army_seq,
		"next_battle_seq": state.next_battle_seq,
		"next_diplomacy_log_seq": state.next_diplomacy_log_seq,
		"next_scheme_seq": state.next_scheme_seq,
		"next_legitimacy_log_seq": state.next_legitimacy_log_seq,
		"cities": _extract_dynamic_rows(state.cities, CITY_DYNAMIC_FIELDS),
		"forces": _extract_dynamic_rows(state.forces, FORCE_DYNAMIC_FIELDS),
		"officers": _extract_dynamic_rows(state.officers, OFFICER_DYNAMIC_FIELDS),
		"armies": state.armies.duplicate(true),
		"battle_logs": state.battle_logs.duplicate(true),
		"legitimacy_logs": state.legitimacy_logs.duplicate(true),
		"active_policies": state.active_policies.duplicate(true),
		"diplomacy_states": state.diplomacy_states.duplicate(true),
		"diplomacy_logs": state.diplomacy_logs.duplicate(true),
		"scheme_states": state.scheme_states.duplicate(true),
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["save file cannot be opened for write: %s" % path]}
	file.store_string(JSON.stringify(save_data, "\t"))
	return {"ok": true, "errors": []}


static func load_state(base_dataset: Dictionary, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["save file not found: %s" % path],
			"state": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["save file cannot be opened: %s" % path],
			"state": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["save file is not valid JSON: %s" % path],
			"state": {},
		}

	var state_result: Dictionary = CoreStateFactory.build_from_dataset(base_dataset)
	if not state_result.ok:
		return {
			"ok": false,
			"errors": state_result.errors,
			"state": {},
		}

	var state: Dictionary = state_result.state
	var errors := _apply_save_data(state, parsed)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"state": {},
		}
	return {
		"ok": true,
		"errors": [],
		"state": state,
	}


static func _validate_state_for_save(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["current_day", "current_month", "next_army_seq", "next_battle_seq", "next_diplomacy_log_seq", "next_scheme_seq", "next_legitimacy_log_seq", "cities", "forces", "officers", "armies", "battle_logs", "legitimacy_logs", "active_policies", "diplomacy_states", "diplomacy_logs", "scheme_states"]:
		if not state.has(key):
			errors.append("save state missing key %s" % key)
	return errors


static func _extract_dynamic_rows(rows: Dictionary, fields: Array) -> Dictionary:
	var result := {}
	for row_id in rows.keys():
		var source: Dictionary = rows[row_id]
		var target := {}
		for field in fields:
			if source.has(field):
				target[field] = source[field]
		result[row_id] = target
	return result


static func _apply_save_data(state: Dictionary, save_data: Dictionary) -> Array[String]:
	var errors := _validate_save_data(save_data)
	if not errors.is_empty():
		return errors

	state.current_day = int(save_data.current_day)
	state.current_month = int(save_data.current_month)
	state.next_army_seq = int(save_data.next_army_seq)
	state.next_battle_seq = int(save_data.next_battle_seq)
	state.next_diplomacy_log_seq = int(save_data.next_diplomacy_log_seq)
	state.next_scheme_seq = int(save_data.next_scheme_seq)
	state.next_legitimacy_log_seq = int(save_data.next_legitimacy_log_seq)

	_apply_dynamic_rows(state.cities, save_data.cities, errors, "cities")
	_apply_dynamic_rows(state.forces, save_data.forces, errors, "forces")
	_apply_dynamic_rows(state.officers, save_data.officers, errors, "officers")
	if not errors.is_empty():
		return errors

	state.armies = save_data.armies.duplicate(true)
	state.battle_logs = save_data.battle_logs.duplicate(true)
	state.legitimacy_logs = save_data.legitimacy_logs.duplicate(true)
	state.active_policies = save_data.active_policies.duplicate(true)
	state.diplomacy_states = save_data.diplomacy_states.duplicate(true)
	state.diplomacy_logs = save_data.diplomacy_logs.duplicate(true)
	state.scheme_states = save_data.scheme_states.duplicate(true)
	return errors


static func _validate_save_data(save_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["version", "current_day", "current_month", "next_army_seq", "next_battle_seq", "next_diplomacy_log_seq", "next_scheme_seq", "next_legitimacy_log_seq", "cities", "forces", "officers", "armies", "battle_logs", "legitimacy_logs", "active_policies", "diplomacy_states", "diplomacy_logs", "scheme_states"]:
		if not save_data.has(key):
			errors.append("save data missing key %s" % key)
	if errors.is_empty() and int(save_data.version) != SAVE_VERSION:
		errors.append("unsupported save version %s" % save_data.version)
	return errors


static func _apply_dynamic_rows(base_rows: Dictionary, saved_rows: Dictionary, errors: Array[String], table_name: String) -> void:
	for row_id in saved_rows.keys():
		if not base_rows.has(row_id):
			errors.append("save references missing %s id %s" % [table_name, row_id])
			continue
		var base_row: Dictionary = base_rows[row_id]
		var saved_row: Dictionary = saved_rows[row_id]
		for field in saved_row.keys():
			base_row[field] = saved_row[field]
