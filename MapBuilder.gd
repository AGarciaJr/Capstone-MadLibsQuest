extends Node
class_name MapBuilder

## Pool of random encounters available for regular fight nodes.
## Room3D picks from this list each time a fight door is opened.
const FIGHT_ENCOUNTER_POOL: Array[String] = ["goblin", "skeleton"]

static func build_linear_demo() -> Dictionary:
	return {
		"seed": 0,
		"start_id": 0,
		"nodes": {
			0: {"type": "start", "next": [1]},
			1: {"type": "fight", "next": [2]},
			2: {"type": "boss",  "next": [], "encounter_id": "Boss Rat"},
		}
	}
