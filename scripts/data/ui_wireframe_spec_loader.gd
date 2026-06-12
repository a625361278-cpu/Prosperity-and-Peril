extends RefCounted

const UiWireframeSpecValidator = preload("res://scripts/data/ui_wireframe_spec_validator.gd")

const DEFAULT_SPEC_PATH := "res://data/content_alpha/ui_wireframe_spec.json"


static func load_default_spec() -> Dictionary:
	return load_and_build_lookup(DEFAULT_SPEC_PATH)


static func load_and_build_lookup(path: String) -> Dictionary:
	var load_result := _load_spec(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"source": {},
			"wireframes": [],
			"lookup": {},
		}
	var validation: Dictionary = UiWireframeSpecValidator.validate_spec(load_result.spec)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"source": load_result.spec.get("source", {}),
			"wireframes": [],
			"lookup": {},
		}
	var wireframes: Array = load_result.spec.wireframes.duplicate(true)
	return {
		"ok": true,
		"errors": [],
		"source": load_result.spec.source,
		"wireframes": wireframes,
		"lookup": _build_lookup(wireframes),
	}


static func resolve_wireframe(lookup: Dictionary, wireframe_id: String) -> Dictionary:
	if not lookup.has(wireframe_id):
		return {
			"ok": false,
			"errors": ["ui wireframe spec missing wireframe id %s" % wireframe_id],
			"wireframe": {},
		}
	return {
		"ok": true,
		"errors": [],
		"wireframe": lookup[wireframe_id].duplicate(true),
	}


static func _load_spec(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["ui wireframe spec file not found: %s" % path],
			"spec": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["ui wireframe spec file cannot be opened: %s" % path],
			"spec": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["ui wireframe spec root must be a JSON object: %s" % path],
			"spec": {},
		}
	return {
		"ok": true,
		"errors": [],
		"spec": parsed,
	}


static func _build_lookup(wireframes: Array) -> Dictionary:
	var lookup := {}
	for wireframe in wireframes:
		lookup[str(wireframe.id)] = wireframe
	return lookup
