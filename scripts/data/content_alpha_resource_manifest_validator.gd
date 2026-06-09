extends RefCounted


const REQUIRED_ROOT_FIELDS := ["schema_version", "resource_packs"]
const REQUIRED_PACK_FIELDS := [
	"id",
	"kind",
	"index_path",
	"source_project",
	"ownership_status",
	"source_paths",
	"usage_scope",
	"allowed_contexts",
	"notes",
]
const OWNERSHIP_STATUSES := ["project_owner_resource", "generated_project_resource", "third_party_resource"]


static func validate_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not manifest.has(field):
			errors.append("content alpha resource manifest missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(manifest.schema_version) or int(manifest.schema_version) < 1:
		errors.append("content alpha resource manifest schema_version must be a positive integer")
	if not manifest.resource_packs is Array:
		errors.append("content alpha resource manifest resource_packs must be an array")
	else:
		_validate_packs(manifest.resource_packs, errors)
	return _result(errors)


static func _validate_packs(packs: Array, errors: Array[String]) -> void:
	var ids := {}
	for index in packs.size():
		var pack = packs[index]
		if not pack is Dictionary:
			errors.append("content alpha resource manifest resource_packs[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_PACK_FIELDS:
			if not pack.has(field):
				errors.append("content alpha resource manifest resource_packs[%d].%s missing required field" % [index, field])
			elif _is_empty_value(pack[field]):
				errors.append("content alpha resource manifest resource_packs[%d].%s empty required field" % [index, field])
		if pack.has("id"):
			var pack_id := str(pack.id)
			if ids.has(pack_id):
				errors.append("duplicate content alpha resource pack id %s" % pack_id)
			ids[pack_id] = true
		_validate_ownership(index, pack, errors)
		_validate_paths(index, pack, errors)


static func _validate_ownership(index: int, pack: Dictionary, errors: Array[String]) -> void:
	if not pack.has("ownership_status"):
		return
	var status := str(pack.ownership_status)
	if not OWNERSHIP_STATUSES.has(status):
		errors.append("content alpha resource manifest resource_packs[%d].ownership_status invalid %s" % [index, status])
	if status == "project_owner_resource" and pack.has("source_project") and str(pack.source_project).is_empty():
		errors.append("content alpha resource manifest resource_packs[%d] project_owner_resource requires source_project" % index)


static func _validate_paths(index: int, pack: Dictionary, errors: Array[String]) -> void:
	if pack.has("index_path") and not FileAccess.file_exists(str(pack.index_path)):
		errors.append("content alpha resource manifest resource_packs[%d].index_path missing file %s" % [index, str(pack.index_path)])
	if pack.has("source_paths") and pack.source_paths is Array:
		for source_path in pack.source_paths:
			if str(source_path).is_empty():
				errors.append("content alpha resource manifest resource_packs[%d].source_paths contains empty path" % index)


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
