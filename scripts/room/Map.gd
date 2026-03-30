extends Control
class_name MapView

@export var node_radius: float = 25.0
@export var layer_spacing: float = 200.0
@export var row_spacing: float = 150.0
@export var padding: float = 50.0
@export var edge_width: float = 8.0

var _map_data: Dictionary = {}
var _current_id: int = -1

func set_map_data(map_data: Dictionary, current_id: int) -> void:
	_map_data = map_data
	_current_id = current_id
	queue_redraw()
	
func _draw() -> void:
	if _map_data.is_empty() or not _map_data.has("nodes") or not _map_data.has("start_id") or not _map_data.has("layers"):
		return
	
	var positions := {}
	var layers: Array = _map_data["layers"]
	
	for layer_index in range(layers.size()):
		var nodes: Array = layers[layer_index]
		var x_pos := padding + layer_index * layer_spacing
		var total_y := (nodes.size() - 1) * row_spacing
		var start_y := size.y * 0.5 - total_y * 0.5
		
		for i in range(nodes.size()):
			var node_id = nodes[i]
			var y_pos := start_y + i * row_spacing
			positions[node_id] = Vector2(x_pos, y_pos)
	
	var nodes: Dictionary = _map_data["nodes"]
	
	# Draw edges
	for node_id in nodes.keys():
		if not positions.has(node_id):
			continue
		
		var node: Dictionary = nodes[node_id]
		
		for next_id in node.get("next", []):
			if positions.has(next_id):
				draw_line(positions[node_id], positions[next_id], Color(1, 1, 1, 0.4), edge_width)

	# Draw nodes
	for node_id in nodes.keys():
		if not positions.has(node_id):
			continue
		
		var pos: Vector2 = positions[node_id]
		var node: Dictionary = nodes[node_id]
		var node_type: String = node.get("type", "")
		
		var color := Color(0, 0, 0, 1)
		match node_type:
			"start":
				color = Color(0.0, 1.0, 0.5, 1.0)
			"fight":
				color = Color(.2, 0, 1, 1.0)
			"boss":
				color = Color(1, 0, .2, 1.0)
		
		if node_id == _current_id:
			draw_circle(pos, node_radius + 5.0, Color(1, 1, 1, 0.95))
		
		draw_circle(pos, node_radius, color)
				
