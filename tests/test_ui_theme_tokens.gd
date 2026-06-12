extends SceneTree

const UiThemeTokenValidator = preload("res://scripts/data/ui_theme_token_validator.gd")
const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")

const TOKENS_PATH := "res://data/content_alpha/ui_theme_tokens.json"


var _failed := 0


func _initialize() -> void:
	_run("ui theme tokens are valid", _test_tokens_are_valid)
	_run("ui theme token loader exposes formal style tokens", _test_loader_exposes_tokens)
	_run("ui theme tokens reject invalid color", _test_rejects_invalid_color)
	_run("ui theme tokens reject missing palette reference", _test_rejects_missing_palette_reference)
	_run("ui theme tokens reject missing style reference", _test_rejects_missing_style_reference)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_tokens_are_valid() -> Dictionary:
	var token_result := _load_tokens()
	if not token_result.ok:
		return token_result
	var validation: Dictionary = UiThemeTokenValidator.validate_tokens(token_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid ui theme tokens, got %s" % [validation.errors]}
	return {"ok": true}


func _test_loader_exposes_tokens() -> Dictionary:
	var load_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not load_result.ok:
		return {"ok": false, "message": "expected ui theme token load success, got %s" % [load_result.errors]}
	if str(load_result.tokens.palette.accent_gold) != "#C69A3E":
		return {"ok": false, "message": "accent gold token mismatch"}
	if int(load_result.tokens.shape.corner_radius) != 6:
		return {"ok": false, "message": "corner radius token mismatch"}
	if not str(load_result.source.boundary_rule).contains("not a finished Beta UI"):
		return {"ok": false, "message": "theme token boundary missing"}
	return {"ok": true}


func _test_rejects_invalid_color() -> Dictionary:
	var token_result := _load_tokens()
	if not token_result.ok:
		return token_result
	var copied: Dictionary = token_result.data.duplicate(true)
	copied.palette.accent_gold = "gold"
	var validation: Dictionary = UiThemeTokenValidator.validate_tokens(copied)
	return _expect_error_contains(validation, "palette.accent_gold must be #RRGGBB")


func _test_rejects_missing_palette_reference() -> Dictionary:
	var token_result := _load_tokens()
	if not token_result.ok:
		return token_result
	var copied: Dictionary = token_result.data.duplicate(true)
	copied.controls.button.hover = "missing_color"
	var validation: Dictionary = UiThemeTokenValidator.validate_tokens(copied)
	return _expect_error_contains(validation, "references missing palette color missing_color")


func _test_rejects_missing_style_reference() -> Dictionary:
	var token_result := _load_tokens()
	if not token_result.ok:
		return token_result
	var copied: Dictionary = token_result.data.duplicate(true)
	copied.source.style_reference = "res://docs/资源/ui_style_concepts/missing_style.png"
	var validation: Dictionary = UiThemeTokenValidator.validate_tokens(copied)
	return _expect_error_contains(validation, "source.style_reference missing file")


func _load_tokens() -> Dictionary:
	if not FileAccess.file_exists(TOKENS_PATH):
		return {"ok": false, "message": "ui theme tokens missing: %s" % TOKENS_PATH}
	var file := FileAccess.open(TOKENS_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "ui theme tokens cannot be opened: %s" % TOKENS_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "ui theme tokens root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
