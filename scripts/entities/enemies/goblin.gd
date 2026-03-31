class_name Goblin
extends BaseEnemy
## A sneaky goblin — fast, aggressive, and loves a good ambush.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "goblin"


func _init() -> void:
	entity_name   = "Goblin"
	max_hp        = 45
	atk           = 10
	def           = 5
	armor         = 2
	crit_chance   = 0.15
	crit_mult     = 1.6
	sprite_frames_path    = "res://assets/Art/Enemies/Monster_Creatures_Fantasy(Version 1.3)/Goblin/Goblin.tres"
	sprite_animation_name = "Goblin 2"

	max_sentences  = 10
	defeat_message = "The goblin cackled and emptied your coin pouch. You lost all your gold!"

	base_move = {
		"base_damage": 15,
		"scaling":     0.4,
		"coefficient": 1.0,
		"accuracy":    1.0,
	}

	templates = [
		{
			"line": "The hero faced a ___ goblin who tried to steal their ___ coin pouch with ___ speed!",
			"blanks": [
				{"type": "adjective", "hint": "describe the goblin",      "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the coin pouch",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the speed",       "display": "ADJECTIVE"},
			]
		},
		{
			"line": "With a ___ screech, the goblin hurled a ___ rock and tried to ___ the hero!",
			"blanks": [
				{"type": "adjective", "hint": "describe the screech",      "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the rock",         "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action done to someone", "display": "VERB"},
			]
		},
		{
			"line": "The goblin's ___ claws slashed out and the hero had to ___ away with a ___ cry!",
			"blanks": [
				{"type": "adjective", "hint": "describe the claws",      "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "how the hero moved",       "display": "VERB"},
				{"type": "adjective", "hint": "describe the battle cry",  "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ goblin ambush forced the hero to ___ through a ___ hail of arrows!",
			"blanks": [
				{"type": "adjective", "hint": "describe the ambush",  "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "how the hero moved",   "display": "VERB"},
				{"type": "adjective", "hint": "describe the hail",    "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The goblin chief raised a ___ war club and made a ___ charge with a ___ roar!",
			"blanks": [
				{"type": "adjective", "hint": "describe the war club", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the charge",   "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the roar",     "display": "ADJECTIVE"},
			]
		},
		{
			"line": "Covered in ___ warpaint, the goblin tried to ___ the hero's ___ shield away!",
			"blanks": [
				{"type": "adjective", "hint": "describe the warpaint", "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",             "display": "VERB"},
				{"type": "adjective", "hint": "describe the shield",   "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The hero needed to ___ the goblin before it could ___ its tribe with a ___ signal!",
			"blanks": [
				{"type": "verb",      "hint": "an action",                "display": "VERB"},
				{"type": "verb",      "hint": "how it alerts the tribe",  "display": "VERB"},
				{"type": "adjective", "hint": "describe the signal",      "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ trap sprung and the goblin lunged to ___ the hero with ___ cunning!",
			"blanks": [
				{"type": "adjective", "hint": "describe the trap",    "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",            "display": "VERB"},
				{"type": "adjective", "hint": "describe the cunning", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The goblin's ___ ally hurled a ___ net hoping to ___ the hero completely!",
			"blanks": [
				{"type": "adjective", "hint": "describe the ally",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the net",   "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "an action",          "display": "VERB"},
			]
		},
		{
			"line": "In a ___ last stand, the goblin attempted a ___ leap with ___ desperation!",
			"blanks": [
				{"type": "adjective", "hint": "describe the last stand",  "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the leap",        "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the desperation", "display": "ADJECTIVE"},
			]
		},
	]
