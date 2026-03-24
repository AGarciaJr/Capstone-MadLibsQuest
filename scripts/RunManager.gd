extends Node
class_name RunManager

enum RunMode {
	TUTORIAL,
	GENERATED
}

var map := {}
var current_id := 0
var run_mode : RunMode = RunMode.GENERATED

func _ready() -> void:
	if map.is_empty():
		start_run()
		
func start_run() -> void:
	match run_mode:
		RunMode.TUTORIAL:
			map = MapBuilder.build_tutorial_run()
		RunMode.GENERATED:
			map = MapBuilder.build_generated_run()
	
	current_id = map["start_id"]

func new_tutorial_run() -> void:
	run_mode = RunMode.TUTORIAL
	start_run()

func new_generated_run() -> void:
	run_mode = RunMode.GENERATED
	start_run()

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
