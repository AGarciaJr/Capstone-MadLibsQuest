extends StaticBody3D
class_name DoorInteractable

@export var door_index: int = 0
@export var mesh_path: NodePath

var _mesh: MeshInstance3D
var _base_material: Material
var _highlight_material: Material

func _ready() -> void:
	if mesh_path:
		_mesh = get_node_or_null(mesh_path) as MeshInstance3D
		
	if _mesh == null:
		push_warning("DoorInteractable: no MeshInstance3D found for %s" % name)
		return
		
	_base_material = _mesh.get_surface_override_material(0)
	
	if _base_material == null:
		push_warning("DoorInteractable: no material found for %s" % name)
		return
	
	_highlight_material = _base_material.duplicate() as Material
	# brighten the door color
	if _highlight_material is StandardMaterial3D:
		var std := _highlight_material as StandardMaterial3D
		std.albedo_color = std.albedo_color * Color(1.25, 1.25, 1.25, 1.0)
	else:
		push_warning("Can't highlight")
	
func interact():
	get_tree().current_scene._on_door_clicked(door_index)

func set_highlight(enabled: bool):
	if _mesh == null:
		return
	
	if enabled:
		_mesh.set_surface_override_material(0, _highlight_material)
	else:
		_mesh.set_surface_override_material(0, _base_material)
