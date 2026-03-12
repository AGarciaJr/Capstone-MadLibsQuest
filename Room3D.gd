extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var hint_label: Label = $CanvasLayer/UIRoot/BottomCenter/HintLabel
@onready var completion_center: Control = $CanvasLayer/UIRoot/CompletionCenter
@onready var restart_button: Button = $CanvasLayer/UIRoot/CompletionCenter/CompletionPanel/CompletionVBox/RestartButton

var sensitivity := 0.003

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	restart_button.pressed.connect(_on_restart_pressed)
	completion_center.visible = false
	
	_refresh_ui()

func _input(event):
	# looking
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotate_y(-event.relative.x * sensitivity)
	
	# Door click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if completion_center.visible:
			return
		
		var center = get_viewport().get_visible_rect().size * 0.5
		
		var from = camera.project_ray_origin(center)
		var to = from + camera.project_ray_normal(center) * 1000.0
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if result and result.collider:
			if result.collider.name == "Door1" or result.collider.name == "Door2" or result.collider.name == "Door3":
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
	
	var tutorial_complete : bool = nexts.is_empty() and curr.get("type", "") == "boss"
	
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
