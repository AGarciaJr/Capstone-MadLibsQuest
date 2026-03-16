extends Node
class_name MapBuilder

static func build_linear_demo() -> Dictionary:
	return {
		"seed": 0,
		"start_id": 0,
		"nodes": {
			0: {"type": "start",  "next": [1]},
			1: {"type": "fight",  "next": [2], "encounter_id": "goblin"},
			2: {"type": "fight",  "next": [3], "encounter_id": "skeleton"},
			3: {"type": "boss",   "next": [],  "encounter_id": "mushroom"},
		}
	}
