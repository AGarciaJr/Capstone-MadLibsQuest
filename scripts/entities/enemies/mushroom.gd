class_name Mushroom
extends BaseEnemy
## A spore-spewing mushroom creature — the toughest of the three demo encounters.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "mushroom"


func _init() -> void:
	entity_name   = "Mushroom"
	max_hp        = 60
	atk           = 10
	def           = 4
	armor         = 3
	crit_chance   = 0.12
	crit_mult     = 1.7
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Mushroom/Mushroom.tres"
	sprite_animation_name = "Idle"

	max_sentences  = 3
	defeat_message = "The fungal spores in the room infected you and you became a mushroom."

	base_move = {
		"base_damage": 6,
		"scaling":     0.45,
		"coefficient": 1.1,
		"accuracy":    1.0,
	}

	templates = [
		{
			"line": "The hero dodged the ___ spores, tried to ___, and struck with ___ fury!",
			"blanks": [
				{"type": "adjective", "hint": "describe the spores",        "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",                  "display": "VERB"},
				{"type": "adjective", "hint": "a powerful describing word", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The ___ mushroom released a ___ cloud that tried to ___ the hero's senses!",
			"blanks": [
				{"type": "adjective", "hint": "describe the mushroom", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the cloud",    "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",             "display": "VERB"},
			]
		},
		{
			"line": "In a ___ rage, the mushroom lunged forward with a ___ roar and a ___ slam!",
			"blanks": [
				{"type": "adjective", "hint": "describe the rage",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the roar",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the slam",  "display": "ADJECTIVE"},
			]
		},
	]
