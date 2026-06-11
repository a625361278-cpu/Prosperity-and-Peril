extends RefCounted


static func build_default_preview_rows(records: Array, limit: int) -> Dictionary:
	if limit <= 0:
		return {
			"ok": false,
			"errors": ["reusable hero portrait preview limit must be positive"],
			"rows": [],
		}
	if records.is_empty():
		return {
			"ok": false,
			"errors": ["reusable hero portrait preview requires at least one portrait"],
			"rows": [],
		}
	var rows: Array[Dictionary] = []
	for index in min(limit, records.size()):
		var record: Dictionary = records[index]
		var row_result := _build_row(record)
		if not row_result.ok:
			return {
				"ok": false,
				"errors": row_result.errors,
				"rows": [],
			}
		rows.append(row_result.row)
	return {
		"ok": true,
		"errors": [],
		"rows": rows,
	}


static func _build_row(record: Dictionary) -> Dictionary:
	var required := ["representative_source_hero_id", "representative_source_name_cn", "half_body", "portrait_res_path"]
	var errors: Array[String] = []
	for field in required:
		if not record.has(field):
			errors.append("reusable hero portrait preview record missing %s" % field)
		elif str(record[field]).is_empty():
			errors.append("reusable hero portrait preview record empty %s" % field)
	if errors.is_empty() and not FileAccess.file_exists(str(record.portrait_res_path)):
		errors.append("reusable hero portrait preview imported file missing: %s" % str(record.portrait_res_path))
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"row": {},
		}
	return {
		"ok": true,
		"errors": [],
		"row": {
			"hero_id": int(record.representative_source_hero_id),
			"name_cn": str(record.representative_source_name_cn),
			"half_body": str(record.half_body),
			"portrait_res_path": str(record.portrait_res_path),
			"source_binding_count": record.source_hero_bindings.size() if record.has("source_hero_bindings") and record.source_hero_bindings is Array else 0,
		},
	}
