class_name Skeleton
extends BaseEnemy
## A rattling skeleton warrior — tanky bones, slow but relentless.
## Stats and template are set in _init() so .new() is safe outside the scene tree.


func _init() -> void:
	entity_name      = "Skeleton"
	max_hp           = 35
	atk              = 8
	def              = 3
	armor            = 5   # Bony frame soaks up hits
	crit_chance      = 0.10
	crit_mult        = 1.5
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Skeleton/Skeleton.tres"
	sprite_animation_name = "Idle"

	template_line = "The hero shattered the ___ bones, made the skeleton ___, and crushed it with ___ might!"
	blanks = [
		{"type": "adjective", "hint": "describe the skeleton",          "display": "ADJECTIVE"},
		{"type": "verb",      "hint": "an action",                       "display": "VERB"},
		{"type": "adjective", "hint": "a powerful describing word",      "display": "ADJECTIVE"},
	]

	base_move = {
		"base_damage": 5,
		"scaling":     0.35,
		"coefficient": 0.9,
		"accuracy":    0.95,
	}
