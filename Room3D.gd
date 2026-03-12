extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var hint_label: Label = $CanvasLayer/HintLabel

var sensitivity := 0.003

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_ui()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		camera.rotate_y(-event.relative.x * sensitivity)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var center = get_viewport().get_visible_rect().size * 0.5
		
		var from = camera.project_ray_origin(center)
		var to = from + camera.project_ray_normal(center) * 1000.0
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if result and result.collider:
			if result.collider.name == "Door1":
				_on_door_clicked(0)
			elif result.collider.name == "Door2":
				_on_door_clicked(0)
			elif result.collider.name == "Door3":
				_on_door_clicked(0)

func _on_door_clicked(index: int):
	var nexts = Run.next_ids()
	
	if nexts.is_empty():
		return
	
	var next_id = nexts[index]
	
	Run.advance_to(next_id)
	_refresh_ui()
	
	var curr := Run.node()
	var type = curr.get("type", "?")
	
	if type == "fight" or type == "boss":
		var encounter_id : String = curr.get("encounter_id", "")
		
		EncounterSceneTransition.start_battle(
			{"encounter_id": encounter_id},
			get_tree().current_scene.scene_file_path,
			{"node_id": Run.current_id}
		)

func _refresh_ui() -> void:
	var curr := Run.node()
	var nexts = Run.next_ids()
	
	if nexts.is_empty() and curr.get("type", "") == "boss":
		hint_label.text = "Boss cleared. Tutorial complete."
	else:
		hint_label.text = "Current %s (%s). Click a door." % [str(Run.current_id), curr.get("type", "?")]
