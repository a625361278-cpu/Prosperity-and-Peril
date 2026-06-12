extends SceneTree

const ContentAlphaThemeBuilder = preload("res://scripts/ui/content_alpha_theme_builder.gd")
const ContentAlphaThemeLoader = preload("res://scripts/ui/content_alpha_theme_loader.gd")
const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("content alpha formal theme resource loads", _test_theme_resource_loads)
	_run("content alpha formal theme matches tokens", _test_theme_matches_tokens)
	_run("content alpha formal theme rejects drift", _test_theme_rejects_drift)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_theme_resource_loads() -> Dictionary:
	var result: Dictionary = ContentAlphaThemeLoader.load_default_theme()
	if not result.ok:
		return {"ok": false, "message": "expected theme load success, got %s" % [result.errors]}
	if result.theme == null:
		return {"ok": false, "message": "theme resource was not returned"}
	if int(result.control_types) != 3:
		return {"ok": false, "message": "unexpected theme control type count"}
	return {"ok": true}


func _test_theme_matches_tokens() -> Dictionary:
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return {"ok": false, "message": "expected token load success, got %s" % [token_result.errors]}
	var built_theme := ContentAlphaThemeBuilder.build_theme(token_result.tokens)
	var validation: Dictionary = ContentAlphaThemeLoader.validate_theme(built_theme, token_result.tokens)
	if not validation.ok:
		return {"ok": false, "message": "builder created a theme that failed validation: %s" % [validation.errors]}
	return {"ok": true}


func _test_theme_rejects_drift() -> Dictionary:
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return {"ok": false, "message": "expected token load success, got %s" % [token_result.errors]}
	var drifted_theme := ContentAlphaThemeBuilder.build_theme(token_result.tokens)
	drifted_theme.set_font_size("font_size", "Button", 99)
	var validation: Dictionary = ContentAlphaThemeLoader.validate_theme(drifted_theme, token_result.tokens)
	if validation.ok:
		return {"ok": false, "message": "expected drifted theme to fail validation"}
	for error in validation.errors:
		if str(error).contains("Button.font_size mismatch"):
			return {"ok": true}
	return {"ok": false, "message": "expected Button.font_size mismatch, got %s" % [validation.errors]}
