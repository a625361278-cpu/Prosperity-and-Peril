extends RefCounted


static func create_sortie(
	state: Dictionary,
	origin_city_id: String,
	commander_officer_id: String,
	route_id: String,
	troop_count: int,
	food_amount: int
) -> Dictionary:
	var errors := _validate_sortie(state, origin_city_id, commander_officer_id, route_id, troop_count, food_amount)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"army_id": "",
		}

	var army_id := "ARMY_%d" % int(state.next_army_seq)
	state.next_army_seq += 1

	var city: Dictionary = state.cities[origin_city_id]
	city.troops -= troop_count
	city.food -= food_amount

	state.armies[army_id] = {
		"id": army_id,
		"origin_city_id": origin_city_id,
		"commander_officer_id": commander_officer_id,
		"route_id": route_id,
		"troop_count": troop_count,
		"food_current": food_amount,
		"route_progress_days": 0,
		"state": "mobilizing",
	}

	return {
		"ok": true,
		"errors": [],
		"army_id": army_id,
	}


static func _validate_sortie(
	state: Dictionary,
	origin_city_id: String,
	commander_officer_id: String,
	route_id: String,
	troop_count: int,
	food_amount: int
) -> Array[String]:
	var errors: Array[String] = []
	if troop_count <= 0:
		errors.append("troop_count must be positive")
	if food_amount <= 0:
		errors.append("food_amount must be positive")
	if not state.has("cities") or not state.cities.has(origin_city_id):
		errors.append("origin city not found: %s" % origin_city_id)
	if not state.has("officers") or not state.officers.has(commander_officer_id):
		errors.append("commander officer not found: %s" % commander_officer_id)
	if not state.has("routes") or not state.routes.has(route_id):
		errors.append("route not found: %s" % route_id)
	if not state.has("armies"):
		errors.append("runtime state missing armies")
	if not state.has("next_army_seq"):
		errors.append("runtime state missing next_army_seq")
	if not errors.is_empty():
		return errors

	var city: Dictionary = state.cities[origin_city_id]
	var officer: Dictionary = state.officers[commander_officer_id]
	var route: Dictionary = state.routes[route_id]

	if officer.force_id != city.force_id:
		errors.append("commander force does not match city owner")
	if route.from_city_id != origin_city_id:
		errors.append("route does not start from origin city")
	if city.troops < troop_count:
		errors.append("city troops are insufficient")
	if city.food < food_amount:
		errors.append("city food is insufficient")

	return errors

