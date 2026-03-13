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
	
	_refresh_ui()

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
		var encounter_id : String = curr.get("encounter_id", "")
		
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
	elif Run.current_id == 1:
		hint_label.text = "You made it through. Click a door to face the boss."
	else:
		hint_label.text = "Click a door to continue." 

func _on_restart_pressed():
	# Reset tutorial run state
	Run.new_linear_demo_run()
	
	# Reset progress manager
	Progress.reset_progress()
	
	EncounterSceneTransition.clear()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()
