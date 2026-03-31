extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var hint_label: Label = $CanvasLayer/UIRoot/BottomCenter/HintLabel
@onready var completion_center: Control = $CanvasLayer/UIRoot/CompletionCenter
@onready var restart_button: Button = $CanvasLayer/UIRoot/CompletionCenter/CompletionPanel/CompletionVBox/RestartButton
@onready var fade: ColorRect = $CanvasLayer/UIRoot/Fade
@onready var crosshair: Control = $CanvasLayer/UIRoot/Crosshair
@onready var doors_root : Node3D = $DoorsRoot
@onready var map_overlay: Control = $CanvasLayer/UIRoot/MapOverlay
@onready var map_view: MapView = $CanvasLayer/UIRoot/MapOverlay/Panel/MapView

@export var door_scene: PackedScene
@export var door_radius: float = .75

var sensitivity := 0.003
var _hovered_door: DoorInteractable = null
var _is_transitioning: bool = false
var _active_doors: Array[DoorInteractable] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not restart_button.pressed.is_connected(_on_restart_pressed):	
		restart_button.pressed.connect(_on_restart_pressed)
	
	completion_center.visible = false
	map_overlay.visible = false
	fade.color = Color( 0, 0, 0, 0)
	fade.visible = true
	
	_update_map_overlay()
	_rebuild_doors()
	_refresh_ui()

func _input(event):
	# looking
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotate_y(-event.relative.x * sensitivity)
	
	# Door click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if completion_center.visible or _is_transitioning or map_overlay.visible:
			return
		
		var door := _get_targeted_door()
		if door != null:
			door.interact()
	
	# Opening map
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_map_overlay()
			return

func _process(_delta: float) -> void:
	if completion_center.visible or _is_transitioning or map_overlay.visible:
		_set_hovered_door(null)
		return
	
	var targeted_door := _get_targeted_door()
	_set_hovered_door(targeted_door)

func _rebuild_doors() -> void:
	_clear_spawned_doors()
	
	var nexts: Array = Run.next_ids()
	
	if nexts.is_empty():
		return
	
	for i in range(nexts.size()):
		var next_node_id: int = nexts[i]
		var door := door_scene.instantiate() as DoorInteractable
		doors_root.add_child(door)
		door.next_node_id = next_node_id
		door.name = "Door_%s" % i
		_active_doors.append(door)
	
	for door in _active_doors:
		_place_door(door)

func _clear_spawned_doors() -> void:
	_set_hovered_door(null)
	
	for door in _active_doors:
		if is_instance_valid(door):
			door.queue_free()
	
	_active_doors.clear()

func _place_door(door: DoorInteractable) -> void:
	var map: Dictionary = Run.map
	var current_id: int = Run.current_id
	var next_id: int = door.next_node_id
	
	var current_pos := _find_node_position(current_id, map)
	var next_pos := _find_node_position(next_id, map)
	
	var angle_deg: float = 0.0
	
	if current_pos.layer >= 0 and next_pos.layer >= 0:
		# convert the position to a value between 0-1 to represent the real position,
		# i.e. a node with index 0 in a layer of 1 node is technically centered and in the same
		# position as a node with index 1 in a layer with 3 nodes, so they should have the same
		# normalized position
		var current_normalized_pos := 0.0
		var next_normalized_pos := 0.0
		 
		if current_pos.layer_size <= 1:
			current_normalized_pos = 0.5
		else:
			current_normalized_pos = float(current_pos.row) / float(current_pos.layer_size - 1)
			
		if next_pos.layer_size <= 1:
			next_normalized_pos = 0.5
		else:
			next_normalized_pos = float(next_pos.row) / float(next_pos.layer_size - 1)
		
		# Find the angle to place the door in front of the player so the room doors align with the map
		var difference = next_normalized_pos - current_normalized_pos
		angle_deg = difference * 75.0
		
		# Position doors in a circular arc
		var angle_rads = deg_to_rad(angle_deg)
		var pos := Vector3(sin(angle_rads) * door_radius, 0.2, -cos(angle_rads) * door_radius)
		door.position = pos
		var center := Vector3(0.0, door.position.y, 0.0)
		door.look_at(center, Vector3.UP)

