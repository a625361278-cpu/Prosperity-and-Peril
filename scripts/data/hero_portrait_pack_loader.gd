extends RefCounted

const ContentAlphaResourceManifestLoader = preload("res://scripts/data/content_alpha_resource_manifest_loader.gd")
const HeroPortraitIndexLoader = preload("res://scripts/data/hero_portrait_index_loader.gd")

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
		}
	var pack_result: Dictionary = ContentAlphaResourceManifestLoader.resolve_pack(manifest_result.packs, pack_id)
	if not pack_result.ok:
		return {
			"ok": false,
			"errors": pack_result.errors,
			"lookup": {},
			"pack": {},
			"source": {},
		}
	if str(pack_result.pack.kind) != "hero_portrait":
		return {
			"ok": false,
			"errors": ["hero portrait pack kind invalid %s" % str(pack_result.pack.kind)],
			"lookup": {},
			"pack": pack_result.pack,
			"source": {},
		}

	var index_result: Dictionary = HeroPortraitIndexLoader.load_and_build_lookup(str(pack_result.pack.index_path))
	if not index_result.ok:
		return {
			"ok": false,
			"errors": index_result.errors,
			"lookup": {},
			"pack": pack_result.pack,
			"source": index_result.source,
		}
	return {
		"ok": true,
		"errors": [],
		"lookup": index_result.lookup,
		"pack": pack_result.pack,
		"source": index_result.source,
	}
