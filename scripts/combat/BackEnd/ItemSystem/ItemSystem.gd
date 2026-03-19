extends Node

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

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
		"description": "Adds 1 random bonus letter.",
		"effect_type": "add_random_bonus_letters",
		"params": {
			"count": 1
		}
	},
	{
		"id": "add_bonus_letters_2",
		"name": "Glyph of Many Letters",
		"description": "Adds 2 random bonus letters.",
		"effect_type": "add_random_bonus_letters",
		"params": {
			"count": 2
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
	{
		"id": "increase_letter_limit",
		"name": "Scroll of Eloquence",
		"description": "Increases the maximum letters you can use per word by 1.",
		"effect_type": "increase_letter_limit",
		"params": {
			"amount": 1
		}
	},
]

# TODO: merge this with the get one random letter item
func get_random_choices(n: int = 3) -> Array[Dictionary]:
	var non_letter_pool: Array[Dictionary] = items.duplicate()
	non_letter_pool.shuffle()
	var letter_pool: Array[Dictionary] = []
	for i in range(ALPHABET.length()):
		var letter: String = ALPHABET.substr(i, 1)
		letter_pool.append({
			"id": "letter_%s" % letter,
			"name": "Letter %s" % letter,
			"description": "Adds '%s' as a bonus letter. If you already have it, doubles the damage bonus for that letter!" % letter,
			"effect_type": "add_bonus_letter",
			"params": {"letter": letter}
		})
	letter_pool.shuffle()
	var out: Array[Dictionary] = []
	var letter_slot: int = randi() % n
	for i in range(n):
		if i == letter_slot:
			out.append(letter_pool[0])
		else:
			out.append(non_letter_pool.pop_back())
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

		"add_random_bonus_letters":
			var count: int = int(p.get("count", 1))
			PlayerState.add_random_bonus_letters(count)

		"improve_bonus_letter":
			PlayerState.modify_bonus_letter_power(float(p.get("extra_per_match", 0.01)))

		"heal":
			PlayerState.heal(int(p.get("amount", 0)))

		"increase_letter_limit":
			PlayerState.add_letter_limit(int(p.get("amount", 1)))

		_:
			pass
