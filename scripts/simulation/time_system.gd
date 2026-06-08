extends RefCounted

const DAYS_PER_MONTH := 30


static func advance_days(state: Dictionary, days: int) -> Dictionary:
	if days <= 0:
		return {
			"ok": false,
			"errors": ["days must be a positive integer"],
			"events": [],
		}
	if not state.has("current_day"):
		return {
			"ok": false,
			"errors": ["runtime state missing current_day"],
			"events": [],
		}
	if not state.has("current_month"):
		return {
			"ok": false,
			"errors": ["runtime state missing current_month"],
			"events": [],
		}

	var events: Array[Dictionary] = []
	for _i in days:
		state.current_day += 1
		if state.current_day % DAYS_PER_MONTH == 0:
			state.current_month += 1
			events.append({
				"type": "monthly_tick",
				"day": state.current_day,
				"month": state.current_month,
			})

	return {
		"ok": true,
		"errors": [],
		"events": events,
	}

