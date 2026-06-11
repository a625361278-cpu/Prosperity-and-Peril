extends RefCounted

const REQUIRED_ROOT_FIELDS := ["schema_version", "source", "asset_count", "records"]
const REQUIRED_SOURCE_FIELDS := ["import_manifest_path", "selection_rule", "scope_rule", "project_rule"]
const REQUIRED_RECORD_FIELDS := [
	"half_body",
	"portrait_res_path",
	"file_name",
	"width",
	"height",
	"byte_size",
	"sha256",
	"representative_source_hero_id",
	"representative_source_name_cn",
	"source_hero_bindings",
]
const REQUIRED_BINDING_FIELDS := ["source_hero_id", "source_name_key", "source_name_cn"]
const DISALLOWED_GAMEPLAY_FIELDS := ["source_power", "source_up_point", "skill_ids", "secret_ids", "biography_cn"]


static func validate_pool(pool: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not pool.has(field):
			errors.append("reusable hero portrait pool missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(pool.schema_version) or int(pool.schema_version) < 1:
		errors.append("reusable hero portrait pool schema_version must be a positive integer")
	if not pool.source is Dictionary:
		errors.append("reusable hero portrait pool source must be a dictionary")
	else:
		_validate_source(pool.source, errors)
	if not _is_integer_number(pool.asset_count) or int(pool.asset_count) <= 0:
		errors.append("reusable hero portrait pool asset_count must be a positive integer")
	if not pool.records is Array:
		errors.append("reusable hero portrait pool records must be an array")
	else:
		if _is_integer_number(pool.asset_count) and pool.records.size() != int(pool.asset_count):
			errors.append("reusable hero portrait pool asset_count does not match records")
		_validate_records(pool.records, errors)
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("reusable hero portrait pool source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("reusable hero portrait pool source.%s empty required field" % field)
	if source.has("scope_rule") and not str(source.scope_rule).contains("do not import source gameplay fields"):
		errors.append("reusable hero portrait pool source.scope_rule must forbid source gameplay fields")
	if source.has("project_rule") and not str(source.project_rule).contains("skip officers without portraits"):
		errors.append("reusable hero portrait pool source.project_rule must allow skipping officers without portraits")
	if source.has("import_manifest_path") and not FileAccess.file_exists(str(source.import_manifest_path)):
		errors.append("reusable hero portrait pool source.import_manifest_path missing file %s" % str(source.import_manifest_path))


static func _validate_records(records: Array, errors: Array[String]) -> void:
	var half_bodies := {}
	for index in records.size():
		var record = records[index]
		if not record is Dictionary:
			errors.append("reusable hero portrait pool records[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_RECORD_FIELDS:
			if not record.has(field):
				errors.append("reusable hero portrait pool records[%d].%s missing required field" % [index, field])
			elif _is_empty_value(record[field]):
				errors.append("reusable hero portrait pool records[%d].%s empty required field" % [index, field])
		for field in DISALLOWED_GAMEPLAY_FIELDS:
			if record.has(field):
				errors.append("reusable hero portrait pool records[%d] leaked source gameplay field %s" % [index, field])
		_validate_record_values(index, record, half_bodies, errors)


static func _validate_record_values(index: int, record: Dictionary, half_bodies: Dictionary, errors: Array[String]) -> void:
	if record.has("half_body"):
		var half_body := str(record.half_body)
		if half_bodies.has(half_body):
			errors.append("duplicate reusable hero portrait half_body %s" % half_body)
		half_bodies[half_body] = true
	for field in ["width", "height", "byte_size", "representative_source_hero_id"]:
		if record.has(field) and (not _is_integer_number(record[field]) or int(record[field]) <= 0):
			errors.append("reusable hero portrait pool records[%d].%s must be a positive integer" % [index, field])
	if record.has("sha256") and str(record.sha256).length() != 64:
		errors.append("reusable hero portrait pool records[%d].sha256 must be 64 hex characters" % index)
	if record.has("portrait_res_path") and not FileAccess.file_exists(str(record.portrait_res_path)):
		errors.append("reusable hero portrait pool records[%d].portrait_res_path missing file %s" % [index, str(record.portrait_res_path)])
	if record.has("source_hero_bindings"):
		_validate_source_bindings(index, record, errors)


static func _validate_source_bindings(index: int, record: Dictionary, errors: Array[String]) -> void:
	if not record.source_hero_bindings is Array:
		errors.append("reusable hero portrait pool records[%d].source_hero_bindings must be an array" % index)
		return
	var has_representative := false
	for binding_index in record.source_hero_bindings.size():
		var binding = record.source_hero_bindings[binding_index]
		if not binding is Dictionary:
			errors.append("reusable hero portrait pool records[%d].source_hero_bindings[%d] must be a dictionary" % [index, binding_index])
			continue
		for field in REQUIRED_BINDING_FIELDS:
			if not binding.has(field) or _is_empty_value(binding[field]):
				errors.append("reusable hero portrait pool records[%d].source_hero_bindings[%d].%s missing required field" % [index, binding_index, field])
		for field in DISALLOWED_GAMEPLAY_FIELDS:
			if binding.has(field):
				errors.append("reusable hero portrait pool records[%d].source_hero_bindings[%d] leaked source gameplay field %s" % [index, binding_index, field])
		if binding.has("source_hero_id") and _is_integer_number(binding.source_hero_id):
			if int(binding.source_hero_id) == int(record.representative_source_hero_id):
				has_representative = true
	if not has_representative:
		errors.append("reusable hero portrait pool records[%d] representative source hero is not in source_hero_bindings" % index)


static func _is_empty_value(value) -> bool:
	if value is Array:
		return value.is_empty()
	return value == null or str(value).is_empty()


static func _is_integer_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), float(int(value)))
	return false


static func _result(errors: Array[String]) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}
