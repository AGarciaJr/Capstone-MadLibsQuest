# meant to be used as an interface/base class
extends Area2D
class_name InteractableArea

signal focus_entered(interactable: InteractableArea)
signal focus_exited(interactable: InteractableArea)
signal prompt_changed(interactable: InteractableArea, new_text: String)

@export var prompt_text: String = "Press Enter to interact"

var _player_inside := false

func _ready() -> void:
	body_entered.connect(_handle_body_entered)
	body_exited.connect(_handle_body_exited)

func _handle_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = true
		on_player_entered(body) 
		focus_entered.emit(self)

func _handle_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false
		on_player_exited(body) 
		focus_exited.emit(self)

func on_player_entered(_player: Player) -> void:
	pass

func on_player_exited(_player: Player) -> void:
	pass

func set_prompt(text: String) -> void:
	prompt_text = text
	prompt_changed.emit(self, text)

func can_interact() -> bool:
	return _player_inside

func interact() -> void:
	pass
