extends Node
class_name InteractionManager

@export var prompt_label: Label

var current: InteractableArea = null

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is InteractableArea:
			_connect_interactable(node)

func _connect_interactable(area: InteractableArea) -> void:
	area.focus_entered.connect(_on_focus_entered)
	area.focus_exited.connect(_on_focus_exited)
	area.prompt_changed.connect(_on_prompt_changed)


func _on_focus_entered(area: InteractableArea) -> void:
	current = area
	_show(area.prompt_text)

func _on_focus_exited(area: InteractableArea) -> void:
	if current == area:
		current = null
		_clear()
		
func _on_prompt_changed(area: InteractableArea, new_text: String) -> void:
	if current == area:
		_show(new_text)


func try_interact() -> void:
	if current and current.can_interact():
		current.interact()

func _show(text: String) -> void:
	if prompt_label:
		prompt_label.text = text

func _clear() -> void:
	if prompt_label:
		prompt_label.text = ""
