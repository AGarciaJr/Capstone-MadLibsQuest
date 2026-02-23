extends InteractableArea
class_name GateInteractable

@export var gate_id: String = "first_gate"
@export var blocker: StaticBody2D
@export var required_key_id: String = "first_gate_key"

func _ready() -> void:
	super._ready()
	
	# Clear blocker and gate interaction area if 
	# already unlocked
	if Progress.is_gate_unlocked(gate_id):
		_open_now()
		return
	
	_refresh_prompt()

func on_player_entered(_player: Player) -> void:
	_refresh_prompt()

func interact() -> void:
	if not can_interact():
		return

	if Progress.is_gate_unlocked(gate_id):
		_open_now()
		return
	
	if Progress.has_key(required_key_id):
		# mark gate as unlocked 
		Progress.unlock_gate(gate_id)
		_open_now()
	else:
		set_prompt("Locked (need key)")

func _refresh_prompt() -> void:
	if Progress.is_gate_unlocked(gate_id) or Progress.has_key(required_key_id):
		set_prompt("Press Enter to open")
	else:
		set_prompt("Locked (need key)")

func _open_now() -> void:
	if blocker:
		blocker.queue_free()
	queue_free()
