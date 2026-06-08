extends RefCounted


static func start_march(state: Dictionary, army_id: String, speed_base: float, food_cost_per_day: int) -> Dictionary:
	var errors := _validate_start_march(state, army_id, speed_base, food_cost_per_day)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
		}

	var army: Dictionary = state.armies[army_id]
	var route: Dictionary = state.routes[army.route_id]
	var days_required := int(ceil(float(route.distance) / (speed_base * float(route.terrain_modifier))))

	army.state = "marching"
	army.speed_base = speed_base
	army.food_cost_per_day = food_cost_per_day
	army.days_required = days_required
	army.route_progress_days = 0
	army.out_of_supply = false

	return {
		"ok": true,
		"errors": [],
	}


static func advance_army_one_day(state: Dictionary, army_id: String) -> Dictionary:
	var errors := _validate_daily_advance(state, army_id)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
		}

	var army: Dictionary = state.armies[army_id]
	army.route_progress_days += 1
	army.food_current = max(0, int(army.food_current) - int(army.food_cost_per_day))

	if int(army.food_current) <= 0:
		army.out_of_supply = true
		army.state = "out_of_supply"
		return {
			"ok": true,
			"errors": [],
		}

	if int(army.route_progress_days) >= int(army.days_required):
		army.state = "engaged"

	return {
		"ok": true,
		"errors": [],
	}


static func _validate_start_march(state: Dictionary, army_id: String, speed_base: float, food_cost_per_day: int) -> Array[String]:
	var errors: Array[String] = []
	if speed_base <= 0.0:
		errors.append("speed_base must be positive")
	if food_cost_per_day <= 0:
		errors.append("food_cost_per_day must be positive")
	if not state.has("armies") or not state.armies.has(army_id):
		errors.append("army not found: %s" % army_id)
	if not errors.is_empty():
		return errors

	var army: Dictionary = state.armies[army_id]
	if not state.has("routes") or not state.routes.has(army.route_id):
		errors.append("army route not found: %s" % army.route_id)
	if army.state != "mobilizing":
		errors.append("army must be mobilizing before march")
	return errors


static func _validate_daily_advance(state: Dictionary, army_id: String) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("armies") or not state.armies.has(army_id):
		errors.append("army not found: %s" % army_id)
		return errors

	var army: Dictionary = state.armies[army_id]
	if not ["marching", "out_of_supply"].has(army.state):
		errors.append("army is not marching")
	if not army.has("days_required"):
		errors.append("army missing days_required")
	if not army.has("food_cost_per_day"):
		errors.append("army missing food_cost_per_day")
	return errors

