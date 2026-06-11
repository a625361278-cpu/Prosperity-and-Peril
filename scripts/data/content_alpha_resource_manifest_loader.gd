extends RefCounted

const ContentAlphaResourceManifestValidator = preload("res://scripts/data/content_alpha_resource_manifest_validator.gd")


static func load_and_validate(path: String) -> Dictionary:
	var load_result := _load_manifest(path)
	if not load_result.ok:
		return {
			"ok": false,
			"errors": load_result.errors,
			"manifest": {},
			"packs": {},
		}

	var validation: Dictionary = ContentAlphaResourceManifestValidator.validate_manifest(load_result.manifest)
	if not validation.ok:
		return {
			"ok": false,
			"errors": validation.errors,
			"manifest": load_result.manifest,
			"packs": {},
		}

	return {
		"ok": true,
		"errors": [],
		"manifest": load_result.manifest,
		"packs": _index_packs(load_result.manifest.resource_packs),
	}


static func resolve_pack(packs: Dictionary, pack_id: String) -> Dictionary:
	if not packs.has(pack_id):
		return {
			"ok": false,
			"errors": ["content alpha resource pack missing %s" % pack_id],
			"pack": {},
		}
	return {
		"ok": true,
		"errors": [],
		"pack": packs[pack_id].duplicate(true),
	}


static func _load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"errors": ["content alpha resource manifest file not found: %s" % path],
			"manifest": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"errors": ["content alpha resource manifest file cannot be opened: %s" % path],
			"manifest": {},
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"errors": ["content alpha resource manifest root must be a JSON object: %s" % path],
			"manifest": {},
		}
	return {
		"ok": true,
		"errors": [],
		"manifest": parsed,
	}


static func _index_packs(packs: Array) -> Dictionary:
	var indexed := {}
	for pack in packs:
		var pack_copy: Dictionary = pack.duplicate(true)
		indexed[str(pack_copy.id)] = pack_copy
	return indexed
