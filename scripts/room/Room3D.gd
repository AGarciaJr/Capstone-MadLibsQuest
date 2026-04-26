extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var hint_label: Label = $CanvasLayer/UIRoot/BottomCenter/HintLabel
@onready var completion_center: Control = $CanvasLayer/UIRoot/CompletionCenter
@onready var begin_run_button: Button = (
	$CanvasLayer/UIRoot/CompletionCenter/CompletionPanel/CompletionVBox/HBoxContainer/BeginRunButton
)
@onready var fade: ColorRect = $CanvasLayer/UIRoot/Fade
@onready var crosshair: Control = $CanvasLayer/UIRoot/Crosshair
@onready var doors_root : Node3D = $DoorsRoot
@onready var map_overlay: Control = $CanvasLayer/UIRoot/MapOverlay
@onready var map_view: MapView = $CanvasLayer/UIRoot/MapOverlay/Panel/MapView
@onready var main_menu_button: Button = (
	$CanvasLayer/UIRoot/CompletionCenter/CompletionPanel/CompletionVBox/HBoxContainer/MainMenuButton
)

@onready var room_hp_label: Label = $CanvasLayer/UIRoot/RoomHUD/PlayerHP
@onready var room_hp_bar: ProgressBar = $CanvasLayer/UIRoot/RoomHUD/PlayerHPBar
@onready var score_label: Label = $CanvasLayer/UIRoot/ScoreLabel

@export var door_radius: float = .75


const DOOR_SCENE := preload("res://Scenes/Rooms/DoorInteractable.tscn")

var sensitivity := 0.003
var _hovered_door: DoorInteractable = null
var _is_transitioning: bool = false
var _active_doors: Array[DoorInteractable] = []
var _gate_mesh: Mesh
var _gate_tex: Texture2D
var _atlas_tex: Texture2D

func _exit_tree() -> void:
	if is_instance_valid(map_overlay) and map_overlay.visible:
		MouseModeStack.pop(map_overlay)
		InputBlocker.pop(map_overlay)


func _ready() -> void:
	_gate_mesh = load("res://assets/Art/Envoirnment/3D-CubeMaps/gate.obj")
	_gate_tex  = load("res://assets/Art/Envoirnment/3D-CubeMaps/gate.png")
	_atlas_tex = load("res://assets/Art/Envoirnment/3D-CubeMaps/cubemap_atlas01.png")
	
	MouseModeStack.set_default_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not begin_run_button.pressed.is_connected(_on_begin_run_pressed):	
		begin_run_button.pressed.connect(_on_begin_run_pressed)
		
	if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):	
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	completion_center.visible = false
	map_overlay.visible = false
	fade.color = Color( 0, 0, 0, 0)
	fade.visible = true
	
	_update_map_overlay()
	_rebuild_doors()
	_refresh_ui()
	_apply_3d_assets()
	_update_room_hud()

func _input(event):
	# Opening map
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_map_overlay()
			return
	
	if InputBlocker.is_blocked():
		return
	
	# looking
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotate_y(-event.relative.x * sensitivity)

	# Door click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if completion_center.visible or _is_transitioning:
			return
		
		var door := _get_targeted_door()
		if door != null:
			door.interact()
	
