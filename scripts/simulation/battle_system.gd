extends RefCounted


static func resolve_city_battle(state: Dictionary, army_id: String, target_city_id: String) -> Dictionary:
	var errors := _validate_city_battle(state, army_id, target_city_id)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"winner": "",
			"battle_id": "",
		}

	var army: Dictionary = state.armies[army_id]
	var target_city: Dictionary = state.cities[target_city_id]
	var origin_city: Dictionary = state.cities[army.origin_city_id]
	var commander: Dictionary = state.officers[army.commander_officer_id]
	var attacker_force_id := str(origin_city.force_id)
	var defender_force_id := str(target_city.force_id)

	var attacker_power := int(army.troop_count) + int(commander.leadership) * 100
	var defender_power := int(target_city.troops)
	var battle_id := "BATTLE_%d" % int(state.next_battle_seq)
	state.next_battle_seq += 1

	if attacker_power > defender_power:
		var attacker_loss = min(int(army.troop_count), max(1, int(ceil(float(defender_power) * 0.25))))
		army.troop_count = max(0, int(army.troop_count) - attacker_loss)
		army.state = "victorious"
		army.last_battle_result = "attacker_victory"
		target_city.force_id = attacker_force_id
		target_city.previous_force_id = defender_force_id
		target_city.troops = 0
		target_city.recovery_state = "occupied"
		state.battle_logs[battle_id] = _battle_log(battle_id, army_id, target_city_id, "attacker", attacker_loss, defender_power)
		return {
			"ok": true,
			"errors": [],
			"winner": "attacker",
			"battle_id": battle_id,
		}

	var defender_loss = min(int(target_city.troops), max(1, int(ceil(float(army.troop_count) * 0.35))))
	target_city.troops = max(0, int(target_city.troops) - defender_loss)
	army.troop_count = 0
	army.state = "defeated"
	army.last_battle_result = "defender_victory"
	state.battle_logs[battle_id] = _battle_log(battle_id, army_id, target_city_id, "defender", int(army.troop_count), defender_loss)
	return {
		"ok": true,
		"errors": [],
		"winner": "defender",
		"battle_id": battle_id,
	}


static func _validate_city_battle(state: Dictionary, army_id: String, target_city_id: String) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("armies") or not state.armies.has(army_id):
		errors.append("army not found: %s" % army_id)
	if not state.has("cities") or not state.cities.has(target_city_id):
		errors.append("target city not found: %s" % target_city_id)
	if not state.has("battle_logs"):
		errors.append("runtime state missing battle_logs")
	if not state.has("next_battle_seq"):
		errors.append("runtime state missing next_battle_seq")
	if not errors.is_empty():
		return errors

	var army: Dictionary = state.armies[army_id]
	if army.state != "engaged":
		errors.append("army must be engaged before battle")
	if not state.routes.has(army.route_id):
		errors.append("army route not found: %s" % army.route_id)
		return errors

	var route: Dictionary = state.routes[army.route_id]
	if route.to_city_id != target_city_id:
		errors.append("target city is not route destination")
	if not state.cities.has(army.origin_city_id):
		errors.append("army origin city not found: %s" % army.origin_city_id)
	if not state.officers.has(army.commander_officer_id):
		errors.append("army commander not found: %s" % army.commander_officer_id)
	if errors.is_empty():
		var origin_city: Dictionary = state.cities[army.origin_city_id]
		var target_city: Dictionary = state.cities[target_city_id]
		if origin_city.force_id == target_city.force_id:
			errors.append("target city already belongs to attacker force")
	return errors


static func _battle_log(
	battle_id: String,
	army_id: String,
	target_city_id: String,
	winner: String,
	attacker_loss: int,
	defender_loss: int
) -> Dictionary:
	return {
		"id": battle_id,
		"army_id": army_id,
		"target_city_id": target_city_id,
		"winner": winner,
		"attacker_loss": attacker_loss,
		"defender_loss": defender_loss,
	}

