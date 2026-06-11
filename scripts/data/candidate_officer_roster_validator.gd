extends RefCounted

const REQUIRED_ROOT_FIELDS := ["schema_version", "source", "candidate_count", "records"]
const REQUIRED_SOURCE_FIELDS := ["portrait_pool_path", "roster_rule", "gameplay_field_rule", "selection_rule"]
const REQUIRED_RECORD_FIELDS := [
	"candidate_officer_id",
	"display_name_cn",
	"selection_status",
	"half_body",
	"portrait_res_path",
	"source_reference",
]
const REQUIRED_SOURCE_REFERENCE_FIELDS := ["representative_source_hero_id", "source_hero_bindings"]
const ALLOWED_SELECTION_STATUS := ["candidate", "selected", "rejected"]
const DISALLOWED_GAMEPLAY_FIELDS := [
	"force_id",
	"faction_id",
	"office",
	"stats",
	"leadership",
	"war",
	"intelligence",
	"politics",
	"charm",
	"skill_ids",
	"secret_ids",
	"biography_cn",
]


static func validate_roster(roster: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not roster.has(field):
			errors.append("candidate officer roster missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(roster.schema_version) or int(roster.schema_version) < 1:
		errors.append("candidate officer roster schema_version must be a positive integer")
	if not roster.source is Dictionary:
		errors.append("candidate officer roster source must be a dictionary")
	else:
		_validate_source(roster.source, errors)
	if not _is_integer_number(roster.candidate_count) or int(roster.candidate_count) <= 0:
		errors.append("candidate officer roster candidate_count must be a positive integer")
	if not roster.records is Array:
		errors.append("candidate officer roster records must be an array")
	else:
		if _is_integer_number(roster.candidate_count) and roster.records.size() != int(roster.candidate_count):
			errors.append("candidate officer roster candidate_count does not match records")
		_validate_records(roster.records, errors)
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("candidate officer roster source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("candidate officer roster source.%s empty required field" % field)
	if source.has("portrait_pool_path") and not FileAccess.file_exists(str(source.portrait_pool_path)):
		errors.append("candidate officer roster source.portrait_pool_path missing file %s" % str(source.portrait_pool_path))
	if source.has("roster_rule") and not str(source.roster_rule).contains("not the final officer database"):
		errors.append("candidate officer roster source.roster_rule must state it is not the final officer database")
	if source.has("gameplay_field_rule") and not str(source.gameplay_field_rule).contains("do not add stats, skills"):
		errors.append("candidate officer roster source.gameplay_field_rule must forbid gameplay fields")


static func _validate_records(records: Array, errors: Array[String]) -> void:
	var ids := {}
	var half_bodies := {}
	for index in records.size():
		var record = records[index]
		if not record is Dictionary:
			errors.append("candidate officer roster records[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_RECORD_FIELDS:
			if not record.has(field):
				errors.append("candidate officer roster records[%d].%s missing required field" % [index, field])
			elif _is_empty_value(record[field]):
				errors.append("candidate officer roster records[%d].%s empty required field" % [index, field])
		for field in DISALLOWED_GAMEPLAY_FIELDS:
			if record.has(field):
				errors.append("candidate officer roster records[%d] leaked gameplay field %s" % [index, field])
		_validate_record_values(index, record, ids, half_bodies, errors)


static func _validate_record_values(index: int, record: Dictionary, ids: Dictionary, half_bodies: Dictionary, errors: Array[String]) -> void:
	if record.has("candidate_officer_id"):
		var candidate_id := str(record.candidate_officer_id)
		if not candidate_id.begins_with("CANDIDATE_"):
			errors.append("candidate officer roster records[%d].candidate_officer_id must begin with CANDIDATE_" % index)
		if ids.has(candidate_id):
			errors.append("duplicate candidate officer id %s" % candidate_id)
		ids[candidate_id] = true
	if record.has("selection_status") and not ALLOWED_SELECTION_STATUS.has(str(record.selection_status)):
		errors.append("candidate officer roster records[%d].selection_status invalid %s" % [index, str(record.selection_status)])
	if record.has("half_body"):
		var half_body := str(record.half_body)
		if half_bodies.has(half_body):
			errors.append("duplicate candidate officer half_body %s" % half_body)
		half_bodies[half_body] = true
	if record.has("portrait_res_path") and not FileAccess.file_exists(str(record.portrait_res_path)):
		errors.append("candidate officer roster records[%d].portrait_res_path missing file %s" % [index, str(record.portrait_res_path)])
	if record.has("source_reference"):
		_validate_source_reference(index, record.source_reference, errors)


static func _validate_source_reference(index: int, source_reference, errors: Array[String]) -> void:
	if not source_reference is Dictionary:
		errors.append("candidate officer roster records[%d].source_reference must be a dictionary" % index)
		return
	for field in REQUIRED_SOURCE_REFERENCE_FIELDS:
		if not source_reference.has(field) or _is_empty_value(source_reference[field]):
			errors.append("candidate officer roster records[%d].source_reference.%s missing required field" % [index, field])
	for field in DISALLOWED_GAMEPLAY_FIELDS:
		if source_reference.has(field):
			errors.append("candidate officer roster records[%d].source_reference leaked gameplay field %s" % [index, field])
	if source_reference.has("representative_source_hero_id") and not _is_integer_number(source_reference.representative_source_hero_id):
		errors.append("candidate officer roster records[%d].source_reference.representative_source_hero_id must be an integer" % index)
	if source_reference.has("source_hero_bindings") and not source_reference.source_hero_bindings is Array:
		errors.append("candidate officer roster records[%d].source_reference.source_hero_bindings must be an array" % index)


static func _is_empty_value(value) -> bool:
	if value is Array:
		return value.is_empty()
	if value is Dictionary:
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
