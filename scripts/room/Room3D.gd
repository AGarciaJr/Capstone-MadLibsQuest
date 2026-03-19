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
@export var door_radius: float = .5

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
		
		_place_door(door, i, nexts.size())
		_active_doors.append(door)

func _clear_spawned_doors() -> void:
	_set_hovered_door(null)
	
	for door in _active_doors:
		if is_instance_valid(door):
			door.queue_free()
	
	_active_doors.clear()

func _place_door(door: DoorInteractable, index: int, total: int) -> void:
	var angle_offset_degrees: float
	
	if total == 1:
		angle_offset_degrees = 0.0
	elif total <= 5:
		var spread := 120
		var start_angle := -spread * 0.5
		angle_offset_degrees = start_angle + (spread / float(total - 1)) * index
	else:
		angle_offset_degrees = (360 / float(total)) * index
	
	var angle_radians := deg_to_rad(angle_offset_degrees)
	var pos := Vector3(sin(angle_radians) * door_radius, .2, -cos(angle_radians) * door_radius)
	door.position = pos
	
	var center := Vector3(0.0, door.position.y, 0.0)
	door.look_at(center, Vector3.UP)

func _on_door_clicked(next_node_id: int):
	
	if _is_transitioning or not Run.can_advance_to(next_node_id):
		return
	
	Run.advance_to(next_node_id)
	_rebuild_doors()
	_refresh_ui()
	
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
