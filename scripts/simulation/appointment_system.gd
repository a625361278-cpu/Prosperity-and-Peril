extends RefCounted


static func appoint_governor(state: Dictionary, city_id: String, officer_id: String) -> Dictionary:
	var errors := _validate_governor_appointment(state, city_id, officer_id)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
		}

	var city: Dictionary = state.cities[city_id]
	var officer: Dictionary = state.officers[officer_id]
	city.governor_officer_id = officer_id
	officer.assignment_type = "governor"
	officer.assignment_target_id = city_id

	return {
		"ok": true,
		"errors": [],
	}


static func _validate_governor_appointment(state: Dictionary, city_id: String, officer_id: String) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("cities") or not state.cities.has(city_id):
		errors.append("city not found: %s" % city_id)
	if not state.has("officers") or not state.officers.has(officer_id):
		errors.append("officer not found: %s" % officer_id)
	if not errors.is_empty():
		return errors

	var city: Dictionary = state.cities[city_id]
	var officer: Dictionary = state.officers[officer_id]
	if officer.force_id != city.force_id:
		errors.append("officer force does not match city owner")
	return errors

