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
		"cities": _index_rows(dataset.cities),
		"forces": _index_rows(dataset.forces),
		"officers": _index_rows(dataset.officers),
		"routes": _index_rows(dataset.routes),
		"armies": {},
		"battle_logs": {},
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
