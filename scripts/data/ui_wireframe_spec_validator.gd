extends RefCounted

const REQUIRED_ROOT_FIELDS := ["schema_version", "source", "wireframes"]
const REQUIRED_SOURCE_FIELDS := ["stage", "boundary_rule", "style_reference", "requirements_source"]
const REQUIRED_WIREFRAME_FIELDS := [
	"id",
	"title_cn",
	"implementation_status",
	"layout_regions",
	"primary_components",
	"state_bindings",
	"interactions",
	"blocked_until",
]
const REQUIRED_WIREFRAME_IDS := [
	"strategic_map",
	"city_detail_panel",
	"formal_officer_roster",
	"appointment_sortie_panel",
	"battle_report_panel",
	"event_log_panel",
	"save_load_panel",
	"candidate_officer_workbench",
]
const ALLOWED_STATUSES := ["wireframe_specified", "content_alpha_tool"]


static func validate_spec(spec: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not spec.has(field):
			errors.append("ui wireframe spec missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(spec.schema_version) or int(spec.schema_version) < 1:
		errors.append("ui wireframe spec schema_version must be a positive integer")
	if not spec.source is Dictionary:
		errors.append("ui wireframe spec source must be a dictionary")
	else:
		_validate_source(spec.source, errors)
	if not spec.wireframes is Array:
		errors.append("ui wireframe spec wireframes must be an array")
	else:
		_validate_wireframes(spec.wireframes, errors)
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("ui wireframe spec source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("ui wireframe spec source.%s empty required field" % field)
	if source.has("boundary_rule") and not str(source.boundary_rule).contains("not a finished Beta UI"):
		errors.append("ui wireframe spec source.boundary_rule must state it is not a finished Beta UI")
	if source.has("style_reference"):
		_validate_res_path("source.style_reference", str(source.style_reference), errors)


static func _validate_wireframes(wireframes: Array, errors: Array[String]) -> void:
	var ids := {}
	for index in wireframes.size():
		var wireframe = wireframes[index]
		if not wireframe is Dictionary:
			errors.append("ui wireframe spec wireframes[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_WIREFRAME_FIELDS:
			if not wireframe.has(field):
				errors.append("ui wireframe spec wireframes[%d].%s missing required field" % [index, field])
			elif _is_empty_value(wireframe[field]):
				errors.append("ui wireframe spec wireframes[%d].%s empty required field" % [index, field])
		_validate_wireframe_values(index, wireframe, ids, errors)
	for required_id in REQUIRED_WIREFRAME_IDS:
		if not ids.has(required_id):
			errors.append("ui wireframe spec missing required wireframe %s" % required_id)


static func _validate_wireframe_values(index: int, wireframe: Dictionary, ids: Dictionary, errors: Array[String]) -> void:
	if wireframe.has("id"):
		var id := str(wireframe.id)
		if ids.has(id):
			errors.append("duplicate ui wireframe id %s" % id)
		ids[id] = true
	if wireframe.has("implementation_status") and not ALLOWED_STATUSES.has(str(wireframe.implementation_status)):
		errors.append("ui wireframe spec wireframes[%d].implementation_status invalid %s" % [index, str(wireframe.implementation_status)])
	for field in ["layout_regions", "primary_components", "state_bindings", "interactions", "blocked_until"]:
		if wireframe.has(field) and not wireframe[field] is Array:
			errors.append("ui wireframe spec wireframes[%d].%s must be an array" % [index, field])
	if wireframe.has("layout_regions") and wireframe.layout_regions is Array and wireframe.layout_regions.size() < 3:
		errors.append("ui wireframe spec wireframes[%d] must declare at least three layout regions" % index)
	if wireframe.has("interactions") and wireframe.interactions is Array and wireframe.interactions.size() < 2:
		errors.append("ui wireframe spec wireframes[%d] must declare at least two interactions" % index)
	if wireframe.has("state_bindings") and wireframe.state_bindings is Array:
		for binding in wireframe.state_bindings:
			var binding_text := str(binding)
			if binding_text.begins_with("res://"):
				_validate_res_path("wireframes[%d].state_bindings" % index, binding_text, errors)


static func _validate_res_path(label: String, res_path: String, errors: Array[String]) -> void:
	if not res_path.begins_with("res://"):
		errors.append("ui wireframe spec %s must use res:// path: %s" % [label, res_path])
	elif not FileAccess.file_exists(res_path):
		errors.append("ui wireframe spec %s missing file %s" % [label, res_path])


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
