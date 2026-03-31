class_name Goblin
extends BaseEnemy
## A sneaky goblin — fast, aggressive, and loves a good ambush.
## Stats and template are set in _init() so .new() is safe outside the scene tree.

const ENCOUNTER_ID: String = "goblin"


func _init() -> void:
	entity_name   = "Goblin"
	max_hp        = 45
	atk           = 7
	def           = 5
	armor         = 2
	crit_chance   = 0.15
	crit_mult     = 1.6
	sprite_frames_path    = "res://assets/Art/Enemies/Monster_Creatures_Fantasy(Version 1.3)/Goblin/Goblin.tres"
	sprite_animation_name = "Goblin 2"

	max_sentences  = 10
	defeat_message = "The goblin cackled, snatched your coin pouch, and vanished into the dark. Your adventure ends... broke."

	base_move = {
		"base_damage": 4,
		"scaling":     0.4,
		"coefficient": 1.0,
		"accuracy":    1.0,
	}

	templates = [
		{
			"line": "The hero faced a ___ goblin who tried to steal their ___ coin pouch with ___ speed!",
			"blanks": [
				{"type": "adjective", "hint": "describe the goblin (sneaky? cheerful? terrifying?)",          "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the coin pouch (leather? velvet? magical?)",          "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the goblin's speed (lightning? suspicious? baffling?)", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "With a ___ screech, the goblin hurled a ___ rock and tried to ___ the hero!",
			"blanks": [
				{"type": "adjective", "hint": "describe the screech (ear-splitting? musical? wet?)",          "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the rock (enormous? glowing? suspiciously smooth?)",  "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "what did it try to do to the hero? (squash? confuse? tackle?)", "display": "VERB"},
			]
		},
		{
			"line": "The goblin's ___ claws slashed out and the hero had to ___ away with a ___ cry!",
			"blanks": [
				{"type": "adjective", "hint": "describe those claws (rusty? razor-sharp? painted?)",           "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "how did the hero escape? (roll? leap? stumble? sprint?)",       "display": "VERB"},
				{"type": "adjective", "hint": "what kind of battle cry? (valiant? panicked? squeaky?)",        "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ goblin ambush forced the hero to ___ through a ___ hail of arrows!",
			"blanks": [
				{"type": "adjective", "hint": "what kind of ambush? (perfectly timed? completely accidental?)", "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "how did the hero move through it? (sprint? crawl? dance?)",      "display": "VERB"},
				{"type": "adjective", "hint": "describe the arrow storm (relentless? surprisingly sparse?)",    "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The goblin chief brandished a ___ war club, let out a ___ roar, and made a ___ charge!",
			"blanks": [
				{"type": "adjective", "hint": "describe the war club (enormous? rusty? bejeweled?)",           "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the roar (thunderous? surprisingly squeaky?)",         "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "what kind of charge was it? (reckless? terrifying? wobbly?)",   "display": "ADJECTIVE"},
			]
		},
		{
			"line": "Covered in ___ warpaint, the goblin tried to ___ the hero's ___ shield away!",
			"blanks": [
				{"type": "adjective", "hint": "describe the warpaint (lurid? smeared? surprisingly artistic?)", "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "what did it try to do to the shield? (yank? bite? charm?)",      "display": "VERB"},
				{"type": "adjective", "hint": "describe the hero's shield (battered? gleaming? borrowed?)",     "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The hero had to ___ fast before the goblin could ___ its tribe with a ___ warning signal!",
			"blanks": [
				{"type": "verb",      "hint": "what should the hero do immediately? (strike? hide? apologize?)", "display": "VERB"},
				{"type": "verb",      "hint": "how does a goblin alert its tribe? (shriek? drum? whistle?)",     "display": "VERB"},
				{"type": "adjective", "hint": "describe the warning signal (deafening? oddly melodic? distant?)", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "A ___ trap sprung from the shadows and the goblin lunged to ___ the hero with ___ cunning!",
			"blanks": [
				{"type": "adjective", "hint": "what kind of trap? (rope? glue? politely labeled?)",            "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "what did the goblin try? (grab? tackle? trick?)",               "display": "VERB"},
				{"type": "adjective", "hint": "how cunning is this goblin really? (fiendish? barely adequate?)", "display": "ADJECTIVE"},
			]
		},
		{
			"line": "The goblin's ___ ally hurled a ___ net to ___ the hero and end the fight!",
			"blanks": [
				{"type": "adjective", "hint": "describe the goblin's ally (hulking? tiny? very enthusiastic?)", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the net (heavy? fraying? surprisingly clean?)",         "display": "ADJECTIVE"},
				{"type": "verb",      "hint": "what was the net supposed to do? (trap? slow? confuse?)",        "display": "VERB"},
			]
		},
		{
			"line": "In a ___ last stand, the goblin leapt with ___ desperation toward the hero's ___ sword!",
			"blanks": [
				{"type": "adjective", "hint": "what kind of last stand? (valiant? desperate? very short?)",    "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "how desperate was that leap? (reckless? teary-eyed? graceful?)", "display": "ADJECTIVE"},
				{"type": "adjective", "hint": "describe the hero's sword (gleaming? chipped? legendary?)",     "display": "ADJECTIVE"},
			]
		},
	]
