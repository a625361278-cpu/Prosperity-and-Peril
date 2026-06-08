extends RefCounted

const DataValidator = preload("res://scripts/data/data_validator.gd")


static func build_from_dataset(dataset: Dictionary) -> Dictionary:
	var validation: Dictionary = DataValidator.validate_dataset(dataset)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"state": {},
		}

	var state := {
		"current_day": 0,
		"current_month": 1,
		"next_army_seq": 1,
		"next_battle_seq": 1,
		"next_diplomacy_log_seq": 1,
		"next_scheme_seq": 1,
		"next_legitimacy_log_seq": 1,
		"next_local_governance_log_seq": 1,
		"cities": _index_rows(dataset.cities),
		"forces": _force_rows(dataset.forces),
		"officers": _index_rows(dataset.officers),
		"routes": _index_rows(dataset.routes),
		"armies": {},
		"battle_logs": {},
		"legitimacy_logs": {},
		"local_governance_logs": {},
		"active_policies": {},
		"diplomacy_states": {},
		"diplomacy_logs": {},
		"scheme_states": {},
	}

	return {
		"ok": true,
		"errors": [],
		"state": state,
	}


static func _index_rows(rows: Array) -> Dictionary:
	var indexed := {}
	for row in rows:
		var row_copy: Dictionary = row.duplicate(true)
		indexed[str(row_copy.id)] = row_copy
	return indexed


static func _force_rows(rows: Array) -> Dictionary:
	var indexed := {}
	for row in rows:
		var row_copy: Dictionary = row.duplicate(true)
		row_copy.legitimacy = int(row_copy.legitimacy_base)
		row_copy.prestige = int(row_copy.prestige_base)
		indexed[str(row_copy.id)] = row_copy
	return indexed