func _process(_delta: float) -> void:
	if completion_center.visible or _is_transitioning or InputBlocker.is_blocked():
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
		var door := DOOR_SCENE.instantiate() as DoorInteractable
		doors_root.add_child(door)
		door.next_node_id = next_node_id
		door.name = "Door_%s" % i
		_active_doors.append(door)
	
	for door in _active_doors:
		_place_door(door)
		_apply_gate_to_door(door)

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
			Scenes.ROOM,
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
	var run_complete: bool = (
		nexts.is_empty()
		and curr.get("type", "") == "boss"
		and boss_cleared
	)
	
	if run_complete and Run.run_mode == RunManager.RunMode.TUTORIAL:
		completion_center.visible = not _is_transitioning
		hint_label.visible = false
		crosshair.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	if run_complete and Run.run_mode == RunManager.RunMode.GENERATED and not _is_transitioning:
		_is_transitioning = true
		crosshair.visible = false
		hint_label.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var tween = create_tween()
		tween.tween_property(fade, "color", Color(0,0,0,1), 1.0)
		await tween.finished
		get_tree().change_scene_to_file(Scenes.RUN_COMPLETE)
		return
		
	completion_center.visible = false
	crosshair.visible = not _is_transitioning
	
	if Run.run_mode == RunManager.RunMode.TUTORIAL:
		hint_label.visible = false
	else:
		hint_label.visible = not _is_transitioning
		var hint: String = curr.get("hint", "")
		if hint != "":
			hint_label.text = hint
		else:
			hint_label.text = "Click a door to continue."
		_update_map_overlay()

func _on_begin_run_pressed():
	var saved_name := PlayerState.player_name
	PlayerState.reset_to_defaults()
	PlayerState.player_name = saved_name
	
	# Reset run state
	Run.run_mode = RunManager.RunMode.GENERATED
	Run.start_run()
	# Reset progress manager
	Progress.reset_progress()
	
	EncounterSceneTransition.clear()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file(Scenes.ROOM)

func _on_main_menu_pressed() -> void:
	PlayerState.reset_to_defaults()
	Progress.reset_progress()
	EncounterSceneTransition.clear()
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)

func _update_map_overlay() -> void:
	map_view.set_map_data(Run.map, Run.current_id)
	
func _toggle_map_overlay() ->void:
	# Closing overlay
	if map_overlay.visible:
		map_overlay.visible = false
		MouseModeStack.pop(map_overlay)
		InputBlocker.pop(map_overlay)
		crosshair.visible = true
		return
	
	if InputBlocker.is_blocked() or completion_center.visible or _is_transitioning:
		return
	
	# opening overlay
	map_overlay.visible = true
	MouseModeStack.push(map_overlay, Input.MOUSE_MODE_VISIBLE)
	InputBlocker.push(map_overlay)
	crosshair.visible = false
	_set_hovered_door(null)
	_update_map_overlay()

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

func _apply_3d_assets() -> void:
	_build_room_walls()
	_setup_dungeon_environment()


func _build_room_walls() -> void:
	# cubemap_atlas01.png is a 256x256 texture with a 2x2 grid of 128x128 tiles.
	# Tile UV offsets (each tile occupies 0.5x0.5 of UV space):
	#   Tile 0 (top-left)     : offset (0.0, 0.0)
	#   Tile 1 (top-right)    : offset (0.5, 0.0)
	#   Tile 2 (bottom-left)  : offset (0.0, 0.5)
	#   Tile 3 (bottom-right) : offset (0.5, 0.5)
	const TILE_UV := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.5, 0.0, 0.0),
		Vector3(0.0, 0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
	]

	# [position, rotation_degrees, plane_size, tile_index]
	var walls := [
		[Vector3( 0.0, 0.5, -1.0), Vector3( 90, 0,   0), Vector2(2.0, 1.0), 0],  # front (door wall)
		[Vector3( 0.0, 0.5,  1.0), Vector3( 90, 180, 0), Vector2(2.0, 1.0), 0],  # back
		[Vector3(-1.0, 0.5,  0.0), Vector3(  90, 90, 0), Vector2(2.0, 1.0), 1],  # left
		[Vector3( 1.0, 0.5,  0.0), Vector3(  90, -90,  0), Vector2(2.0, 1.0), 1],  # right
		[Vector3( 0.0, 1.0,  0.0), Vector3(180, 0,   0), Vector2(2.0, 2.0), 2],  # ceiling
	]

	for wall_def in walls:
		var mesh_inst := MeshInstance3D.new()
		var plane     := PlaneMesh.new()
		plane.size    = wall_def[2]
		mesh_inst.mesh = plane

		var mat := StandardMaterial3D.new()
		if _atlas_tex != null:
			mat.albedo_texture = _atlas_tex
			mat.uv1_offset     = TILE_UV[wall_def[3]]
			mat.uv1_scale      = Vector3(0.5, 0.5, 1.0)
		else:
			mat.albedo_color = Color(0.25, 0.20, 0.15)

		mesh_inst.set_surface_override_material(0, mat)
		mesh_inst.position         = wall_def[0]
		mesh_inst.rotation_degrees = wall_def[1]
		add_child(mesh_inst)

	# Apply tile 3 (bottom-right) to the existing floor mesh
	var floor_node := get_node_or_null("Floor") as MeshInstance3D
	if floor_node != null and _atlas_tex != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _atlas_tex
		
		mat.uv1_offset     = TILE_UV[3]
		mat.uv1_scale      = Vector3(0.5, 0.5, 1.0)
		floor_node.set_surface_override_material(0, mat)

