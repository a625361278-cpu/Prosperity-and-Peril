extends Control

const ContentAlphaValidationRunner = preload("res://scripts/data/content_alpha_validation_runner.gd")

@onready var _summary: Label = $Root/ValidationSummary
@onready var _tabs: TabContainer = $Root/WorkbenchTabs
@onready var _candidate_browser = $Root/WorkbenchTabs/CandidateRoster/CandidateOfficerRosterBrowserPanel
@onready var _portrait_browser = $Root/WorkbenchTabs/PortraitPool/ReusableHeroPortraitBrowserPanel
@onready var _ui_navigation_panel = $Root/WorkbenchTabs/UiNavigation/UiNavigationSpecPanel
@onready var _ui_wireframe_panel = $Root/WorkbenchTabs/UiWireframes/UiWireframeSpecPanel
@onready var _ui_theme_token_panel = $Root/WorkbenchTabs/UiThemeTokens/UiThemeTokenPanel


func _ready() -> void:
	load_default_workbench()


func load_default_workbench() -> Dictionary:
	var errors: Array = []
	var validation_result: Dictionary = ContentAlphaValidationRunner.validate_default_content()
	if not validation_result.ok:
		errors.append_array(validation_result.errors)
	else:
		set_validation_summary(validation_result.summary)

	var candidate_result: Dictionary = _candidate_roster_browser().load_default_roster()
	if not candidate_result.ok:
		errors.append_array(candidate_result.errors)

	var portrait_result: Dictionary = _portrait_pool_browser().load_default_pool()
	if not portrait_result.ok:
		errors.append_array(portrait_result.errors)

	var ui_navigation_result: Dictionary = _ui_navigation_spec_panel().load_default_spec()
	if not ui_navigation_result.ok:
		errors.append_array(ui_navigation_result.errors)

	var ui_wireframe_result: Dictionary = _ui_wireframe_spec_panel().load_default_spec()
	if not ui_wireframe_result.ok:
		errors.append_array(ui_wireframe_result.errors)

	var ui_theme_token_result: Dictionary = _ui_theme_token_panel_node().load_default_tokens()
	if not ui_theme_token_result.ok:
		errors.append_array(ui_theme_token_result.errors)

	if not errors.is_empty():
		_show_error(errors)
		return {
			"ok": false,
			"errors": errors,
		}
	return {
		"ok": true,
		"errors": [],
	}


func set_validation_summary(summary: Dictionary) -> void:
	_summary_label().text = "Content Alpha 工作台: 图池=%s 候选=%s 源绑定=%s UI规格=%s 规划=%s 线框=%s 主题色=%s 首图=%s %s" % [
		str(summary.reusable_portraits),
		str(summary.candidate_officers),
		str(summary.indexed_heroes),
		str(summary.ui_navigation_screens),
		str(summary.ui_navigation_planned_screens),
		str(summary.ui_wireframes),
		str(summary.ui_theme_palette_colors),
		str(summary.first_candidate_officer_id),
		str(summary.first_candidate_display_name_cn),
	]


func get_validation_summary_text() -> String:
	return _summary_label().text


func get_tab_count() -> int:
	return _tab_container().get_tab_count()


func get_candidate_item_count() -> int:
	return _candidate_roster_browser().get_item_count()


func get_portrait_item_count() -> int:
	return _portrait_pool_browser().get_item_count()


func get_ui_navigation_item_count() -> int:
	return _ui_navigation_spec_panel().get_item_count()


func get_ui_wireframe_item_count() -> int:
	return _ui_wireframe_spec_panel().get_item_count()


func get_ui_theme_token_item_count() -> int:
	return _ui_theme_token_panel_node().get_item_count()


func _show_error(errors: Array) -> void:
	_summary_label().text = "Content Alpha 工作台异常:\n%s" % "\n".join(errors)


func _summary_label() -> Label:
	if _summary != null:
		return _summary
	return get_node("Root/ValidationSummary") as Label


func _tab_container() -> TabContainer:
	if _tabs != null:
		return _tabs
	return get_node("Root/WorkbenchTabs") as TabContainer


func _candidate_roster_browser():
	if _candidate_browser != null:
		return _candidate_browser
	return get_node("Root/WorkbenchTabs/CandidateRoster/CandidateOfficerRosterBrowserPanel")


func _portrait_pool_browser():
	if _portrait_browser != null:
		return _portrait_browser
	return get_node("Root/WorkbenchTabs/PortraitPool/ReusableHeroPortraitBrowserPanel")


func _ui_navigation_spec_panel():
	if _ui_navigation_panel != null:
		return _ui_navigation_panel
	return get_node("Root/WorkbenchTabs/UiNavigation/UiNavigationSpecPanel")


func _ui_wireframe_spec_panel():
	if _ui_wireframe_panel != null:
		return _ui_wireframe_panel
	return get_node("Root/WorkbenchTabs/UiWireframes/UiWireframeSpecPanel")


func _ui_theme_token_panel_node():
	if _ui_theme_token_panel != null:
		return _ui_theme_token_panel
	return get_node("Root/WorkbenchTabs/UiThemeTokens/UiThemeTokenPanel")
