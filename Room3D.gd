extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var hint_label: Label = $CanvasLayer/UIRoot/BottomCenter/HintLabel
@onready var completion_center: Control = $CanvasLayer/UIRoot/CompletionCenter
@onready var restart_button: Button = $CanvasLayer/UIRoot/CompletionCenter/CompletionPanel/CompletionVBox/RestartButton
@onready var fade: ColorRect = $CanvasLayer/UIRoot/Fade

var sensitivity := 0.003
var _hovered_door: DoorInteractable = null
var _is_transitioning: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	restart_button.pressed.connect(_on_restart_pressed)
	completion_center.visible = false
	fade.color = Color( 0, 0, 0, 0)
	fade.visible = true
	
	_refresh_ui()
	_apply_3d_assets()

func _input(event):
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
	if completion_center.visible or _is_transitioning:
		_set_hovered_door(null)
		return
	
	var targeted_door := _get_targeted_door()
	_set_hovered_door(targeted_door)

func _on_door_clicked(index: int):
	var nexts = Run.next_ids()
	
	if nexts.is_empty() or _is_transitioning:
		return
	
	var next_id = nexts[index]
	
	Run.advance_to(next_id)
	_refresh_ui()
	
	var curr := Run.node()
	var type = curr.get("type", "?")
	
	if type == "fight" or type == "boss":
		var encounter_id: String = curr.get("encounter_id", "")
		
		_is_transitioning = true
		_set_hovered_door(null)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		var tween = create_tween()
		tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.35)
		await tween.finished
		
		EncounterSceneTransition.start_battle(
			{"encounter_id": encounter_id},
			get_tree().current_scene.scene_file_path,
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
	var tutorial_complete: bool = nexts.is_empty() and curr.get("type", "") == "boss" and boss_cleared
	
	completion_center.visible = tutorial_complete
	hint_label.visible = not tutorial_complete
	
	if tutorial_complete:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	if Run.current_id == 0:
		hint_label.text = "Look at a door and click to continue."
	elif Run.current_id == 2:
		hint_label.text = "You made it through. Click a door to face the boss."
	else:
		hint_label.text = "Click a door to continue."

func _apply_3d_assets() -> void:
	_build_room_walls()
	_apply_gate_to_doors()
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

	var atlas := load("res://assets/Art/Envoirnment/3D-CubeMaps/cubemap_atlas01.png") as Texture2D

	# [position, rotation_degrees, plane_size, tile_index]
	var walls := [
		[Vector3( 0.0, 0.5, -1.0), Vector3( 90, 0,   0), Vector2(2.0, 1.0), 0],  # front (door wall)
		[Vector3( 0.0, 0.5,  1.0), Vector3(-90, 0,   0), Vector2(2.0, 1.0), 0],  # back
		[Vector3(-1.0, 0.5,  0.0), Vector3(  0, 0, -90), Vector2(2.0, 1.0), 1],  # left
		[Vector3( 1.0, 0.5,  0.0), Vector3(  0, 0,  90), Vector2(2.0, 1.0), 1],  # right
		[Vector3( 0.0, 1.0,  0.0), Vector3(180, 0,   0), Vector2(2.0, 2.0), 2],  # ceiling
	]

	for wall_def in walls:
		var mesh_inst := MeshInstance3D.new()
		var plane     := PlaneMesh.new()
		plane.size    = wall_def[2]
		mesh_inst.mesh = plane

		var mat := StandardMaterial3D.new()
		if atlas != null:
			mat.albedo_texture = atlas
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
	if floor_node != null and atlas != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = atlas
		mat.uv1_offset     = TILE_UV[3]
		mat.uv1_scale      = Vector3(0.5, 0.5, 1.0)
		floor_node.set_surface_override_material(0, mat)


func _apply_gate_to_doors() -> void:
	var gate_mesh := load("res://assets/Art/Envoirnment/3D-CubeMaps/gate.obj") as Mesh
	var gate_tex  := load("res://assets/Art/Envoirnment/3D-CubeMaps/gate.png") as Texture2D

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

	for door_name in ["Door1", "Door2", "Door3"]:
		var mesh_inst := get_node_or_null(door_name + "/MeshInstance3D") as MeshInstance3D
		if mesh_inst == null:
			continue

		if gate_mesh != null:
			mesh_inst.mesh      = gate_mesh
			mesh_inst.transform = gate_transform

		if gate_tex != null:
			var mat            := StandardMaterial3D.new()
			mat.albedo_texture = gate_tex
			mesh_inst.set_surface_override_material(0, mat)


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


func _on_restart_pressed():
	# Reset tutorial run state
	Run.new_linear_demo_run()
	
	# Reset progress manager
	Progress.reset_progress()
	
	EncounterSceneTransition.clear()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()
