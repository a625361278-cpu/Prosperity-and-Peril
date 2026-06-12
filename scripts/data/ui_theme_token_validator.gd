extends RefCounted

const REQUIRED_ROOT_FIELDS := [
	"schema_version",
	"source",
	"palette",
	"typography",
	"spacing",
	"shape",
	"controls",
	"responsive_rules",
	"blocked_until",
]
const REQUIRED_SOURCE_FIELDS := ["stage", "boundary_rule", "style_reference", "requirements_source"]
const REQUIRED_PALETTE_KEYS := [
	"lacquer_dark",
	"lacquer_panel",
	"aged_paper",
	"paper_muted",
	"ink_text",
	"muted_text",
	"accent_gold",
	"accent_red",
	"warning",
	"danger",
	"success",
	"route_line",
	"player_force",
	"enemy_force",
	"neutral_force",
]
const REQUIRED_CONTROL_KEYS := ["panel", "button", "warning_badge", "danger_badge", "success_badge"]


static func validate_tokens(tokens: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_ROOT_FIELDS:
		if not tokens.has(field):
			errors.append("ui theme tokens missing %s" % field)
	if not errors.is_empty():
		return _result(errors)

	if not _is_integer_number(tokens.schema_version) or int(tokens.schema_version) < 1:
		errors.append("ui theme tokens schema_version must be a positive integer")
	if not tokens.source is Dictionary:
		errors.append("ui theme tokens source must be a dictionary")
	else:
		_validate_source(tokens.source, errors)
	if not tokens.palette is Dictionary:
		errors.append("ui theme tokens palette must be a dictionary")
	else:
		_validate_palette(tokens.palette, errors)
	_validate_typography(tokens.typography, errors)
	_validate_positive_number_map("spacing", tokens.spacing, errors)
	_validate_positive_number_map("shape", tokens.shape, errors)
	_validate_controls(tokens.controls, tokens.palette if tokens.palette is Dictionary else {}, errors)
	if not tokens.responsive_rules is Array or tokens.responsive_rules.size() < 3:
		errors.append("ui theme tokens responsive_rules must contain at least three rules")
	if not tokens.blocked_until is Array or tokens.blocked_until.is_empty():
		errors.append("ui theme tokens blocked_until must be a non-empty array")
	return _result(errors)


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	for field in REQUIRED_SOURCE_FIELDS:
		if not source.has(field):
			errors.append("ui theme tokens source.%s missing required field" % field)
		elif str(source[field]).is_empty():
			errors.append("ui theme tokens source.%s empty required field" % field)
	if source.has("boundary_rule") and not str(source.boundary_rule).contains("not a finished Beta UI"):
		errors.append("ui theme tokens source.boundary_rule must state it is not a finished Beta UI")
	if source.has("style_reference"):
		_validate_res_path("source.style_reference", str(source.style_reference), errors)


static func _validate_palette(palette: Dictionary, errors: Array[String]) -> void:
	for key in REQUIRED_PALETTE_KEYS:
		if not palette.has(key):
			errors.append("ui theme tokens palette.%s missing required color" % key)
		elif not _is_hex_color(str(palette[key])):
			errors.append("ui theme tokens palette.%s must be #RRGGBB" % key)


static func _validate_typography(typography, errors: Array[String]) -> void:
	if not typography is Dictionary:
		errors.append("ui theme tokens typography must be a dictionary")
		return
	if not typography.has("font_policy") or str(typography.font_policy).is_empty():
		errors.append("ui theme tokens typography.font_policy missing required field")
	if not typography.has("sizes") or not typography.sizes is Dictionary:
		errors.append("ui theme tokens typography.sizes must be a dictionary")
	else:
		for key in ["title", "section", "body", "caption", "number"]:
			if not typography.sizes.has(key) or not _is_positive_number(typography.sizes[key]):
				errors.append("ui theme tokens typography.sizes.%s must be positive" % key)
	if not typography.has("rules") or not typography.rules is Array or typography.rules.size() < 3:
		errors.append("ui theme tokens typography.rules must contain at least three rules")


static func _validate_positive_number_map(label: String, value, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("ui theme tokens %s must be a dictionary" % label)
		return
	for key in value.keys():
		if not _is_positive_number(value[key]):
			errors.append("ui theme tokens %s.%s must be positive" % [label, str(key)])


static func _validate_controls(controls, palette: Dictionary, errors: Array[String]) -> void:
	if not controls is Dictionary:
		errors.append("ui theme tokens controls must be a dictionary")
		return
	for key in REQUIRED_CONTROL_KEYS:
		if not controls.has(key) or not controls[key] is Dictionary:
			errors.append("ui theme tokens controls.%s missing required control" % key)
			continue
		for color_key in controls[key].values():
			if not palette.has(str(color_key)):
				errors.append("ui theme tokens controls.%s references missing palette color %s" % [key, str(color_key)])


static func _validate_res_path(label: String, res_path: String, errors: Array[String]) -> void:
	if not res_path.begins_with("res://"):
		errors.append("ui theme tokens %s must use res:// path: %s" % [label, res_path])
	elif not FileAccess.file_exists(res_path):
		errors.append("ui theme tokens %s missing file %s" % [label, res_path])


static func _is_hex_color(value: String) -> bool:
	if value.length() != 7 or not value.begins_with("#"):
		return false
	for index in range(1, value.length()):
		if not "0123456789ABCDEFabcdef".contains(value[index]):
			return false
	return true


static func _is_positive_number(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) > 0.0


static func _is_integer_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), float(int(value)))
	return false


static func _result(errors: Array[String]) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}
