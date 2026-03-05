extends Control

@onready var door_container := $DoorContainer
@onready var node_label: Label = $NodeInfoLabel
@onready var hint_label: Label = $HintLabel
@onready var title_label: Label = $TitleLabel

func _ready() -> void:
	if Run.map.is_empty():
		Run.new_linear_demo_run()
	
	_refresh_doors()

func _refresh_doors() -> void:
	for child in door_container.get_children():
		child.queue_free()
	
	var curr = Run.node()
	
	title_label.text = "Demo Run"
	node_label.text = "Current Node: %s | Type: %s" % [
		str(Run.current_id),
		curr.get("type", "?")
	]
	hint_label.text = "Choose a door to continue."
	
	var nexts = Run.next_ids()
	
	for next_id in nexts:
		var button := Button.new()
		var next_node: Dictionary = Run.map["nodes"][next_id]
		button.text = "Go to %s (%s)" % [
			str(next_id), 
			next_node.get("type", "?")
		]
		
		button.pressed.connect(func():
			_on_choose_next(next_id)
		)
		
		door_container.add_child(button)
	
func _on_choose_next(next_id: int) -> void:
	Run.advance_to(next_id)
	var curr := Run.node()
	var type = curr.get("type", "?")
	
	if type == "fight" or type == "boss":
		var encounter_id : String = curr.get("encounter_id", "")
		EncounterSceneTransition.start_battle(
			{"encounter_id": encounter_id},
			get_tree().current_scene.scene_file_path,
			{"node_id": Run.current_id}
		)
	else:
		_refresh_doors()
