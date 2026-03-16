class_name Goblin
extends BaseEnemy
## A sneaky goblin — fast, aggressive, and loves a good ambush.
## Stats and template are set in _init() so .new() is safe outside the scene tree.


func _init() -> void:
	entity_name      = "Goblin"
	max_hp           = 45
	atk              = 10
	def              = 5
	armor            = 2
	crit_chance      = 0.15
	crit_mult        = 1.6
	sprite_frames_path  = "res://assets/Art/Enemies/Monster_Creatures_Fantasy(Version 1.3)/Goblin/Goblin.tres"
	sprite_animation_name = "Goblin 2"

	template_line = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
	blanks = [
		{"type": "noun",      "hint": "a creature/thing",  "display": "NOUN"},
		{"type": "verb",      "hint": "an action",          "display": "VERB"},
		{"type": "adjective", "hint": "a describing word",  "display": "ADJECTIVE"},
	]

	base_move = {
		"base_damage": 4,
		"scaling":     0.4,
		"coefficient": 1.0,
		"accuracy":    1.0,
	}
