extends VBoxContainer

const ContentAlphaValidationRunner = preload("res://scripts/data/content_alpha_validation_runner.gd")
const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")
const HeroPortraitPreviewPresenter = preload("res://scripts/ui/hero_portrait_preview_presenter.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

const HERO_PORTRAIT_PREVIEW_LIMIT := 3

@onready var _preview_label: Label = $PortraitPreviewText
@onready var _validation_label: Label = $ContentAlphaValidationText
@onready var _preview_image: TextureRect = $PortraitPreviewImage


func load_default_preview() -> Dictionary:
	var load_result: Dictionary = HeroPortraitPackLoader.load_default_pack()
	if not load_result.ok:
		_show_error(load_result.errors)
		return {
			"ok": false,
			"errors": load_result.errors,
		}
	var preview_result: Dictionary = HeroPortraitPreviewPresenter.build_default_preview_rows(
		load_result.lookup,
		HERO_PORTRAIT_PREVIEW_LIMIT
	)
	if not preview_result.ok:
		_show_error(preview_result.errors)
		return {
			"ok": false,
			"errors": preview_result.errors,
		}
	set_preview_rows(preview_result.rows)
	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(preview_result.rows[0])
	if not texture_result.ok:
		_show_error(texture_result.errors)
		return {
			"ok": false,
			"errors": texture_result.errors,
		}
	set_preview_texture(texture_result.texture)
	var validation_result: Dictionary = ContentAlphaValidationRunner.validate_default_content()
	if not validation_result.ok:
		_show_error(validation_result.errors)
		return {
			"ok": false,
			"errors": validation_result.errors,
		}
	set_validation_summary(validation_result.summary)
	return {
		"ok": true,
		"errors": [],
	}


func set_preview_rows(rows: Array) -> void:
	_preview_text().text = _format_preview(rows)


func set_preview_texture(texture: Texture2D) -> void:
	_preview_texture_rect().texture = texture


func set_validation_summary(summary: Dictionary) -> void:
	_validation_text().text = _format_validation_summary(summary)


func clear_preview_texture() -> void:
	_preview_texture_rect().texture = null


func _show_error(errors: Array) -> void:
	clear_preview_texture()
	_preview_text().text = "半身像候选预览异常:\n%s" % "\n".join(errors)
	_validation_text().text = "Content Alpha 校验异常:\n%s" % "\n".join(errors)


func _format_preview(rows: Array) -> String:
	var lines: Array[String] = ["半身像候选预览:"]
	for row in rows:
		lines.append("- %s %s halfBody=%s" % [
			row.hero_id,
			row.name_cn,
			row.half_body,
		])
	return "\n".join(lines)


func _format_validation_summary(summary: Dictionary) -> String:
	return "Content Alpha 校验: 资源包=%s 英雄=%s 预览=%s 首图=%s %s %sx%s" % [
		str(summary.pack_id),
		str(summary.indexed_heroes),
		str(summary.preview_rows),
		str(summary.first_hero_id),
		str(summary.first_hero_name_cn),
		str(summary.first_texture_width),
		str(summary.first_texture_height),
	]


func _preview_text() -> Label:
	if _preview_label != null:
		return _preview_label
	return get_node("PortraitPreviewText") as Label


func _validation_text() -> Label:
	if _validation_label != null:
		return _validation_label
	return get_node("ContentAlphaValidationText") as Label


func _preview_texture_rect() -> TextureRect:
	if _preview_image != null:
		return _preview_image
	return get_node("PortraitPreviewImage") as TextureRect
