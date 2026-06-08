extends RefCounted

const PROGRESS_PER_TASK := 25
const PUBLIC_ORDER_RECOVERY_PER_TASK := 5
const MORALE_RECOVERY_PER_TASK := 5


static func apply_integration_task(state: Dictionary, city_id: String, officer_id: String) -> Dictionary:
	var errors := _validate_integration_task(state, city_id, officer_id)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
		}

	var city: Dictionary = state.cities[city_id]
	city.integration_progress = min(100, int(city.integration_progress) + PROGRESS_PER_TASK)
	city.public_order = min(100, int(city.public_order) + PUBLIC_ORDER_RECOVERY_PER_TASK)
	city.morale_public = min(100, int(city.morale_public) + MORALE_RECOVERY_PER_TASK)

	if int(city.integration_progress) >= 100:
		city.recovery_state = "normal"

	return {
		"ok": true,
		"errors": [],
	}


static func _validate_integration_task(state: Dictionary, city_id: String, officer_id: String) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("cities") or not state.cities.has(city_id):
		errors.append("city not found: %s" % city_id)
	if not state.has("officers") or not state.officers.has(officer_id):
		errors.append("officer not found: %s" % officer_id)
	if not errors.is_empty():
		return errors

	var city: Dictionary = state.cities[city_id]
	var officer: Dictionary = state.officers[officer_id]
	if city.recovery_state != "occupied":
		errors.append("city is not occupied")
	if officer.force_id != city.force_id:
		errors.append("officer force does not match city owner")
	if not city.has("integration_progress"):
		errors.append("occupied city missing integration_progress")
	return errors

