extends Node2D
class_name Overworld

@export var player: Player
@export var interaction: InteractionManager

var paused := false

func _ready() -> void:
	EncounterSceneTransition.apply_return_state(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		paused = !paused
		if paused and player:
			player.lock_movement()
		elif player:
			player.unlock_movement()

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if interaction:
			interaction.try_interact()
