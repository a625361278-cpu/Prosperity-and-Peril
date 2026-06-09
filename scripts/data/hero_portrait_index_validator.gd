extends RefCounted


const REQUIRED_ROOT_FIELDS := ["schema_version", "source", "records"]
const REQUIRED_SOURCE_FIELDS := ["hero_xlsx", "lang_xlsx", "portrait_dir", "mapping_rule", "usage_scope"]
const REQUIRED_RECORD_FIELDS := ["id", "name_key", "name_cn", "half_body", "portrait_file", "portrait_source_path"]


static func validate_index(index: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not index.has(field):
			errors.append("hero portrait index missing %s" % field)

	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(index.schema_version) or int(index.schema_version) < 1:
		errors.append("hero portrait index schema_version must be a positive integer")
	if not index.source is Dictionary:
		errors.append("hero portrait index source must be a dictionary")
	else:
		_validate_source(index.source, errors)
	if not index.records is Array:
		errors.append("hero portrait index records must be an array")
	else:
		_validate_records(index.records, errors)
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("hero portrait index source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("hero portrait index source.%s empty required field" % field)
	if source.has("mapping_rule") and not str(source.mapping_rule).contains("halfBody"):
		errors.append("hero portrait index source.mapping_rule must state that halfBody is authoritative")


static func _validate_records(records: Array, errors: Array[String]) -> void:
	var ids := {}
	for index in records.size():
		var record = records[index]
		if not record is Dictionary:
			errors.append("hero portrait index records[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_RECORD_FIELDS:
			if not record.has(field):
				errors.append("hero portrait index records[%d].%s missing required field" % [index, field])
			elif str(record[field]).is_empty():
				errors.append("hero portrait index records[%d].%s empty required field" % [index, field])
		if record.has("id"):
			if not _is_integer_number(record.id):
				errors.append("hero portrait index records[%d].id must be an integer" % index)
			else:
				var hero_id := int(record.id)
				if ids.has(hero_id):
					errors.append("duplicate hero portrait index id %d" % hero_id)
				ids[hero_id] = true
		if record.has("portrait_file") and not str(record.portrait_file).ends_with(".png"):
			errors.append("hero portrait index records[%d].portrait_file must be a png file" % index)
		if record.has("half_body") and record.has("portrait_file"):
			if str(record.portrait_file) != "%s.png" % str(record.half_body):
				errors.append("hero portrait index records[%d].portrait_file must match half_body" % index)


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
