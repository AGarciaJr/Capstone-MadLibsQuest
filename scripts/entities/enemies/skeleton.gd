class_name Skeleton
extends BaseEnemy
## A rattling skeleton warrior — tanky bones, slow but relentless.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "skeleton"


func _init() -> void:
	entity_name   = "Skeleton"
	max_hp        = 35
	atk           = 8
	def           = 3
	armor         = 5  # Bony frame soaks up hits
	crit_chance   = 0.10
	crit_mult     = 1.5
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Skeleton/Skeleton.tres"
	sprite_animation_name = "Idle"

	max_sentences  = 5
	defeat_message = "The skeleton's blade found its mark. You collapse in the dusty corridor, never to rise again."

	base_move = {
		"base_damage": 5,
		"scaling":     0.35,
		"coefficient": 0.9,
		"accuracy":    0.95,
	}

	templates = [
		{
			"line": "The hero shattered the ___ bones, made the skeleton ___, and crushed it with ___ might!",
			"blanks": [
				{"type": "adjective", "hint": "describe the skeleton's bones", "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",                     "display": "VERB"},
				{"type": "adjective", "hint": "a powerful describing word",    "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The skeleton's ___ eye sockets glowed as it tried to ___ the hero with ___ precision!",
			"blanks": [
				{"type": "adjective", "hint": "describe the glow",       "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",               "display": "VERB"},
				{"type": "adjective", "hint": "describe the precision",  "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ clatter echoed as the skeleton raised its ___ blade and unleashed a ___ slash!",
			"blanks": [
				{"type": "adjective", "hint": "describe the clatter", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the blade",   "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the slash",   "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The hero had to ___ quickly as the skeleton conjured a ___ wave of ___ dark energy!",
			"blanks": [
				{"type": "verb",      "hint": "how the hero moved",           "display": "VERB"},
				{"type": "adjective", "hint": "describe the wave",            "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the dark energy",     "display": "ADJECTIVE"},
			]
		},
		{
			"line": "In the ___ dungeon the skeleton made one final ___ strike with a ___ shriek!",
			"blanks": [
				{"type": "adjective", "hint": "describe the dungeon", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the strike",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the shriek",  "display": "ADJECTIVE"},
			]
		},
	]