func _on_door_clicked(next_node_id: int):
	if _is_transitioning or not Run.can_advance_to(next_node_id):
		return
	
	Run.advance_to(next_node_id)
	
	var curr := Run.node()
	var type = curr.get("type", "?")
	
	if type == "fight" or type == "boss":
		var encounter_id : String = curr.get("encounter_id", "")
		
		_is_transitioning = true
		crosshair.visible = false
		hint_label.visible = false
		_set_hovered_door(null)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		var tween = create_tween()
		tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.35)
		await tween.finished
		
		EncounterSceneTransition.start_battle_with_prebattle(
			{"encounter_id": encounter_id},
			scene_file_path,
			{"node_id": Run.current_id}
		)
		return
	
	# does nothing for now, when using non-combat scenes this will refresh the room
	_rebuild_doors()
	_refresh_ui()
	
func _get_targeted_door() -> DoorInteractable:
	var center = get_viewport().get_visible_rect().size * 0.5
		
	var from = camera.project_ray_origin(center)
	var to = from + camera.project_ray_normal(center) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result and result.collider is DoorInteractable:
		return result.collider as DoorInteractable
	
	return null

	
func _set_hovered_door(targeted_door: DoorInteractable) -> void:
	if _hovered_door == targeted_door:
		return
	
	if _hovered_door != null:
		_hovered_door.set_highlight(false)
	
	_hovered_door = targeted_door
	
	if _hovered_door != null:
		_hovered_door.set_highlight(true)

func _refresh_ui() -> void:
	var curr := Run.node()
	var nexts = Run.next_ids()
	
	var encounter_id: String = curr.get("encounter_id", "")
	var boss_cleared := encounter_id != "" and Progress.is_encounter_cleared(encounter_id)
	var tutorial_complete: bool = (
		Run.run_mode == RunManager.RunMode.TUTORIAL
		and nexts.is_empty()
		and curr.get("type", "") == "boss"
		and boss_cleared
	)
	
	completion_center.visible = tutorial_complete and not _is_transitioning
	hint_label.visible = not tutorial_complete and not _is_transitioning
	crosshair.visible = not tutorial_complete and not _is_transitioning
	
	if tutorial_complete:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	if Run.run_mode == RunManager.RunMode.TUTORIAL:
		if Run.current_id == 0:
			hint_label.text = "Look at a door and click to continue."
		elif Run.current_id == 1:
			hint_label.text = "You made it through. Click a door to face the boss."
		else:
			hint_label.text = "Click a door to continue." 
	else:
		match curr.get("type", ""):
			"start":
				hint_label.text = "Choose a path."
			"fight":
				hint_label.text = "Choose your next path"
			"boss":
				hint_label.text = "Defeated the boss"
			_:
				hint_label.text = "Choose a path."
	
	_update_map_overlay()

func _on_restart_pressed():
	var saved_letters := PlayerState.player_letters.duplicate()
	var saved_name := PlayerState.player_name
	
	PlayerState.reset_to_defaults()
	
	PlayerState.set_player_letters(saved_letters)
	PlayerState.player_name = saved_name
	# Reset tutorial run state
	Run.new_tutorial_run()
	
	# Reset progress manager
	Progress.reset_progress()
	
	EncounterSceneTransition.clear()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()

func _update_map_overlay() -> void:
	map_view.set_map_data(Run.map, Run.current_id)
	
func _toggle_map_overlay() ->void:
	if completion_center.visible or _is_transitioning:
		return
	
	map_overlay.visible = not map_overlay.visible
	
	if map_overlay.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		crosshair.visible = false
		_set_hovered_door(null)
		_update_map_overlay()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		crosshair.visible = true

func _find_node_position(node_id: int, map: Dictionary) -> Dictionary:
	var not_found := {"layer": -1, "row": -1, "layer_size": -1}
	if not map.has("layers"):
		return not_found
	var layers: Array = map["layers"]
	for layer_index in range(layers.size()):
		var layer: Array = layers[layer_index]
		for row_index in range(layer.size()):
			if layer[row_index] == node_id:
				return {"layer": layer_index, "row": row_index, "layer_size": layer.size()}
	return not_found
