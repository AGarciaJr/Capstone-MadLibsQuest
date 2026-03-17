extends Node
class_name MapBuilder

static func build_linear_demo() -> Dictionary:
	return {
		"seed": 0,
		"start_id": 0,
		"nodes": {
			0: {"type": "start", "next": [1]},
			1: {"type": "fight", "next": [2], "encounter_id": "Goblin 2"},
			2: {"type": "boss", "next": [], "encounter_id": "Goblin King"},
		}
	}
