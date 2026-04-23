extends Node

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

## Roll weight = `α^rarity` with `α` lerped by encounter difficulty: `α < 1` at low difficulty (high rarity unlikely), `α > 1` at high difficulty (high rarity likely). `rarity` 0 is always weight 1.
const ITEM_RARITY_ALPHA_AT_LOW_DIFF := 0.58
const ITEM_RARITY_ALPHA_AT_HIGH_DIFF := 1.52
## Encounter `difficulty` at or above this uses full high-difficulty α (linear ramp below).
const ITEM_RARITY_DIFFICULTY_CAP := 6

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
		"name": "Jimmy's Juice",
		"description": "Increase Max HP, Attack, Defense, and Critical hit chance by a moderate amount.",
		"icon": "res://assets/Art/Items/heart.png",
		"effect_type": "boost_stats",
		"rarity": 1,
		"params": {
			"max_hp_flat": 10,
			"atk_flat": 5,
			"def_flat": 2,
			"crit_chance_flat": 0.1
		}
	},
	{
		"id": "hp_and_stats_boost",
		"reward_pool": REWARD_POOL_BASE_STATS,
		"category": "Base Stats",
		"name": "Hanma's Hand",
		"description": "Increase Max HP, Attack, Defense, and Critical hit chance by a massive amount.",
		"effect_type": "boost_stats",
		"rarity": 2,
		"params": {
			"max_hp_flat": 25,
			"atk_flat": 10,
			"def_flat": 10,
			"crit_chance_flat": 0.3
		}
	},
	## adding an item that prevents death once on 1 hp 
	## adding an item that is like leftovers from pokemon 1/8 hp per turn heal 
	## adding 
	{
		"id": "add_bonus_letters_2",
		"reward_pool": REWARD_POOL_LETTER_ACQUISITION,
		"category": "Power Boost",
		"name": "Glyph of Many Letters",
		"description": "Adds 2 random letters, or grants XP to ones you already own.",
		"icon": "res://assets/Art/Items/scroll.png",
		"effect_type": "add_random_player_letters",
		"rarity": 1,
		"params": {
			"count": 2
		}
	},
	{
		"id": "improve_bonus_letter",
		"reward_pool": REWARD_POOL_LETTER_POWER,
		"category": "Power Boost",
		"name": "Character Chakram",
		"description": "Increases letter bonus damage.",
		"icon": "res://assets/Art/Items/ink.png",
		"effect_type": "improve_letter_bonus",
		"rarity": 0,
		"params": {
			"extra_per_match": 0.12
		}
	},
	{
		"id": "improve_bonus_letter_med",
		"reward_pool": REWARD_POOL_LETTER_POWER,
		"category": "Power Boost",
		"name": "Letter Lampoon",
		"description": "Increases letter bonus damage.",
		"effect_type": "improve_letter_bonus",
		"rarity": 1,
		"params": {
			"extra_per_match": 0.18
		}
	},
	{
		"id": "improve_bonus_letter_max",
		"reward_pool": REWARD_POOL_LETTER_POWER,
		"category": "Power Boost",
		"name": "Alphabet Amplification",
		"description": "Increases letter bonus damage.",
		"effect_type": "improve_letter_bonus",
		"rarity": 2,
		"params": {
			"extra_per_match": 0.23
		}
	},
	{
		"id": "infinity_edge",
		"reward_pool": REWARD_POOL_LETTER_POWER,
		"category": "Power Boost",
		"name": "Infinity Edge",
		"description": "Sharpen your strikes: more critical hits and harder crits.",
		"effect_type": "boost_crit",
		"rarity": 1,
		"params": {
			"crit_chance_flat": 0.25,
			"crit_mult_flat": 0.25
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
		"rarity": 0,
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
		"rarity": 1,
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
		"rarity": 2,
		"params": {
			"amount": 100
		}
	},

]


func get_random_choices(n: int = 3, reward_difficulty: int = 0) -> Array[Dictionary]:
	if n == 3:
		return _get_pooled_random_choices_3(reward_difficulty)
	return _get_random_choices_legacy(n, reward_difficulty)


