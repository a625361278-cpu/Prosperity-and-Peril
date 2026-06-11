extends RefCounted


const REQUIRED_ROW_FIELDS := ["hero_id", "name_cn", "half_body", "portrait_source_path"]


static func load_texture_from_row(row: Dictionary) -> Dictionary:
	var errors := _validate_row(row)
	if not errors.is_empty():
		return _failure(errors)

	var texture_path_result := _texture_path(row)
	if not texture_path_result.ok:
		return _failure(texture_path_result.errors)
	var source_path := str(texture_path_result.path)

	var load_result := _load_texture(source_path, str(texture_path_result.path_kind))
	if not load_result.ok:
		return _failure(load_result.errors)

	return {
		"ok": true,
		"errors": [],
		"texture": load_result.texture,
		"width": load_result.width,
		"height": load_result.height,
		"hero_id": int(row.hero_id),
		"name_cn": str(row.name_cn),
		"half_body": str(row.half_body),
		"source_path": source_path,
		"path_kind": str(texture_path_result.path_kind),
	}


static func _validate_row(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in REQUIRED_ROW_FIELDS:
		if not row.has(field):
			errors.append("hero portrait texture row missing %s" % field)
		elif str(row[field]).is_empty():
			errors.append("hero portrait texture row empty %s" % field)
	if row.has("hero_id") and not _is_integer_number(row.hero_id):
		errors.append("hero portrait texture row hero_id must be an integer")
	if row.has("portrait_res_path") and str(row.portrait_res_path).is_empty():
		errors.append("hero portrait texture row empty portrait_res_path")
	return errors


static func _texture_path(row: Dictionary) -> Dictionary:
	if row.has("portrait_res_path") and not str(row.portrait_res_path).is_empty():
		var imported_path := _normalized_path(str(row.portrait_res_path))
		if not FileAccess.file_exists(imported_path):
			return {
				"ok": false,
				"errors": ["hero portrait texture imported file missing: %s" % imported_path],
				"path": "",
				"path_kind": "",
			}
		return {
			"ok": true,
			"errors": [],
			"path": imported_path,
			"path_kind": "imported_res",
		}
	var source_path := _normalized_path(str(row.portrait_source_path))
	if not FileAccess.file_exists(source_path):
		return {
			"ok": false,
			"errors": ["hero portrait texture source file missing: %s" % source_path],
			"path": "",
			"path_kind": "",
		}
	return {
		"ok": true,
		"errors": [],
		"path": source_path,
		"path_kind": "source_path",
	}


static func _load_texture(path: String, path_kind: String) -> Dictionary:
	if path_kind == "imported_res":
		var imported_texture := ResourceLoader.load(path) as Texture2D
		if imported_texture == null:
			return {
				"ok": false,
				"errors": ["hero portrait imported texture resource load failed: %s" % path],
				"texture": null,
				"width": 0,
				"height": 0,
			}
		return {
			"ok": true,
			"errors": [],
			"texture": imported_texture,
			"width": imported_texture.get_width(),
			"height": imported_texture.get_height(),
		}

	var image := Image.new()
	var load_error := image.load(path)
	if load_error != OK:
		return {
			"ok": false,
			"errors": ["hero portrait texture load failed: %s error=%d" % [path, load_error]],
			"texture": null,
			"width": 0,
			"height": 0,
		}
	if image.is_empty():
		return {
			"ok": false,
			"errors": ["hero portrait texture image is empty: %s" % path],
			"texture": null,
			"width": 0,
			"height": 0,
		}
	var source_texture := ImageTexture.create_from_image(image)
	if source_texture == null:
		return {
			"ok": false,
			"errors": ["hero portrait texture creation failed: %s" % path],
			"texture": null,
			"width": 0,
			"height": 0,
		}
	return {
		"ok": true,
		"errors": [],
		"texture": source_texture,
		"width": image.get_width(),
		"height": image.get_height(),
	}


static func _is_integer_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), float(int(value)))
	return false


static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/")


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"texture": null,
		"width": 0,
		"height": 0,
	}
