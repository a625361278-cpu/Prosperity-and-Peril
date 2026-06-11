extends RefCounted

const REQUIRED_ROOT_FIELDS := ["schema_version", "source", "screens"]
const REQUIRED_SOURCE_FIELDS := ["route_stage", "boundary_rule", "implementation_rule", "requirements_source"]
const REQUIRED_SCREEN_FIELDS := [
	"id",
	"title_cn",
	"category",
	"implementation_status",
	"primary_data_sources",
	"entry_points",
	"allowed_actions",
	"blocked_until",
]
const REQUIRED_SCREEN_IDS := [
	"strategic_map",
	"city_detail_panel",
	"candidate_officer_workbench",
	"formal_officer_roster",
	"appointment_sortie_panel",
	"battle_report_panel",
	"event_log_panel",
	"save_load_panel",
]
const ALLOWED_STATUSES := ["debug_available", "content_alpha_available", "planned"]


static func validate_spec(spec: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not spec.has(field):
			errors.append("ui navigation spec missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(spec.schema_version) or int(spec.schema_version) < 1:
		errors.append("ui navigation spec schema_version must be a positive integer")
	if not spec.source is Dictionary:
		errors.append("ui navigation spec source must be a dictionary")
	else:
		_validate_source(spec.source, errors)
	if not spec.screens is Array:
		errors.append("ui navigation spec screens must be an array")
	else:
		_validate_screens(spec.screens, errors)
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("ui navigation spec source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("ui navigation spec source.%s empty required field" % field)
	if source.has("boundary_rule") and not str(source.boundary_rule).contains("not a finished Beta UI"):
		errors.append("ui navigation spec source.boundary_rule must state it is not a finished Beta UI")
	if source.has("implementation_rule") and not str(source.implementation_rule).contains("planned"):
		errors.append("ui navigation spec source.implementation_rule must define planned screen boundary")


static func _validate_screens(screens: Array, errors: Array[String]) -> void:
	var ids := {}
	for index in screens.size():
		var screen = screens[index]
		if not screen is Dictionary:
			errors.append("ui navigation spec screens[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_SCREEN_FIELDS:
			if not screen.has(field):
				errors.append("ui navigation spec screens[%d].%s missing required field" % [index, field])
			elif _is_empty_value(screen[field]):
				errors.append("ui navigation spec screens[%d].%s empty required field" % [index, field])
		_validate_screen_values(index, screen, ids, errors)
	for required_id in REQUIRED_SCREEN_IDS:
		if not ids.has(required_id):
			errors.append("ui navigation spec missing required screen %s" % required_id)


static func _validate_screen_values(index: int, screen: Dictionary, ids: Dictionary, errors: Array[String]) -> void:
	if screen.has("id"):
		var id := str(screen.id)
		if ids.has(id):
			errors.append("duplicate ui navigation screen id %s" % id)
		ids[id] = true
	if screen.has("implementation_status") and not ALLOWED_STATUSES.has(str(screen.implementation_status)):
		errors.append("ui navigation spec screens[%d].implementation_status invalid %s" % [index, str(screen.implementation_status)])
	for field in ["primary_data_sources", "entry_points", "allowed_actions", "blocked_until"]:
		if screen.has(field) and not screen[field] is Array:
			errors.append("ui navigation spec screens[%d].%s must be an array" % [index, field])
	if screen.has("implementation_status") and str(screen.implementation_status) == "planned":
		if not screen.has("blocked_until") or not screen.blocked_until is Array or screen.blocked_until.is_empty():
			errors.append("ui navigation spec screens[%d] planned screen must declare blockers" % index)
	if screen.has("primary_data_sources") and screen.primary_data_sources is Array:
		for source_path in screen.primary_data_sources:
			_validate_data_source(index, str(source_path), errors)


static func _validate_data_source(index: int, source_path: String, errors: Array[String]) -> void:
	if source_path.begins_with("res://") and not FileAccess.file_exists(source_path):
		errors.append("ui navigation spec screens[%d] primary data source missing file %s" % [index, source_path])


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
