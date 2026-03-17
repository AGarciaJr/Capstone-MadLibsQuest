class_name BattleConfigFactory

# Pure data/config builder for basic battles.
static func build(encounter: Dictionary) -> Dictionary:
	# Input: EncounterSceneTransition.current_encounter (or any Dictionary
	# with at least "encounter_id": String).
	#
	# Output example:
	# {
	#   "enemy_max_hp": int,
	#   "player_max_hp": int,
	#   "enemy_name": String,
	#   "template_line": String,
	#   "blanks": Array[Dictionary],
	#   "bonus_letters": PackedStringArray,
	#   "letter_bonus_per_match": float,
	#   "letter_bonus_all_letters_extra": float,
	#   "letter_bonus_cap": float,
	#   "player_stats": Dictionary,
	#   "enemy_stats": Dictionary,
	#   "enemy_move": Dictionary,
	#   "use_element_system": bool
	# }

	var encounter_id: String = encounter.get("encounter_id", "Goblin 2")

	# Defaults that work for any simple encounter.
	var cfg: Dictionary = {
		"enemy_max_hp": 30,
		"player_max_hp": 100,
		"enemy_name": "Enemy",
		"template_line": "The hero faced a fearsome ___, chose to ___, and won with ___ force!",
		"blanks": [
			{"type": "noun", "hint": "a creature/thing", "display": "NOUN"},
			{"type": "verb", "hint": "an action", "display": "VERB"},
			{"type": "adjective", "hint": "a describing word", "display": "ADJECTIVE"},
		],
		"bonus_letters": PackedStringArray(["A", "E", "S", "T"]),
		"letter_bonus_per_match": 0.05,
		"letter_bonus_all_letters_extra": 0.15,
		"letter_bonus_cap": 0.50,
		"player_stats": {"atk": 10, "crit_chance": 0.10, "crit_mult": 1.5, "def": 0, "armor": 0},
		"enemy_stats": {"atk": 6, "crit_chance": 0.05, "crit_mult": 1.4, "def": 2, "armor": 10},
		"enemy_move": {
			"base_damage": 4,
			"scaling": 0.4,
			"coefficient": 1.0,
			"accuracy": 1.0,
		},
		"use_element_system": false,
		"player_attacks_per_turn": 1,
		"enemy_attacks_per_turn": 1,
	}

	match encounter_id:
		"Goblin 2":
			cfg.enemy_max_hp = 30
			cfg.enemy_name = "Goblin"
			cfg.template_line = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
			cfg.blanks = [
				{"type": "noun", "hint": "a creature/thing", "display": "NOUN"},
				{"type": "verb", "hint": "an action", "display": "VERB"},
				{"type": "adjective", "hint": "a describing word", "display": "ADJECTIVE"},
			]
			# Element system enabled by default here.
			cfg.use_element_system = true
		"Goblin King":
			cfg.enemy_max_hp = 50
			cfg.enemy_name = "Goblin King"
			cfg.template_line = "The hero challenged the monstrous ___, tried to ___, and struck with ___ power!"
			cfg.blanks = [
				{"type": "noun", "hint": "a monster/title", "display": "NOUN"},
				{"type": "verb", "hint": "an action", "display": "VERB"},
				{"type": "adjective", "hint": "a powerful describing word", "display": "ADJECTIVE"},
			]
			# Example: maybe you do NOT want elements for this fight.
			cfg.use_element_system = false
			# Example: boss gets 2 attacks, player still gets 1
			cfg.enemy_attacks_per_turn = 2
		_:
			# Keep defaults.
			pass

	return cfg
