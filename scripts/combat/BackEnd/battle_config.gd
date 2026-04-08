class_name BattleConfigFactory

# Maps encounter_id strings to enemy entity scripts.
# Keys must match each enemy class's ENCOUNTER_ID constant.
const ENEMY_REGISTRY := {
	"goblin":   preload("res://scripts/entities/enemies/goblin.gd"),
	"skeleton": preload("res://scripts/entities/enemies/skeleton.gd"),
	"mushroom": preload("res://scripts/entities/enemies/mushroom.gd"),
}

# Builds a battle config dict from the encounter dictionary.
# Loads stats, templates, and sprite data from the enemy entity when available.
static func build(encounter: Dictionary) -> Dictionary:
	var encounter_id: String = encounter.get("encounter_id", "")

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
		"enemy_stats": {"atk": 6, "crit_chance": 0.1, "crit_mult": 1.98, "def": 10, "armor": 10},
		"enemy_move": {
			"base_damage": 4,
			"scaling": 0.4,
			"coefficient": 1.0,
			"accuracy": 1.0,
		},
		"use_element_system": true,
		"player_attacks_per_turn": 1,
		"enemy_attacks_per_turn": 1,
		"sprite_frames_path": "",
		"sprite_animation_name": "",
	}

	if ENEMY_REGISTRY.has(encounter_id):
		var enemy: BaseEnemy = ENEMY_REGISTRY[encounter_id].new() as BaseEnemy
		if enemy != null:
			cfg.enemy_max_hp       = enemy.max_hp
			cfg.enemy_name         = enemy.entity_name
			cfg.enemy_stats        = enemy.get_combat_stats()
			cfg.enemy_move         = enemy.base_move
			cfg.sprite_frames_path    = enemy.sprite_frames_path
			cfg.sprite_animation_name = enemy.sprite_animation_name
			cfg["templates"]          = enemy.templates
			if enemy.templates.size() > 0:
				cfg.template_line = enemy.templates[0].get("line", cfg.template_line)
				cfg.blanks        = enemy.templates[0].get("blanks", cfg.blanks)
			cfg["defeat_message"] = enemy.defeat_message
			enemy.free()

	return cfg
