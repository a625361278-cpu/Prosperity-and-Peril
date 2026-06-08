extends RefCounted


const REQUIRED_FIELDS := {
	"cities": ["id", "name", "force_id", "troops", "food", "public_order", "morale_public", "recovery_state"],
	"forces": ["id", "name", "ruler_officer_id", "capital_city_id"],
	"officers": ["id", "name", "force_id", "leadership", "politics"],
	"routes": ["id", "from_city_id", "to_city_id", "route_type", "distance", "terrain_modifier", "supply_modifier", "battle_trigger"],
}

const ENUM_FIELDS := {
	"cities": {
		"recovery_state": ["normal", "occupied", "unrest", "recovering"],
	},
	"routes": {
		"route_type": ["road", "mountain", "river", "sea", "pass"],
		"battle_trigger": ["none", "field", "pass", "port", "river"],
	},
}


static func validate_dataset(dataset: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var ids_by_table: Dictionary = {}

	for table_name in REQUIRED_FIELDS.keys():
		if not dataset.has(table_name):
			errors.append("missing table %s" % table_name)
			continue
		if not dataset[table_name] is Array:
			errors.append("table %s must be an array" % table_name)
			continue
		ids_by_table[table_name] = _validate_table(table_name, dataset[table_name], errors)

	if errors.is_empty():
		_validate_foreign_keys(dataset, ids_by_table, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}


static func _validate_table(table_name: String, rows: Array, errors: Array[String]) -> Dictionary:
	var ids := {}
	var required_fields: Array = REQUIRED_FIELDS[table_name]
	for index in rows.size():
		var row = rows[index]
		if not row is Dictionary:
			errors.append("%s[%d] must be a dictionary" % [table_name, index])
			continue

		for field in required_fields:
			if not row.has(field):
				errors.append("%s[%d].%s missing required field" % [table_name, index, field])
			elif row[field] == null or str(row[field]).is_empty():
				errors.append("%s[%d].%s empty required field" % [table_name, index, field])

		if row.has("id"):
			var row_id := str(row.id)
			if ids.has(row_id):
				errors.append("duplicate %s id %s" % [table_name, row_id])
			else:
				ids[row_id] = true

		if ENUM_FIELDS.has(table_name):
			for enum_field in ENUM_FIELDS[table_name].keys():
				if row.has(enum_field):
					var value := str(row[enum_field])
					if not ENUM_FIELDS[table_name][enum_field].has(value):
						errors.append("%s[%d].%s invalid enum value %s" % [table_name, index, enum_field, value])

	return ids


static func _validate_foreign_keys(dataset: Dictionary, ids_by_table: Dictionary, errors: Array[String]) -> void:
	_validate_fk(dataset, ids_by_table, errors, "cities", "force_id", "forces")
	_validate_fk(dataset, ids_by_table, errors, "forces", "ruler_officer_id", "officers")
	_validate_fk(dataset, ids_by_table, errors, "forces", "capital_city_id", "cities")
	_validate_fk(dataset, ids_by_table, errors, "officers", "force_id", "forces")
	_validate_fk(dataset, ids_by_table, errors, "routes", "from_city_id", "cities")
	_validate_fk(dataset, ids_by_table, errors, "routes", "to_city_id", "cities")


static func _validate_fk(
	dataset: Dictionary,
	ids_by_table: Dictionary,
	errors: Array[String],
	source_table: String,
	field_name: String,
	target_table: String
) -> void:
	if not dataset.has(source_table) or not ids_by_table.has(target_table):
		return
	var target_ids: Dictionary = ids_by_table[target_table]
	for index in dataset[source_table].size():
		var row = dataset[source_table][index]
		if not row is Dictionary or not row.has(field_name):
			continue
		var ref_id := str(row[field_name])
		if not target_ids.has(ref_id):
			errors.append("%s[%d].%s references missing %s id %s" % [source_table, index, field_name, target_table, ref_id])

