extends Node
class_name Map

var _rng: RandomNumberGenerator
var _next_id: int = 0
var _nodes: Dictionary = {}
var _seed : int = 0

func build_tutorial_run() -> Dictionary:
	return {
		"seed": 0,
		"start_id": 0,
		"nodes": {
			0: {"type": "start", "next": [1], "hint": "Look at a door and click to continue."},
			1: {"type": "fight", "next": [2], "encounter_id": Goblin.ENCOUNTER_ID, "hint": "You made it through. Click a door to continue."},
			2: {"type": "fight", "next": [3], "encounter_id": Skeleton.ENCOUNTER_ID, "hint": "Almost there! Click the door to fight the boss."},
			3: {"type": "boss",  "next": [],  "encounter_id": Mushroom.ENCOUNTER_ID},
		},
		"layers": [
			[0],
			[1],
			[2],
			[3]
		],
	}

func build_generated_run(
	num_layers: int = 3,
	min_nodes_per_layer: int = 1,
	max_nodes_per_layer: int = 3,
	encounters: Array = [],
	boss_encounter_id: String = "",
	run_seed: int = -1
) -> Dictionary:
	# Default pool: all three enemies. Callers can override.
	if encounters.is_empty():
		encounters = [Goblin.ENCOUNTER_ID, Skeleton.ENCOUNTER_ID, Mushroom.ENCOUNTER_ID]
	if boss_encounter_id.is_empty():
		boss_encounter_id = Mushroom.ENCOUNTER_ID
	_rng = RandomNumberGenerator.new()

	if run_seed == -1:
		_rng.randomize()
		_seed = _rng.randi()
	else:
		_seed = run_seed
	
	_rng.seed = _seed
	
	_nodes = { }
	_next_id = 0
	
	var start_id := _make_node("start")
	
	var layers: Array = []
	layers.append([start_id])
	
	# Create normal encounter layers
	for i in range(num_layers):
		var layer_size := _rng.randi_range(min_nodes_per_layer, max_nodes_per_layer)
		var layer : Array = []
		
		for j in range(layer_size):
			layer.append(_make_node("fight", {
				"encounter_id": _choose_random_encounter(encounters),
			}))
		
		layers.append(layer)
	
	# Add boss node
	var boss_id := _make_node("boss", {
		"encounter_id": boss_encounter_id,
	})
	layers.append([boss_id])
	
	_connect_layers(layers)
	
	return {
		"seed": _seed,
		"start_id": start_id,
		"nodes": _nodes,
		"layers": layers,
	}
	
func _make_node(node_type: String, attributes: Dictionary = {}) -> int:
	var id := _next_id
	_next_id += 1

	var node_data := {
		"type": node_type,
		"next": [],
	}

	for key in attributes.keys():
		node_data[key] = attributes[key]

	_nodes[id] = node_data
	return id

func _choose_random_encounter(encounters: Array) -> String:
	return encounters[_rng.randi_range(0, encounters.size() - 1)]

func _connect_layers(layers: Array) -> void:
	for ndx in range(layers.size() - 1):
		var curr_layer : Array = layers[ndx]
		var next_layer : Array = layers[ndx + 1]
		
		# Connect each node in this layer to at least one node in the next layer
		for node_id in curr_layer:
			# choose a random number of nodes in the next layer to connect to
			var connections: Array = []
			var num_connections = _rng.randi_range(1, next_layer.size())
			
			# avoid duplicate entries
			var available_nodes = next_layer.duplicate()
			
			for i in range(num_connections):
				var chosen_ndx := _rng.randi_range(0, available_nodes.size() - 1)
				connections.append(available_nodes[chosen_ndx])
				available_nodes.remove_at(chosen_ndx)
			
			_nodes[node_id]["next"] = connections 
		# Ensure every node in the next layer is reachable from somewhere in this layer
		for next_id in next_layer:
			var reachable := false
			
			for node_id in curr_layer:
				if next_id in _nodes[node_id]["next"]:
					reachable = true
					break
			
			if not reachable:
				var node_id = curr_layer[_rng.randi_range(0, curr_layer.size() - 1)]
				_nodes[node_id]["next"].append(next_id)
		
