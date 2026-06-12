extends RefCounted

const ContentAlphaThemeBuilder = preload("res://scripts/ui/content_alpha_theme_builder.gd")
const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")

const DEFAULT_THEME_PATH := "res://themes/content_alpha_formal_theme.tres"


static func load_default_theme() -> Dictionary:
	return load_theme(DEFAULT_THEME_PATH)


static func load_theme(path: String) -> Dictionary:
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return _failure(token_result.errors)
	if not FileAccess.file_exists(path):
		return _failure(["content alpha formal theme resource missing: %s" % path])
	var loaded := ResourceLoader.load(path)
	if not loaded is Theme:
		return _failure(["content alpha formal theme resource is not a Theme: %s" % path])
	var theme := loaded as Theme
	var validation := validate_theme(theme, token_result.tokens)
	if not validation.ok:
		return _failure(validation.errors)
	return {
		"ok": true,
		"errors": [],
		"theme": theme,
		"theme_path": path,
		"control_types": validation.control_types,
	}


static func validate_theme(theme: Theme, tokens: Dictionary) -> Dictionary:
	if theme == null:
		return _failure(["content alpha formal theme is null"])
	var errors: Array[String] = []
	var palette: Dictionary = tokens.palette
	var sizes: Dictionary = tokens.typography.sizes
	var shape: Dictionary = tokens.shape

	_expect_color(theme.get_color("font_color", "Label"), Color.html(str(palette.ink_text)), "Label.font_color", errors)
	_expect_int(theme.get_font_size("font_size", "Label"), int(sizes.body), "Label.font_size", errors)
	_expect_int(theme.get_font_size("font_size", "Button"), int(sizes.body), "Button.font_size", errors)
	_validate_style(theme.get_stylebox("panel", "PanelContainer"), Color.html(str(palette.lacquer_panel)), Color.html(str(palette.accent_gold)), int(shape.corner_radius), "PanelContainer.panel", errors)
	_validate_style(theme.get_stylebox("normal", "Button"), Color.html(str(palette.lacquer_panel)), Color.html(str(palette.accent_gold)), int(shape.corner_radius), "Button.normal", errors)
	_validate_style(theme.get_stylebox("hover", "Button"), Color.html(str(palette.accent_gold)), Color.html(str(palette.accent_gold)), int(shape.corner_radius), "Button.hover", errors)
	_validate_style(theme.get_stylebox("pressed", "Button"), Color.html(str(palette.accent_red)), Color.html(str(palette.aged_paper)), int(shape.corner_radius), "Button.pressed", errors)
	_validate_style(theme.get_stylebox("disabled", "Button"), Color.html(str(palette.neutral_force)), Color.html(str(palette.neutral_force)), int(shape.corner_radius), "Button.disabled", errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"control_types": 3,
	}


static func save_theme_from_default_tokens(path: String = DEFAULT_THEME_PATH) -> Dictionary:
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return _failure(token_result.errors)
	var theme := ContentAlphaThemeBuilder.build_theme(token_result.tokens)
	var error := ResourceSaver.save(theme, path)
	if error != OK:
		return _failure(["content alpha formal theme save failed %s: %s" % [path, str(error)]])
	return load_theme(path)


static func _validate_style(stylebox: StyleBox, background: Color, border: Color, corner_radius: int, label: String, errors: Array[String]) -> void:
	if not stylebox is StyleBoxFlat:
		errors.append("%s must be StyleBoxFlat" % label)
		return
	var flat := stylebox as StyleBoxFlat
	_expect_color(flat.bg_color, background, "%s.bg_color" % label, errors)
	_expect_color(flat.border_color, border, "%s.border_color" % label, errors)
	_expect_int(flat.corner_radius_top_left, corner_radius, "%s.corner_radius_top_left" % label, errors)


static func _expect_color(actual: Color, expected: Color, label: String, errors: Array[String]) -> void:
	if not actual.is_equal_approx(expected):
		errors.append("%s mismatch: %s != %s" % [label, str(actual), str(expected)])


static func _expect_int(actual: int, expected: int, label: String, errors: Array[String]) -> void:
	if actual != expected:
		errors.append("%s mismatch: %s != %s" % [label, str(actual), str(expected)])


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"theme": null,
		"theme_path": "",
		"control_types": 0,
	}
