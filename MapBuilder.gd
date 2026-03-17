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
			0: {"type": "start", "next": [1]},
			1: {"type": "fight", "next": [2], "encounter_id": "Goblin 2"},
			2: {"type": "boss", "next": [], "encounter_id": "Boss Rat"},
		}
	}

func build_generated_run() -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	
	_seed = _rng.randi()
	_rng.seed = _seed
	
	_nodes = { }
	_next_id = 0
	
	var start_id := _make_node("start")
	
	# Generate random sizes for node layers between start and boss
	var layer_sizes := [
		_rng.randi_range(1, 3),
		_rng.randi_range(1, 3),
		_rng.randi_range(1, 3),
	]
	
	var layers: Array = []
	layers.append([start_id])
	
	# Fill layers with nodes
	for size in layer_sizes:
		var layer : Array = []
		
		for i in range(size):
			layer.append(_make_node("fight", {
				"encounter_id": _choose_random_encounter(),
			}))
		
		layers.append(layer)
	
	# Add boss node
	var boss_id := _make_node("boss", {
		"encounter_id": "Boss Rat",
	})
	layers.append([boss_id])
	
	_connect_layers(layers)
	
	return {
		"seed": _seed,
		"start_id": start_id,
		"nodes": _nodes
	}
	
func _make_node(node_type: String, attributes: Dictionary = {}) -> int:
	var id := _next_id
	_next_id += 1
	
	var node := {
		"type": node_type,
		"next": [],
	}
	
	for key in attributes.keys():
		node[key] = attributes[key]
	
	_nodes[id] = node
	return id

func _choose_random_encounter() -> String:
	var encounters := ["Goblin", "Skeleton", "Eye"]
	return encounters[_rng.randi_range(0, encounters.size() - 1)]

func _connect_layers(layers: Array) -> void:
	for ndx in range(layers.size() - 1):
		var curr_layer : Array = layers[ndx]
		var next_layer : Array = layers[ndx + 1]
		
		# Connect each node in this layer to nodes in the next layer
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
