extends RefCounted

const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")
const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")
const HeroPortraitPreviewPresenter = preload("res://scripts/ui/hero_portrait_preview_presenter.gd")
const HeroPortraitTextureLoader = preload("res://scripts/ui/hero_portrait_texture_loader.gd")

const DEFAULT_PREVIEW_LIMIT := 3


static func validate_default_content() -> Dictionary:
	return validate_hero_portrait_pack(
		HeroPortraitPackLoader.RESOURCE_MANIFEST_PATH,
		HeroPortraitPackLoader.HERO_PORTRAIT_PACK_ID,
		DEFAULT_PREVIEW_LIMIT
	)


static func validate_hero_portrait_pack(manifest_path: String, pack_id: String, preview_limit: int) -> Dictionary:
	var pack_result: Dictionary = HeroPortraitPackLoader.load_pack(manifest_path, pack_id)
	if not pack_result.ok:
		return _failure(pack_result.errors)

	var preview_result: Dictionary = HeroPortraitPreviewPresenter.build_default_preview_rows(
		pack_result.lookup,
		preview_limit
	)
	if not preview_result.ok:
		return _failure(preview_result.errors)

	var texture_result: Dictionary = HeroPortraitTextureLoader.load_texture_from_row(preview_result.rows[0])
	if not texture_result.ok:
		return _failure(texture_result.errors)

	var pool_result: Dictionary = ReusableHeroPortraitPoolLoader.load_default_pool()
	if not pool_result.ok:
		return _failure(pool_result.errors)
	var first_pool_result: Dictionary = ReusableHeroPortraitPoolLoader.resolve_portrait(
		pool_result.lookup,
		str(texture_result.half_body)
	)
	if not first_pool_result.ok:
		return _failure(first_pool_result.errors)

	return {
		"ok": true,
		"errors": [],
		"summary": {
			"pack_id": str(pack_result.pack.id),
			"pack_kind": str(pack_result.pack.kind),
			"indexed_heroes": pack_result.lookup.size(),
			"reusable_portraits": pool_result.records.size(),
			"preview_rows": preview_result.rows.size(),
			"first_hero_id": int(texture_result.hero_id),
			"first_hero_name_cn": str(texture_result.name_cn),
			"first_half_body": str(texture_result.half_body),
			"first_texture_width": int(texture_result.width),
			"first_texture_height": int(texture_result.height),
			"first_texture_source_path": str(texture_result.source_path),
			"first_texture_path_kind": str(texture_result.path_kind),
			"first_reusable_portrait_source_name_cn": str(first_pool_result.record.representative_source_name_cn),
			"portrait_pool_scope_rule": str(pool_result.source.scope_rule),
		},
	}


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"summary": {},
	}
