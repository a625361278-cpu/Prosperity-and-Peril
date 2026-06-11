extends RefCounted

const HeroPortraitImportManifestValidator = preload("res://scripts/data/hero_portrait_import_manifest_validator.gd")

const DEFAULT_IMPORT_MANIFEST_PATH := "res://data/content_alpha/hero_portrait_import_manifest.json"


static func load_default_manifest() -> Dictionary:
	return load_and_validate(DEFAULT_IMPORT_MANIFEST_PATH)


static func load_and_validate(path: String) -> Dictionary:
	var load_result := _load_manifest(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"manifest": {},
			"assets_by_half_body": {},
			"bindings_by_hero_id": {},
		}
	var validation: Dictionary = HeroPortraitImportManifestValidator.validate_manifest(load_result.manifest)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"manifest": load_result.manifest,
			"assets_by_half_body": {},
			"bindings_by_hero_id": {},
		}
	return {
		"ok": true,
		"errors": [],
		"manifest": load_result.manifest,
		"assets_by_half_body": _index_assets(load_result.manifest.assets),
		"bindings_by_hero_id": _index_bindings(load_result.manifest.hero_bindings),
	}


static func resolve_binding(bindings_by_hero_id: Dictionary, hero_id: int) -> Dictionary:
	var key := str(hero_id)
	if not bindings_by_hero_id.has(key):
		return {
			"ok": false,
			"errors": ["hero portrait imported binding missing hero_id %d" % hero_id],
			"binding": {},
		}
	return {
		"ok": true,
		"errors": [],
		"binding": bindings_by_hero_id[key].duplicate(true),
	}


static func _load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["hero portrait import manifest file not found: %s" % path],
			"manifest": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["hero portrait import manifest file cannot be opened: %s" % path],
			"manifest": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["hero portrait import manifest root must be a JSON object: %s" % path],
			"manifest": {},
		}
	return {
		"ok": true,
		"errors": [],
		"manifest": parsed,
	}


static func _index_assets(assets: Array) -> Dictionary:
	var indexed := {}
	for asset in assets:
		var copied: Dictionary = asset.duplicate(true)
		indexed[str(copied.half_body)] = copied
	return indexed


static func _index_bindings(bindings: Array) -> Dictionary:
	var indexed := {}
	for binding in bindings:
		var copied: Dictionary = binding.duplicate(true)
		indexed[str(int(copied.hero_id))] = copied
	return indexed
