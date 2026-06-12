extends RefCounted


static func build_theme(tokens: Dictionary) -> Theme:
	var theme := Theme.new()
	theme.resource_name = "ContentAlphaFormalTheme"
	var palette: Dictionary = tokens.palette
	var sizes: Dictionary = tokens.typography.sizes
	var shape: Dictionary = tokens.shape
	var spacing: Dictionary = tokens.spacing

	theme.set_color("font_color", "Label", _color(palette.ink_text))
	theme.set_color("font_shadow_color", "Label", _color(palette.lacquer_dark))
	theme.set_font_size("font_size", "Label", int(sizes.body))
	theme.set_font_size("font_size", "Button", int(sizes.body))
	theme.set_font_size("font_size", "TabContainer", int(sizes.body))
	theme.set_font_size("font_size", "ItemList", int(sizes.body))

	theme.set_color("font_color", "Button", _color(palette.ink_text))
	theme.set_color("font_hover_color", "Button", _color(palette.lacquer_dark))
	theme.set_color("font_pressed_color", "Button", _color(palette.ink_text))
	theme.set_color("font_disabled_color", "Button", _color(palette.muted_text))
	theme.set_stylebox("normal", "Button", _button_style(tokens, "normal"))
	theme.set_stylebox("hover", "Button", _button_style(tokens, "hover"))
	theme.set_stylebox("pressed", "Button", _button_style(tokens, "pressed"))
	theme.set_stylebox("disabled", "Button", _button_style(tokens, "disabled"))

	theme.set_stylebox("panel", "PanelContainer", _panel_style(tokens))
	theme.set_constant("separation", "VBoxContainer", int(spacing.row_gap))
	theme.set_constant("separation", "HBoxContainer", int(spacing.control_gap))
	theme.set_constant("margin_left", "MarginContainer", int(spacing.panel_padding))
	theme.set_constant("margin_top", "MarginContainer", int(spacing.panel_padding))
	theme.set_constant("margin_right", "MarginContainer", int(spacing.panel_padding))
	theme.set_constant("margin_bottom", "MarginContainer", int(spacing.panel_padding))

	var focus_style := _outline_style(_color(palette.accent_gold), int(shape.focus_border_width), int(shape.corner_radius))
	theme.set_stylebox("focus", "Button", focus_style)
	return theme


static func _button_style(tokens: Dictionary, state: String) -> StyleBoxFlat:
	var palette: Dictionary = tokens.palette
	var controls: Dictionary = tokens.controls
	var shape: Dictionary = tokens.shape
	var background_key := str(controls.button[state])
	var border_key := "accent_gold"
	if state == "pressed":
		border_key = "aged_paper"
	if state == "disabled":
		border_key = "neutral_force"
	return _filled_style(
		_color(palette[background_key]),
		_color(palette[border_key]),
		int(shape.panel_border_width),
		int(shape.corner_radius)
	)


static func _panel_style(tokens: Dictionary) -> StyleBoxFlat:
	var palette: Dictionary = tokens.palette
	var controls: Dictionary = tokens.controls
	var shape: Dictionary = tokens.shape
	return _filled_style(
		_color(palette[str(controls.panel.background)]),
		_color(palette[str(controls.panel.border)]),
		int(shape.panel_border_width),
		int(shape.corner_radius)
	)


static func _filled_style(background: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


static func _outline_style(border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


static func _color(value: String) -> Color:
	return Color.html(value)
