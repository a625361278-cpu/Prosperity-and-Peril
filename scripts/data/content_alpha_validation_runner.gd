extends RefCounted

const HeroPortraitPackLoader = preload("res://scripts/data/hero_portrait_pack_loader.gd")
const ReusableHeroPortraitPoolLoader = preload("res://scripts/data/reusable_hero_portrait_pool_loader.gd")
const CandidateOfficerRosterLoader = preload("res://scripts/data/candidate_officer_roster_loader.gd")
const UiNavigationSpecLoader = preload("res://scripts/data/ui_navigation_spec_loader.gd")
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

	var roster_result: Dictionary = CandidateOfficerRosterLoader.load_default_roster()
	if not roster_result.ok:
		return _failure(roster_result.errors)
	var first_candidate_id := "CANDIDATE_%s" % str(texture_result.half_body).to_upper()
	var first_candidate_result: Dictionary = CandidateOfficerRosterLoader.resolve_candidate(
		roster_result.lookup,
		first_candidate_id
	)
	if not first_candidate_result.ok:
		return _failure(first_candidate_result.errors)

	var ui_spec_result: Dictionary = UiNavigationSpecLoader.load_default_spec()
	if not ui_spec_result.ok:
		return _failure(ui_spec_result.errors)
	var candidate_workbench_result: Dictionary = UiNavigationSpecLoader.resolve_screen(
		ui_spec_result.lookup,
		"candidate_officer_workbench"
	)
	if not candidate_workbench_result.ok:
		return _failure(candidate_workbench_result.errors)
	var ui_status_counts: Dictionary = _count_ui_statuses(ui_spec_result.screens)

	return {
		"ok": true,
		"errors": [],
		"summary": {
			"pack_id": str(pack_result.pack.id),
			"pack_kind": str(pack_result.pack.kind),
			"indexed_heroes": pack_result.lookup.size(),
			"reusable_portraits": pool_result.records.size(),
			"candidate_officers": roster_result.records.size(),
			"preview_rows": preview_result.rows.size(),
			"first_hero_id": int(texture_result.hero_id),
			"first_hero_name_cn": str(texture_result.name_cn),
			"first_half_body": str(texture_result.half_body),
			"first_texture_width": int(texture_result.width),
			"first_texture_height": int(texture_result.height),
			"first_texture_source_path": str(texture_result.source_path),
			"first_texture_path_kind": str(texture_result.path_kind),
			"first_reusable_portrait_source_name_cn": str(first_pool_result.record.representative_source_name_cn),
			"first_candidate_officer_id": str(first_candidate_result.record.candidate_officer_id),
			"first_candidate_display_name_cn": str(first_candidate_result.record.display_name_cn),
			"portrait_pool_scope_rule": str(pool_result.source.scope_rule),
			"candidate_roster_rule": str(roster_result.source.roster_rule),
			"ui_navigation_screens": ui_spec_result.screens.size(),
			"ui_navigation_available_screens": int(ui_status_counts.debug_available) + int(ui_status_counts.content_alpha_available),
			"ui_navigation_planned_screens": int(ui_status_counts.planned),
			"ui_navigation_boundary_rule": str(ui_spec_result.source.boundary_rule),
			"ui_navigation_candidate_workbench_status": str(candidate_workbench_result.screen.implementation_status),
		},
	}


static func _count_ui_statuses(screens: Array) -> Dictionary:
	var counts := {
		"debug_available": 0,
		"content_alpha_available": 0,
		"planned": 0,
	}
	for screen in screens:
		var status := str(screen.implementation_status)
		if not counts.has(status):
			continue
		counts[status] = int(counts[status]) + 1
	return counts


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"summary": {},
	}
