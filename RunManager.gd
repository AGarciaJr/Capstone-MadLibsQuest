extends Node
class_name RunManager

var map := {}
var current_id := 0

func _ready() -> void:
	if map.is_empty():
		new_linear_demo_run()

func new_linear_demo_run() -> void:
	map = MapBuilder.build_linear_demo()
	current_id = map["start_id"]

func node() -> Dictionary:
	if map.is_empty() or not map.has("nodes"):
		push_error("RunManager.node(): map not initialized.")
		return { }
	return map["nodes"].get(current_id, {})

func can_advance_to(next_id: int) -> bool:
	var n := node()
	return n.has("next") and next_id in n["next"]
	
func advance_to(next_id: int) -> void:
	if not can_advance_to(next_id):
		push_error("RunManager: invalid next_id %s from %s" % [next_id, current_id])
		return
	current_id = next_id

func next_ids() -> Array:
	return node().get("next", [])
