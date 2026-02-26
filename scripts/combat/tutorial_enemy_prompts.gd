extends Node
class_name TutorialEnemyPrompts

## Simple data container for tutorial enemy battle prompts and word-triggered effects.
## This is intentionally lightweight so it can be wired into any battle scene.

var enemy_configs := {
	"goblin": {
		"name": "Goblin",
		"battle_title": "~ Greedy Roadside Robber ~",
		"template": "On a lonely road, a {0} goblin leapt from behind a {1} cart, screeching about {2} and demanding {3} from every traveler.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the goblin's appearance or mood"},
			{"type": "noun", "hint": "What kind of cart or object is nearby?"},
			{"type": "noun", "hint": "Something shiny or tempting"},
			{"type": "plural_noun", "hint": "What does the goblin demand from travelers?"}
		],
		"special_words": [
			{
				"id": "greed_trigger",
				"keywords": ["gold", "coin", "coins", "treasure", "loot", "riches", "money"],
				"effect": "greed_up",
				"description": "Mentions of wealth make the goblin greedier but sloppier – gains attack, loses defense."
			},
			{
				"id": "sharing_trigger",
				"keywords": ["share", "gift", "donate", "charity", "kindness"],
				"effect": "soften",
				"description": "Words about sharing or kindness confuse the goblin and soften its attacks."
			},
			{
				"id": "insult_trigger",
				"keywords": ["ugly", "stupid", "smelly", "coward"],
				"effect": "feral",
				"description": "Insults send the goblin into a feral rage – big attack boost, small defense drop."
			}
		]
	},
	"skeleton": {
		"name": "Rattling Skeleton",
		"battle_title": "~ Rattling Graveguard ~",
		"template": "Deep in the {0} graveyard, a {1} skeleton rose from a cracked {2}, its {3} eyes fixed on anyone who dared speak of {4}.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the graveyard"},
			{"type": "adjective", "hint": "What kind of skeleton?"},
			{"type": "noun", "hint": "A grave item: coffin, tomb, etc."},
			{"type": "adjective", "hint": "How do its eyes look?"},
			{"type": "noun", "hint": "Something the dead might resent hearing about"}
		],
		"special_words": [
			{
				"id": "bone_pride",
				"keywords": ["bone", "bones", "bony", "rattle", "clatter"],
				"effect": "bone_pride",
				"description": "Words about bones make the skeleton proud – slightly tougher and harder to crack."
			},
			{
				"id": "holy_fear",
				"keywords": ["holy", "blessed", "sacred", "sunlight", "prayer"],
				"effect": "holy_weakness",
				"description": "Holy imagery makes the skeleton shrink back – its armor and attack drop."
			},
			{
				"id": "grave_resentment",
				"keywords": ["life", "living", "party", "festival"],
				"effect": "resentment",
				"description": "Talking about the joys of life enrages the undead – attack up, defense down."
			}
		]
	},
	"bug": {
		"name": "Swarm Bug",
		"battle_title": "~ Chittering Swarm ~",
		"template": "From the {0} underbrush crawled a {1} bug, soon joined by a buzzing {2} of kin, all drawn to the scent of {3}.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the underbrush or forest floor"},
			{"type": "adjective", "hint": "Describe the first bug"},
			{"type": "noun", "hint": "A swarm or group word"},
			{"type": "noun", "hint": "Something that might attract bugs"}
		],
		"special_words": [
			{
				"id": "pest_control",
				"keywords": ["spray", "poison", "flame", "smoke", "repellent"],
				"effect": "pest_control",
				"description": "Words about bug spray or burning scatter the swarm – big defense drop."
			},
			{
				"id": "sweet_lure",
				"keywords": ["honey", "sugar", "nectar", "fruit", "candy"],
				"effect": "sweet_lure",
				"description": "Sweet words make the bugs cluster hungrily – easier to hit, but they bite harder."
			},
			{
				"id": "disgust",
				"keywords": ["gross", "disgusting", "icky", "nasty"],
				"effect": "disgust",
				"description": "Calling them gross steels their resolve – tiny armor boost, tiny attack boost."
			}
		]
	}
}


static func get_enemy_config(id: String) -> Dictionary:
	if TutorialEnemyPrompts.enemy_configs.has(id):
		return TutorialEnemyPrompts.enemy_configs[id]
	return {}