func _apply_gate_to_door(door: DoorInteractable) -> void:
	# Gate OBJ native bounds: X(-37,43)  Y(0,465)  Z(-759,-449)
	# Scale to ~0.33 m height, rotate 90° around Y so the gate face is visible,
	# and re-center at the door node's local origin.
	const GATE_SCALE := 0.33 / 465.0
	const GATE_CX    := 3.024    # native centroid X
	const GATE_CY    := 232.290  # native centroid Y
	const GATE_CZ    := -603.695 # native centroid Z

	var rot90          := Basis(Vector3.UP, deg_to_rad(90))
	var scale_basis    := Basis().scaled(Vector3(GATE_SCALE, GATE_SCALE, GATE_SCALE))
	# Origin must cancel the centroid after both rotation and scale are applied:
	#   (rot90 * scale_basis) * centroid + origin = 0
	#   => origin = -(rot90 * scaled_centroid)
	# (Calling rotate_y() after setting the transform would also rotate the origin
	#  vector, displacing the gate ~0.43 m sideways — hence building it all at once.)
	var scaled_centroid := Vector3(GATE_CX * GATE_SCALE, GATE_CY * GATE_SCALE, GATE_CZ * GATE_SCALE)
	var gate_transform  := Transform3D(rot90 * scale_basis, -(rot90 * scaled_centroid))

	var mesh_inst := door.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst == null:
		return

	if _gate_mesh != null:
		mesh_inst.mesh      = _gate_mesh
		mesh_inst.transform = gate_transform

	if _gate_tex != null:
		var mat            := StandardMaterial3D.new()
		mat.albedo_texture = _gate_tex
		mesh_inst.set_surface_override_material(0, mat)
	
	door.refresh_base_material()

func _setup_dungeon_environment() -> void:
	var env := Environment.new()
	env.background_mode       = Environment.BG_COLOR
	env.background_color      = Color(0.04, 0.03, 0.02)   # near-black cave bg
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color   = Color(0.60, 0.45, 0.25)   # warm torchlight tint
	env.ambient_light_energy  = 0.4

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _update_room_hud() -> void:
	room_hp_label.text = "HP: %d / %d" % [PlayerState.current_hp, PlayerState.max_hp]
	room_hp_bar.max_value = PlayerState.max_hp
	room_hp_bar.value = PlayerState.current_hp
	_update_room_hp_bar_color()
	score_label.text = "Score: %d" % PlayerState.current_run_score

func _update_room_hp_bar_color() -> void:
	var percent := float(PlayerState.current_hp) / float(PlayerState.max_hp)
	var color: Color
	if percent > 0.5:
		color = Color(0.2, 0.8, 0.2)
	elif percent > 0.1:
		color = Color(0.9, 0.8, 0.1)
	else:
		color = Color(0.9, 0.1, 0.1)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	room_hp_bar.add_theme_stylebox_override("fill", style)
