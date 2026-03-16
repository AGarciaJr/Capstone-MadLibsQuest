class_name BaseEnemy
extends BaseEntity
## Base class for all enemy entities.
## Holds combat stats, the battle Mad Lib template, and the enemy's attack move.
## Subclasses set their values in _init() so they are available via .new()
## without needing to be added to the scene tree.

# --- Combat Stats ---
var atk: int = 5
var def: int = 2
var armor: int = 0
var crit_chance: float = 0.05
var crit_mult: float = 1.4

# --- Battle Mad Lib Template ---
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
var blanks: Array = [
	{"type": "noun",      "hint": "a creature/thing",      "display": "NOUN"},
	{"type": "verb",      "hint": "an action",              "display": "VERB"},
	{"type": "adjective", "hint": "a describing word",      "display": "ADJECTIVE"},
]

# --- Enemy Attack Move ---
var base_move: Dictionary = {
	"base_damage": 4,
	"scaling":     0.4,
	"coefficient": 1.0,
	"accuracy":    1.0,
}

# --- Sprite resources for the battle scene ---
## Path to a SpriteFrames .tres resource for this enemy.
var sprite_frames_path: String = ""
## Animation name to play from that SpriteFrames resource.
var sprite_animation_name: String = ""


## Returns a combat-stats dict compatible with CombatEngine.
func get_combat_stats() -> Dictionary:
	return {
		"atk":         atk,
		"crit_chance": crit_chance,
		"crit_mult":   crit_mult,
		"def":         def,
		"armor":       armor,
	}
