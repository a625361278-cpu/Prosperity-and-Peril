extends SceneTree

const ContentAlphaThemeLoader = preload("res://scripts/ui/content_alpha_theme_loader.gd")


func _initialize() -> void:
	var result: Dictionary = ContentAlphaThemeLoader.save_theme_from_default_tokens()
	if not result.ok:
		for error in result.errors:
			push_error(str(error))
		quit(1)
		return
	print("saved_content_alpha_theme: %s" % str(result.theme_path))
	print("theme_control_types: %s" % str(result.control_types))
	quit(0)
