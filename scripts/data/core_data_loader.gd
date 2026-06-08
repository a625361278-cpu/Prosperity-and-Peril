extends RefCounted

const DataValidator = preload("res://scripts/data/data_validator.gd")


static func load_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(["data file not found: %s" % path])

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(["data file cannot be opened: %s" % path])

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return _failure(["data file is not valid JSON: %s" % path])
	if not parsed is Dictionary:
		return _failure(["data file root must be a JSON object: %s" % path])

	var validation: Dictionary = DataValidator.validate_dataset(parsed)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"dataset": parsed,
		}

	return {
		"ok": true,
		"errors": [],
		"dataset": parsed,
	}


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"dataset": {},
	}

