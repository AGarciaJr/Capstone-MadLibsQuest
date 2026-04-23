extends Node

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

## Used by `get_random_choices` when n == 3: one roll per pool, shuffled for display order.
const REWARD_POOL_BASE_STATS := "base_stats"
const REWARD_POOL_LETTER_POWER := "letter_power"
## Single-letter picks and multi-letter rolls are mutually exclusive — both live here; only one is offered per victory.
const REWARD_POOL_LETTER_ACQUISITION := "letter_acquisition"

var items: Array[Dictionary] = [
	{
		"id": "hp_and_stats_boost",
		"reward_pool": REWARD_POOL_BASE_STATS,
		"category": "Base Stats",
		"name": "Hanma's Charm",
		"description": "Increase max HP and core stats.",
		"icon": "res://assets/Art/Items/heart.png",
		"effect_type": "boost_stats",
		"params": {
			"max_hp_flat": 10,
			"atk_flat": 3,
			"def_flat": 2
		}
	},
	{
		"id": "add_bonus_letters_2",
		"reward_pool": REWARD_POOL_LETTER_ACQUISITION,
		"category": "Power Boost",
		"name": "Glyph of Many Letters",
		"description": "Adds 2 random letters, or grants XP to ones you already own.",
		"icon": "res://assets/Art/Items/scroll.png",
		"effect_type": "add_random_player_letters",
		"params": {
			"count": 2
		}
	},
	{
		"id": "improve_bonus_letter",
		"reward_pool": REWARD_POOL_LETTER_POWER,
		"category": "Power Boost",
		"name": "Alphabet Amplification",
		"description": "Increases letter bonus damage.",
		"icon": "res://assets/Art/Items/ink.png",
		"effect_type": "improve_letter_bonus",
		"params": {
			"extra_per_match": 0.12
		}
	},
	{
		"id": "heal_player_low",
		"reward_pool": REWARD_POOL_BASE_STATS,
		"category": "Base Stats",
		"name": "Apple",
		"description": "Restores HP after battle.",
		"icon": "res://assets/Art/Items/apple.png",
		"effect_type": "heal",
		"params": {
			"amount": 20
		}
	},
	{
		"id": "heal_player_med",
		"reward_pool": REWARD_POOL_BASE_STATS,
		"category": "Base Stats",
		"name": "Bandage",
		"description": "Restores HP after battle.",
		"icon": "res://assets/Art/Items/potion.png",
		"effect_type": "heal",
		"params": {
			"amount": 40
		}
	},
	{
		"id": "heal_player_high",
		"reward_pool": REWARD_POOL_BASE_STATS,
		"category": "Base Stats",
		"name": "Scroll of healing",
		"description": "Restores HP after battle.",
		"icon": "res://assets/Art/Items/scroll.png",
		"effect_type": "heal",
		"params": {
			"amount": 100
		}
	},

]


func get_random_choices(n: int = 3) -> Array[Dictionary]:
	if n == 3:
		return _get_pooled_random_choices_3()
	return _get_random_choices_legacy(n)


func _get_pooled_random_choices_3() -> Array[Dictionary]:
	var base_pool: Array[Dictionary] = []
	var letter_power_pool: Array[Dictionary] = []
	var letter_acquisition_pool: Array[Dictionary] = []

	for it in items:
		var pool: String = String(it.get("reward_pool", ""))
		match pool:
			REWARD_POOL_BASE_STATS:
				base_pool.append(it)
			REWARD_POOL_LETTER_POWER:
				letter_power_pool.append(it)
			REWARD_POOL_LETTER_ACQUISITION:
				letter_acquisition_pool.append(it)
			_:
				pass
	
	if PlayerState.current_hp >= PlayerState.max_hp:
		base_pool = base_pool.filter(func(item): return item.get("effect_type", "") != "heal")

	for i in range(ALPHABET.length()):
		var letter: String = ALPHABET.substr(i, 1)
		letter_acquisition_pool.append({
			"id": "letter_%s" % letter,
			"reward_pool": REWARD_POOL_LETTER_ACQUISITION,
			"category": "Letters recruitment",
			"name": "Letter %s" % letter,
			"description": "Adds '%s' as a player letter, or grants bonus XP if you already have it!" % letter,
			"icon": "res://assets/Art/Items/ink.png",
			"effect_type": "add_player_letter",
			"params": {"letter": letter}
		})

	if base_pool.is_empty() or letter_power_pool.is_empty() or letter_acquisition_pool.is_empty():
		push_warning("ItemSystem: empty reward pool, using legacy item roll")
		return _get_random_choices_legacy(3)

	var out: Array[Dictionary] = [
		base_pool[randi() % base_pool.size()].duplicate(true),
		letter_power_pool[randi() % letter_power_pool.size()].duplicate(true),
		letter_acquisition_pool[randi() % letter_acquisition_pool.size()].duplicate(true),
	]
	return out


func _get_random_choices_legacy(n: int) -> Array[Dictionary]:
	var non_letter_pool: Array[Dictionary] = items.duplicate()
	non_letter_pool.shuffle()
	var letter_pool: Array[Dictionary] = []
	for i in range(ALPHABET.length()):
		var letter: String = ALPHABET.substr(i, 1)
		letter_pool.append({
			"id": "letter_%s" % letter,
			"category": "Letters recruitment",
			"name": "Letter %s" % letter,
			"description": "Adds '%s' as a player letter, or grants bonus XP if you already have it!" % letter,
			"icon": "res://assets/Art/Items/ink.png",
			"effect_type": "add_player_letter",
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
		"add_player_letter":
			PlayerState.add_player_letter(String(p.get("letter", "A")))
		"add_random_player_letters":
			var count_new: int = int(p.get("count", 1))
			PlayerState.add_random_player_letters(count_new)
		"improve_letter_bonus":
			PlayerState.modify_letter_bonus_power(float(p.get("extra_per_match", 0.01)))

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
			PlayerState.add_player_letter(String(p.get("letter", "A")))

		"add_random_bonus_letters":
			var count: int = int(p.get("count", 1))
			PlayerState.add_random_player_letters(count)

		"improve_bonus_letter":
			PlayerState.modify_letter_bonus_power(float(p.get("extra_per_match", 0.01)))

		"heal":
			PlayerState.heal(int(p.get("amount", 0)))

		"increase_letter_limit":
			PlayerState.add_letter_limit(int(p.get("amount", 1)))

		_:
			pass
