class_name Mushroom
extends BaseEnemy
## A spore-spewing mushroom creature — the toughest of the three demo encounters.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "mushroom"


func _init() -> void:
	entity_name   = "Mushroom"
	max_hp        = 60
	atk           = 15
	def           = 4
	armor         = 3
	crit_chance   = 0.12
	crit_mult     = 1.7
	sprite_frames_path    = "res://assets/Art/Enemies/Monsters_Creatures_Fantasy/Mushroom/Mushroom.tres"
	sprite_animation_name = "Idle"

	max_sentences  = 3
	defeat_message = "The spores overwhelmed you. Slowly, silently, you took root. The Bard stares at the spot where a hero once stood. It is now a very nice mushroom."

	base_move = {
		"base_damage": 20,
		"scaling":     0.45,
		"coefficient": 1.1,
		"accuracy":    1.0,
	}

	templates = [
		{
			"line": "The hero ___ through the spore cloud and struck the ___ mushroom with a ___ blow!",
			"blanks": [
				{"type": "verb",      "hint": "how did the hero push through the spores? (charge? crawl?)", "display": "VERB"},
				{"type": "adjective", "hint": "describe the mushroom boss (colossal? pulsing? cute?)",                "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of blow landed? (decisive? thunderous? lucky?)",               "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The ___ mushroom released a ___ cloud of spores that tried to ___ the hero's mind!",
			"blanks": [
				{"type": "adjective", "hint": "describe the mushroom (ancient? hulking?)",           "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the spore cloud (choking? glowing? fragrant?)",        "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "what did the spores try to do to the hero's mind? (scramble? overwhelm? redecorate?)", "display": "VERB"},
			]
		},
		{
			"line": "In a ___ rage, the mushroom slammed down a ___ fist with a ___ shockwave!",
			"blanks": [
				{"type": "adjective", "hint": "what kind of rage? (fungal? silent? catastrophic?)",           "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe that fist (enormous? slimy? fast?)",     "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the shockwave (ground-shaking? blinding? damp?)", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The hero ___ around the mushroom's ___ tendrils and countered with a ___ strike!",
			"blanks": [
				{"type": "verb",      "hint": "how did the hero evade? (weave? vault? slide?)",   "display": "VERB"},
				{"type": "adjective", "hint": "describe the tendrils (writhing? sticky? gentle?)", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the counter-attack (precise? desperate? magnificent?)", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "Spores burst from the ___ cap above and the hero had to ___ through a ___ storm of them!",
			"blanks": [
				{"type": "adjective", "hint": "describe the mushroom's enormous cap (glowing? pulsing? ancient?)",      "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "how did the hero push through? (sprint? crawl? power-walk?)",            "display": "VERB"},
				{"type": "adjective", "hint": "describe that spore storm (blinding? rainbow-colored? endless?)", "display": "ADJECTIVE"},
			]
		},
	]
