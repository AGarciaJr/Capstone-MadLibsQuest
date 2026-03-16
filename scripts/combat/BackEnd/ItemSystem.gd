extends Node

var items: Array[Dictionary] = [
	{
		"id": "hp_and_stats_boost",
		"name": "Hanma's Charm",
		"description": "Increase max HP and core stats.",
		"effect_type": "boost_stats",
		"params": {
			"max_hp_flat": 10,
			"atk_flat": 3,
			"def_flat": 2
		}
	},
	{
		"id": "add_bonus_letter",
		"name": "Glyph of Letters",
		"description": "Adds a new bonus letter.",
		"effect_type": "add_bonus_letter",
		"params": {
			"letter": "R"
		}
	},
	{
		"id": "improve_bonus_letter",
		"name": "Alphabet Amplification",
		"description": "Increases letter bonus damage.",
		"effect_type": "improve_bonus_letter",
		"params": {
			"extra_per_match": 0.12
		}
	},
	{
		"id": "heal_player",
		"name": "Apple",
		"description": "Restores HP after battle.",
		"effect_type": "heal",
		"params": {
			"amount": 20
		}
	},
]

func get_random_choices(n: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = items.duplicate()
	pool.shuffle()
	var count: int = min(n, pool.size())
	var out: Array[Dictionary] = []
	for i in range(count):
		out.append(pool[i])
	return out

func apply_item(item: Dictionary) -> void:
	var t: String = String(item.get("effect_type", ""))
	var p: Dictionary = item.get("params", {}) as Dictionary

	match t:
		"boost_stats":
			var flat: Dictionary = {}
			if p.has("atk_flat"):
				flat["atk"] = int(p["atk_flat"])
			if p.has("def_flat"):
				flat["def"] = int(p["def_flat"])

			PlayerState.max_hp += int(p.get("max_hp_flat", 0))
			PlayerState.heal(int(p.get("max_hp_flat", 0)))
			PlayerState.apply_stat_mod(flat, {})

		"add_bonus_letter":
			PlayerState.add_bonus_letter(String(p.get("letter", "A")))

		"improve_bonus_letter":
			PlayerState.modify_bonus_letter_power(float(p.get("extra_per_match", 0.01)))

		"heal":
			PlayerState.heal(int(p.get("amount", 0)))

		_:
			pass
