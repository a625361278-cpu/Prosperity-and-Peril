extends SceneTree

const UiThemeTokenLoader = preload("res://scripts/data/ui_theme_token_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("formal ui component factory loads tokens", _test_factory_loads_tokens)
	_run("formal ui component factory creates command button with blocker", _test_command_button)
	_run("formal ui component factory creates semantic text controls", _test_semantic_text_controls)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_factory_loads_tokens() -> Dictionary:
	var factory_script := load("res://scripts/ui/formal_ui_component_factory.gd")
	if factory_script == null:
		return {"ok": false, "message": "formal ui component factory script missing"}
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return {"ok": false, "message": "theme token load failed %s" % [token_result.errors]}
	var factory = factory_script.new(token_result.tokens)
	if int(factory.get_panel_padding()) != int(token_result.tokens.spacing.panel_padding):
		return {"ok": false, "message": "factory did not expose token panel padding"}
	return {"ok": true}


func _test_command_button() -> Dictionary:
	var factory_result := _build_factory()
	if not factory_result.ok:
		return factory_result
	var button: Button = factory_result.factory.create_command_button({
		"id": "reserved_roster",
		"label": "武将",
		"enabled": false,
		"blocked_reason": "正式武将名册留作后续版本",
	})
	if button.text != "武将":
		button.free()
		return {"ok": false, "message": "command button label mismatch"}
	if not button.disabled:
		button.free()
		return {"ok": false, "message": "blocked command button must be disabled"}
	if button.tooltip_text != "正式武将名册留作后续版本":
		button.free()
		return {"ok": false, "message": "blocked command tooltip must preserve real reason"}
	if str(button.get_meta("command_id", "")) != "reserved_roster":
		button.free()
		return {"ok": false, "message": "command button missing command id meta"}
	if str(button.get_meta("blocked_reason", "")) != "正式武将名册留作后续版本":
		button.free()
		return {"ok": false, "message": "command button missing blocked reason meta"}
	if button.custom_minimum_size.x < 112 or button.custom_minimum_size.y < 56:
		button.free()
		return {"ok": false, "message": "command button lost stable minimum size"}
	button.free()
	return {"ok": true}


func _test_semantic_text_controls() -> Dictionary:
	var factory_result := _build_factory()
	if not factory_result.ok:
		return factory_result
	var title: Label = factory_result.factory.create_section_title("军务")
	if title.text != "军务":
		title.free()
		return {"ok": false, "message": "section title text mismatch"}
	if str(title.get_meta("formal_component", "")) != "section_title":
		title.free()
		return {"ok": false, "message": "section title missing component meta"}
	var row: Label = factory_result.factory.create_info_row("兵力", "8000")
	if row.text != "兵力  8000":
		title.free()
		row.free()
		return {"ok": false, "message": "info row text mismatch"}
	if str(row.get_meta("formal_component", "")) != "info_row":
		title.free()
		row.free()
		return {"ok": false, "message": "info row missing component meta"}
	var badge: Label = factory_result.factory.create_status_badge("阻断", "warning")
	if badge.text != "阻断":
		title.free()
		row.free()
		badge.free()
		return {"ok": false, "message": "status badge text mismatch"}
	if str(badge.get_meta("status_kind", "")) != "warning":
		title.free()
		row.free()
		badge.free()
		return {"ok": false, "message": "status badge missing kind meta"}
	title.free()
	row.free()
	badge.free()
	return {"ok": true}


func _build_factory() -> Dictionary:
	var factory_script := load("res://scripts/ui/formal_ui_component_factory.gd")
	if factory_script == null:
		return {"ok": false, "message": "formal ui component factory script missing"}
	var token_result: Dictionary = UiThemeTokenLoader.load_default_tokens()
	if not token_result.ok:
		return {"ok": false, "message": "theme token load failed %s" % [token_result.errors]}
	return {
		"ok": true,
		"factory": factory_script.new(token_result.tokens),
	}
