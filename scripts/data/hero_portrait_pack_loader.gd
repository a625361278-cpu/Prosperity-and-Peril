extends RefCounted

const ContentAlphaResourceManifestLoader = preload("res://scripts/data/content_alpha_resource_manifest_loader.gd")
const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")
const HeroPortraitImportManifestLoader = preload("res://scripts/data/hero_portrait_import_manifest_loader.gd")

const RESOURCE_MANIFEST_PATH := "res://data/content_alpha/resource_manifest.json"
const HERO_PORTRAIT_PACK_ID := "candidate_hero_portraits"


static func load_default_pack() -> Dictionary:
	return load_pack(RESOURCE_MANIFEST_PATH, HERO_PORTRAIT_PACK_ID)


static func load_pack(manifest_path: String, pack_id: String) -> Dictionary:
	var manifest_result: Dictionary = ContentAlphaResourceManifestLoader.load_and_validate(manifest_path)
	if not manifest_result.ok:
		return {
			"ok": false,
			"errors": manifest_result.errors,
			"lookup": {},
			"pack": {},
			"source": {},
			"import_manifest": {},
		}
	var pack_result: Dictionary = ContentAlphaResourceManifestLoader.resolve_pack(manifest_result.packs, pack_id)
	if not pack_result.ok:
		return {
			"ok": false,
			"errors": pack_result.errors,
			"lookup": {},
			"pack": {},
			"source": {},
			"import_manifest": {},
		}
	if str(pack_result.pack.kind) != "hero_portrait":
		return {
			"ok": false,
			"errors": ["hero portrait pack kind invalid %s" % str(pack_result.pack.kind)],
			"lookup": {},
			"pack": pack_result.pack,
			"source": {},
			"import_manifest": {},
		}

	var index_result: Dictionary = HeroPortraitIndexLoader.load_and_build_lookup(str(pack_result.pack.index_path))
	if not index_result.ok:
		return {
			"ok": false,
			"errors": index_result.errors,
			"lookup": {},
			"pack": pack_result.pack,
			"source": index_result.source,
			"import_manifest": {},
		}
	var import_result: Dictionary = HeroPortraitImportManifestLoader.load_and_validate(str(pack_result.pack.import_manifest_path))
	if not import_result.ok:
		return {
			"ok": false,
			"errors": import_result.errors,
			"lookup": {},
			"pack": pack_result.pack,
			"source": index_result.source,
			"import_manifest": import_result.manifest,
		}
	var merged_lookup_result := _attach_imported_paths(index_result.lookup, import_result.bindings_by_hero_id)
	if not merged_lookup_result.ok:
		return {
			"ok": false,
			"errors": merged_lookup_result.errors,
			"lookup": {},
			"pack": pack_result.pack,
			"source": index_result.source,
			"import_manifest": import_result.manifest,
		}
	return {
		"ok": true,
		"errors": [],
		"lookup": merged_lookup_result.lookup,
		"pack": pack_result.pack,
		"source": index_result.source,
		"import_manifest": import_result.manifest,
	}


static func _attach_imported_paths(index_lookup: Dictionary, bindings_by_hero_id: Dictionary) -> Dictionary:
	var merged := {}
	for key in index_lookup.keys():
		var record: Dictionary = index_lookup[key].duplicate(true)
		if not bindings_by_hero_id.has(str(key)):
			return {
				"ok": false,
				"errors": ["hero portrait imported binding missing hero_id %s" % str(key)],
				"lookup": {},
			}
		var binding: Dictionary = bindings_by_hero_id[str(key)]
		if str(binding.half_body) != str(record.half_body):
			return {
				"ok": false,
				"errors": ["hero portrait imported binding half_body mismatch hero_id %s" % str(key)],
				"lookup": {},
			}
		record.portrait_res_path = str(binding.target_res_path)
		merged[key] = record
	return {
		"ok": true,
		"errors": [],
		"lookup": merged,
	}
