class_name Skeleton
extends BaseEnemy
## A rattling skeleton warrior — tanky bones, slow but relentless.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "skeleton"


func _init() -> void:
	entity_name   = "Skeleton"
	max_hp        = 35
	atk           = 5
	def           = 3
	armor         = 5  # Bony frame soaks up hits
	crit_chance   = 0.10
	crit_mult     = 1.5
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Skeleton/Skeleton.tres"
	sprite_animation_name = "Idle"

	max_sentences  = 5
	defeat_message = "The skeleton's blade found its mark. You collapse in the dusty corridor, your unfinished story echoing off the ancient walls."

	base_move = {
		"base_damage": 5,
		"scaling":     0.35,
		"coefficient": 0.9,
		"accuracy":    0.95,
	}

	templates = [
		{
			"line": "The hero ___ through the chamber and shattered the skeleton's ___ bones with a ___ blow!",
			"blanks": [
				{"type": "verb",      "hint": "how did the hero move? (charge? dash? cartwheel?)",                   "display": "VERB"},
				{"type": "adjective", "hint": "describe those bones (brittle? ancient? suspiciously sturdy?)",        "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of finishing blow? (devastating? lucky? accidental?)",       "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The skeleton's ___ eye sockets blazed as it raised a ___ blade and swung with ___ fury!",
			"blanks": [
				{"type": "adjective", "hint": "describe the glowing eyes (eerie? neon? disappointingly dim?)",        "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the blade (rusted? enchanted? borrowed?)",                    "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of fury? (bone-rattling? cold? surprisingly polite?)",       "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ clatter rang out as the skeleton swung its ___ sword in a ___ arc overhead!",
			"blanks": [
				{"type": "adjective", "hint": "describe that awful noise (deafening? hollow? strangely musical?)",    "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the sword (cracked? enchanted? way too oversized?)",          "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of arc? (sweeping? awkward? surprisingly graceful?)",        "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The hero had to ___ fast as the skeleton summoned a ___ wave of ___ dark magic!",
			"blanks": [
				{"type": "verb",      "hint": "how did the hero react? (dodge? roll? reconsider everything?)",        "display": "VERB"},
				{"type": "adjective", "hint": "describe the wave (crackling? ominous? disturbingly colorful?)",       "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what flavor of dark magic? (ancient? freezing? oddly familiar?)",      "display": "ADJECTIVE"},
			]
		},
		{
			"line": "With a ___ shriek the skeleton made one final ___ strike in the ___ dungeon corridor!",
			"blanks": [
				{"type": "adjective", "hint": "describe that final shriek (unearthly? rattling? almost musical?)",    "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the last strike (desperate? powerful? catastrophically wide?)", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of dungeon is this? (crumbling? ancient? suspiciously clean?)", "display": "ADJECTIVE"},
			]
		},
	]
