extends RefCounted


var _tokens: Dictionary = {}


func _init(tokens: Dictionary) -> void:
	_validate_tokens(tokens)
	_tokens = tokens


func get_panel_padding() -> int:
	return int(_tokens.spacing.panel_padding)


func create_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 30)
	label.set_meta("formal_component", "section_title")
	label.add_theme_font_size_override("font_size", int(_tokens.typography.sizes.section))
	return label


func create_info_row(label_text: String, value_text: String) -> Label:
	var label := Label.new()
	label.text = "%s  %s" % [label_text, value_text]
	label.custom_minimum_size = Vector2(0, 26)
	label.set_meta("formal_component", "info_row")
	label.add_theme_font_size_override("font_size", int(_tokens.typography.sizes.body))
	return label


func create_status_badge(text: String, status_kind: String) -> Label:
	if not ["warning", "danger", "success"].has(status_kind):
		push_error("formal ui unsupported status badge kind %s" % status_kind)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(72, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_meta("formal_component", "status_badge")
	label.set_meta("status_kind", status_kind)
	label.add_theme_font_size_override("font_size", int(_tokens.typography.sizes.caption))
	return label


func create_command_button(command: Dictionary) -> Button:
	_require_fields(command, "formal command", ["id", "label", "enabled", "blocked_reason"])
	var button := Button.new()
	button.text = str(command.label)
	button.disabled = not bool(command.enabled)
	button.tooltip_text = str(command.blocked_reason)
	button.custom_minimum_size = Vector2(112, 56)
	button.set_meta("formal_component", "command_button")
	button.set_meta("command_id", str(command.id))
	button.set_meta("blocked_reason", str(command.blocked_reason))
	return button


func create_action_button(action: Dictionary, action_id_meta := "action_id", minimum_size := Vector2(132, 44)) -> Button:
	_require_fields(action, "formal action", ["id", "label", "enabled", "blocked_reason"])
	var button := Button.new()
	button.text = str(action.label)
	button.disabled = not bool(action.enabled)
	button.tooltip_text = str(action.blocked_reason)
	button.custom_minimum_size = minimum_size
	button.set_meta("formal_component", "action_button")
	button.set_meta(action_id_meta, str(action.id))
	button.set_meta("blocked_reason", str(action.blocked_reason))
	return button


func _validate_tokens(tokens: Dictionary) -> void:
	for key in ["typography", "spacing"]:
		if not tokens.has(key):
			push_error("formal ui component factory missing token group %s" % key)
			return
	if not tokens.typography.has("sizes"):
		push_error("formal ui component factory missing typography sizes")
	if not tokens.spacing.has("panel_padding"):
		push_error("formal ui component factory missing panel padding")


func _require_fields(values: Dictionary, context: String, fields: Array) -> void:
	for field in fields:
		if not values.has(field):
			push_error("%s missing %s" % [context, str(field)])
