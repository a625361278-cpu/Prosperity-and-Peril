extends RefCounted

const UiThemeTokenValidator = preload("res://scripts/data/ui_theme_token_validator.gd")

const DEFAULT_TOKENS_PATH := "res://data/content_alpha/ui_theme_tokens.json"


static func load_default_tokens() -> Dictionary:
	return load_tokens(DEFAULT_TOKENS_PATH)


static func load_tokens(path: String) -> Dictionary:
	var load_result := _load_tokens(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"source": {},
			"tokens": {},
		}
	var validation: Dictionary = UiThemeTokenValidator.validate_tokens(load_result.tokens)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"source": load_result.tokens.get("source", {}),
			"tokens": {},
		}
	return {
		"ok": true,
		"errors": [],
		"source": load_result.tokens.source,
		"tokens": load_result.tokens.duplicate(true),
	}


static func _load_tokens(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["ui theme tokens file not found: %s" % path],
			"tokens": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["ui theme tokens file cannot be opened: %s" % path],
			"tokens": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["ui theme tokens root must be a JSON object: %s" % path],
			"tokens": {},
		}
	return {
		"ok": true,
		"errors": [],
		"tokens": parsed,
	}
