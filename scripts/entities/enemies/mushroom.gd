class_name Mushroom
extends BaseEnemy
## A spore-spewing mushroom creature — the toughest of the three demo encounters.
## Stats and template are set in _init() so .new() is safe outside the scene tree.


func _init() -> void:
	entity_name      = "Mushroom"
	max_hp           = 60
	atk              = 12
	def              = 4
	armor            = 3
	crit_chance      = 0.12
	crit_mult        = 1.7
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Mushroom/Mushroom.tres"
	sprite_animation_name = "Idle"

	template_line = "The hero dodged the ___ spores, tried to ___, and struck with ___ fury!"
	blanks = [
		{"type": "adjective", "hint": "describe the spores",       "display": "ADJECTIVE"},
		{"type": "verb",      "hint": "an action",                  "display": "VERB"},
		{"type": "adjective", "hint": "a powerful describing word", "display": "ADJECTIVE"},
	]

	base_move = {
		"base_damage": 6,
		"scaling":     0.45,
		"coefficient": 1.1,
		"accuracy":    1.0,
	}