func _item_rarity_roll_weight(item: Dictionary, difficulty: int) -> float:
	var r: int = maxi(0, int(item.get("rarity", 0)))
	var d: float = maxf(0.0, float(maxi(0, difficulty)))
	var t: float = 1.0 if ITEM_RARITY_DIFFICULTY_CAP <= 0 else clampf(d / float(ITEM_RARITY_DIFFICULTY_CAP), 0.0, 1.0)
	var alpha: float = lerpf(ITEM_RARITY_ALPHA_AT_LOW_DIFF, ITEM_RARITY_ALPHA_AT_HIGH_DIFF, t)
	return pow(alpha, float(r))


func _weighted_pick_index(pool: Array[Dictionary], difficulty: int) -> int:
	if pool.is_empty():
		return 0
	if pool.size() == 1:
		return 0
	var total: float = 0.0
	var weights: Array[float] = []
	for it in pool:
		var w: float = _item_rarity_roll_weight(it, difficulty)
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if roll <= acc:
			return i
	return pool.size() - 1


func _pick_from_pool_weighted_duplicate(pool: Array[Dictionary], difficulty: int) -> Dictionary:
	if pool.is_empty():
		return {}
	var idx: int = _weighted_pick_index(pool, difficulty)
	return pool[idx].duplicate(true)


func _pick_from_pool_weighted_remove(pool: Array[Dictionary], difficulty: int) -> Dictionary:
	if pool.is_empty():
		return {}
	var idx: int = _weighted_pick_index(pool, difficulty)
	var picked: Dictionary = pool[idx].duplicate(true)
	pool.remove_at(idx)
	return picked


func _get_pooled_random_choices_3(reward_difficulty: int = 0) -> Array[Dictionary]:
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
			"rarity": 0,
			"params": {"letter": letter}
		})

	if base_pool.is_empty() or letter_power_pool.is_empty() or letter_acquisition_pool.is_empty():
		push_warning("ItemSystem: empty reward pool, using legacy item roll")
		return _get_random_choices_legacy(3, reward_difficulty)

	var out: Array[Dictionary] = [
		_pick_from_pool_weighted_duplicate(base_pool, reward_difficulty),
		_pick_from_pool_weighted_duplicate(letter_power_pool, reward_difficulty),
		_pick_from_pool_weighted_duplicate(letter_acquisition_pool, reward_difficulty),
	]
	out.shuffle()
	return out


func _get_random_choices_legacy(n: int, reward_difficulty: int = 0) -> Array[Dictionary]:
	var non_letter_pool: Array[Dictionary] = items.duplicate()
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
			"rarity": 0,
			"params": {"letter": letter}
		})
	letter_pool.shuffle()
	if reward_difficulty <= 0:
		non_letter_pool.shuffle()
	var out: Array[Dictionary] = []
	var letter_slot: int = randi() % n
	for i in range(n):
		if i == letter_slot:
			out.append(letter_pool[0])
		else:
			if reward_difficulty <= 0:
				if non_letter_pool.size() > 0:
					out.append(non_letter_pool.pop_back())
			else:
				if non_letter_pool.is_empty():
					break
				out.append(_pick_from_pool_weighted_remove(non_letter_pool, reward_difficulty))
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
			if p.has("crit_chance_flat"):
				flat["crit_chance"] = float(p["crit_chance_flat"])

			var max_hp_gain: int = int(p.get("max_hp_flat", 0))
			if max_hp_gain > 0:
				PlayerState.max_hp += max_hp_gain
				PlayerState.current_hp = clampi(PlayerState.current_hp + max_hp_gain, 0, PlayerState.max_hp)
			PlayerState.apply_stat_mod(flat, {})

		"boost_crit":
			var flat_crit: Dictionary = {}
			if p.has("crit_chance_flat"):
				flat_crit["crit_chance"] = float(p["crit_chance_flat"])
			if p.has("crit_mult_flat"):
				flat_crit["crit_mult"] = float(p["crit_mult_flat"])
			PlayerState.apply_stat_mod(flat_crit, {})

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
