extends RefCounted

const UiNavigationSpecValidator = preload("res://scripts/data/ui_navigation_spec_validator.gd")

const DEFAULT_SPEC_PATH := "res://data/content_alpha/ui_navigation_spec.json"


static func load_default_spec() -> Dictionary:
	return load_and_build_lookup(DEFAULT_SPEC_PATH)


static func load_and_build_lookup(path: String) -> Dictionary:
	var load_result := _load_spec(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"source": {},
			"screens": [],
			"lookup": {},
		}
	var validation: Dictionary = UiNavigationSpecValidator.validate_spec(load_result.spec)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"source": load_result.spec.get("source", {}),
			"screens": [],
			"lookup": {},
		}
	var screens: Array = load_result.spec.screens.duplicate(true)
	return {
		"ok": true,
		"errors": [],
		"source": load_result.spec.source,
		"screens": screens,
		"lookup": _build_lookup(screens),
	}


static func resolve_screen(lookup: Dictionary, screen_id: String) -> Dictionary:
	if not lookup.has(screen_id):
		return {
			"ok": false,
			"errors": ["ui navigation spec missing screen id %s" % screen_id],
			"screen": {},
		}
	return {
		"ok": true,
		"errors": [],
		"screen": lookup[screen_id].duplicate(true),
	}


static func _load_spec(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["ui navigation spec file not found: %s" % path],
			"spec": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["ui navigation spec file cannot be opened: %s" % path],
			"spec": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["ui navigation spec root must be a JSON object: %s" % path],
			"spec": {},
		}
	return {
		"ok": true,
		"errors": [],
		"spec": parsed,
	}


static func _build_lookup(screens: Array) -> Dictionary:
	var lookup := {}
	for screen in screens:
		lookup[str(screen.id)] = screen
	return lookup
