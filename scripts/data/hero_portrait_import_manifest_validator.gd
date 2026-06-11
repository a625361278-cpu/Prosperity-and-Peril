extends RefCounted

const REQUIRED_ROOT_FIELDS := [
	"schema_version",
	"resource_pack_id",
	"source_index_path",
	"target_root",
	"mapping_rule",
	"asset_count",
	"hero_binding_count",
	"assets",
	"hero_bindings",
]
const REQUIRED_ASSET_FIELDS := [
	"half_body",
	"source_path",
	"target_res_path",
	"file_name",
	"byte_size",
	"sha256",
	"width",
	"height",
]
const REQUIRED_BINDING_FIELDS := ["hero_id", "name_key", "name_cn", "half_body", "target_res_path"]


static func validate_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not manifest.has(field):
			errors.append("hero portrait import manifest missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(manifest.schema_version) or int(manifest.schema_version) < 1:
		errors.append("hero portrait import manifest schema_version must be a positive integer")
	if str(manifest.resource_pack_id).is_empty():
		errors.append("hero portrait import manifest resource_pack_id empty required field")
	if not str(manifest.mapping_rule).contains("halfBody"):
		errors.append("hero portrait import manifest mapping_rule must state that halfBody is authoritative")
	if not manifest.assets is Array:
		errors.append("hero portrait import manifest assets must be an array")
	if not manifest.hero_bindings is Array:
		errors.append("hero portrait import manifest hero_bindings must be an array")
	if not errors.is_empty():
		return _result(errors)

	_validate_assets(manifest.assets, errors)
	_validate_bindings(manifest.hero_bindings, manifest.assets, errors)
	if _is_integer_number(manifest.asset_count) and int(manifest.asset_count) != manifest.assets.size():
		errors.append("hero portrait import manifest asset_count mismatch")
	if _is_integer_number(manifest.hero_binding_count) and int(manifest.hero_binding_count) != manifest.hero_bindings.size():
		errors.append("hero portrait import manifest hero_binding_count mismatch")
	return _result(errors)


static func _validate_assets(assets: Array, errors: Array[String]) -> void:
	var half_bodies := {}
	var target_paths := {}
	for index in assets.size():
		var asset = assets[index]
		if not asset is Dictionary:
			errors.append("hero portrait import manifest assets[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_ASSET_FIELDS:
			if not asset.has(field):
				errors.append("hero portrait import manifest assets[%d].%s missing required field" % [index, field])
			elif str(asset[field]).is_empty():
				errors.append("hero portrait import manifest assets[%d].%s empty required field" % [index, field])
		if not _asset_has_required_fields(asset):
			continue

		var half_body := str(asset.half_body)
		var target_res_path := str(asset.target_res_path)
		if half_bodies.has(half_body):
			errors.append("duplicate imported hero portrait half_body %s" % half_body)
		half_bodies[half_body] = true
		if target_paths.has(target_res_path):
			errors.append("duplicate imported hero portrait target path %s" % target_res_path)
		target_paths[target_res_path] = true
		if str(asset.file_name) != "%s.png" % half_body:
			errors.append("hero portrait import manifest assets[%d].file_name must match half_body" % index)
		if not FileAccess.file_exists(str(asset.source_path)):
			errors.append("hero portrait import manifest assets[%d].source_path missing file %s" % [index, str(asset.source_path)])
		_validate_target_file(index, asset, errors)


static func _validate_target_file(index: int, asset: Dictionary, errors: Array[String]) -> void:
	var target_res_path := str(asset.target_res_path)
	if not FileAccess.file_exists(target_res_path):
		errors.append("hero portrait import manifest assets[%d].target_res_path missing file %s" % [index, target_res_path])
		return
	var file := FileAccess.open(target_res_path, FileAccess.READ)
	if file == null:
		errors.append("hero portrait import manifest assets[%d].target_res_path cannot be opened %s" % [index, target_res_path])
		return
	if _is_integer_number(asset.byte_size) and int(asset.byte_size) != file.get_length():
		errors.append("hero portrait import manifest assets[%d].byte_size mismatch" % index)
	var sha256 := _sha256_file(target_res_path)
	if sha256 != str(asset.sha256):
		errors.append("hero portrait import manifest assets[%d].sha256 mismatch" % index)

	var image := Image.new()
	var load_error := image.load(target_res_path)
	if load_error != OK:
		errors.append("hero portrait import manifest assets[%d].target_res_path image load failed error=%d" % [index, load_error])
		return
	if _is_integer_number(asset.width) and int(asset.width) != image.get_width():
		errors.append("hero portrait import manifest assets[%d].width mismatch" % index)
	if _is_integer_number(asset.height) and int(asset.height) != image.get_height():
		errors.append("hero portrait import manifest assets[%d].height mismatch" % index)


static func _validate_bindings(bindings: Array, assets: Array, errors: Array[String]) -> void:
	var assets_by_half_body := {}
	for asset in assets:
		if asset is Dictionary and asset.has("half_body") and asset.has("target_res_path"):
			assets_by_half_body[str(asset.half_body)] = str(asset.target_res_path)
	var hero_ids := {}
	for index in bindings.size():
		var binding = bindings[index]
		if not binding is Dictionary:
			errors.append("hero portrait import manifest hero_bindings[%d] must be a dictionary" % index)
			continue
		for field in REQUIRED_BINDING_FIELDS:
			if not binding.has(field):
				errors.append("hero portrait import manifest hero_bindings[%d].%s missing required field" % [index, field])
			elif str(binding[field]).is_empty():
				errors.append("hero portrait import manifest hero_bindings[%d].%s empty required field" % [index, field])
		if not _binding_has_required_fields(binding):
			continue
		if not _is_integer_number(binding.hero_id):
			errors.append("hero portrait import manifest hero_bindings[%d].hero_id must be an integer" % index)
			continue
		var hero_id := int(binding.hero_id)
		if hero_ids.has(hero_id):
			errors.append("duplicate imported hero portrait binding hero_id %d" % hero_id)
		hero_ids[hero_id] = true
		var half_body := str(binding.half_body)
		if not assets_by_half_body.has(half_body):
			errors.append("hero portrait import manifest hero_bindings[%d].half_body missing imported asset %s" % [index, half_body])
		elif assets_by_half_body[half_body] != str(binding.target_res_path):
			errors.append("hero portrait import manifest hero_bindings[%d].target_res_path does not match imported asset" % index)


static func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		context.update(file.get_buffer(1024 * 1024))
	return context.finish().hex_encode()


static func _asset_has_required_fields(asset: Dictionary) -> bool:
	for field in REQUIRED_ASSET_FIELDS:
		if not asset.has(field) or str(asset[field]).is_empty():
			return false
	return true


static func _binding_has_required_fields(binding: Dictionary) -> bool:
	for field in REQUIRED_BINDING_FIELDS:
		if not binding.has(field) or str(binding[field]).is_empty():
			return false
	return true


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
