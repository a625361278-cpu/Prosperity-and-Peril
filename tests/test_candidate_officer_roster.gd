extends SceneTree

const CandidateOfficerRosterValidator = preload("res://scripts/data/candidate_officer_roster_validator.gd")
const CandidateOfficerRosterLoader = preload("res://scripts/data/candidate_officer_roster_loader.gd")

const ROSTER_PATH := "res://data/content_alpha/candidate_officer_roster.json"


var _failed := 0


func _initialize() -> void:
	_run("candidate officer roster is valid", _test_roster_is_valid)
	_run("candidate officer roster loader resolves portrait-backed candidates", _test_loader_resolves_candidates)
	_run("candidate officer roster rejects gameplay fields", _test_rejects_gameplay_fields)
	_run("candidate officer roster rejects missing portrait resource", _test_rejects_missing_portrait_resource)
	_run("candidate officer roster rejects invalid selection status", _test_rejects_invalid_selection_status)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_roster_is_valid() -> Dictionary:
	var roster_result := _load_roster()
	if not roster_result.ok:
		return roster_result
	var validation: Dictionary = CandidateOfficerRosterValidator.validate_roster(roster_result.data)
	if not validation.ok:
		return {"ok": false, "message": "expected valid candidate officer roster, got %s" % [validation.errors]}
	if int(roster_result.data.candidate_count) != 212:
		return {"ok": false, "message": "expected 212 candidate officers"}
	return {"ok": true}


func _test_loader_resolves_candidates() -> Dictionary:
	var load_result: Dictionary = CandidateOfficerRosterLoader.load_default_roster()
	if not load_result.ok:
		return {"ok": false, "message": "expected candidate roster load success, got %s" % [load_result.errors]}
	var candidate_id := "CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1004"
	var result: Dictionary = CandidateOfficerRosterLoader.resolve_candidate(load_result.lookup, candidate_id)
	if not result.ok:
		return {"ok": false, "message": "expected candidate %s" % candidate_id}
	var record: Dictionary = result.record
	if str(record.display_name_cn) != "赵云":
		return {"ok": false, "message": "expected Zhao Yun display name"}
	if str(record.selection_status) != "candidate":
		return {"ok": false, "message": "expected candidate selection status"}
	if record.has("skill_ids") or record.has("biography_cn"):
		return {"ok": false, "message": "candidate roster must not contain source gameplay fields"}
	if int(record.source_reference.source_hero_bindings.size()) != 2:
		return {"ok": false, "message": "expected two source bindings for Zhao Yun portrait"}
	return {"ok": true}


func _test_rejects_gameplay_fields() -> Dictionary:
	var roster_result := _load_roster()
	if not roster_result.ok:
		return roster_result
	var copied: Dictionary = roster_result.data.duplicate(true)
	copied.records[0].force_id = "FORCE_SHU"
	var validation: Dictionary = CandidateOfficerRosterValidator.validate_roster(copied)
	return _expect_error_contains(validation, "leaked gameplay field")


func _test_rejects_missing_portrait_resource() -> Dictionary:
	var roster_result := _load_roster()
	if not roster_result.ok:
		return roster_result
	var copied: Dictionary = roster_result.data.duplicate(true)
	copied.records[0].portrait_res_path = "res://assets/content_alpha/hero_portraits/missing_hero.png"
	var validation: Dictionary = CandidateOfficerRosterValidator.validate_roster(copied)
	return _expect_error_contains(validation, "portrait_res_path missing file")


func _test_rejects_invalid_selection_status() -> Dictionary:
	var roster_result := _load_roster()
	if not roster_result.ok:
		return roster_result
	var copied: Dictionary = roster_result.data.duplicate(true)
	copied.records[0].selection_status = "auto_selected"
	var validation: Dictionary = CandidateOfficerRosterValidator.validate_roster(copied)
	return _expect_error_contains(validation, "selection_status invalid")


func _load_roster() -> Dictionary:
	if not FileAccess.file_exists(ROSTER_PATH):
		return {"ok": false, "message": "candidate officer roster missing: %s" % ROSTER_PATH}
	var file := FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "candidate officer roster cannot be opened: %s" % ROSTER_PATH}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "candidate officer roster root must be a JSON object"}
	return {"ok": true, "data": parsed}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}
