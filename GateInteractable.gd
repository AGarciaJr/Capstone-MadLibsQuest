extends InteractableArea
class_name GateInteractable

@export var gate_id: String = "first_gate"
@export var blocker: StaticBody2D
@export var progress: ProgressManager
@export var required_key_id: String = "first_gate_key"

func on_player_entered(_player: Player) -> void:
	_refresh_prompt()

func interact() -> void:
	if not can_interact():
		return

	if progress and progress.has_key(required_key_id):
		# mark gate as unlocked 
		progress.unlock_gate(gate_id)

		if blocker:
			blocker.queue_free()
		queue_free()
	else:
		set_prompt("Locked (need key)")

func _refresh_prompt() -> void:
	if progress and progress.is_gate_unlocked(gate_id):
		set_prompt("Press Enter to open")
	elif progress and progress.has_key(required_key_id):
		set_prompt("Press Enter to open")
	else:
		set_prompt("Locked")
