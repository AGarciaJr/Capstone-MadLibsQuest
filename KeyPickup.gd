extends InteractableArea
class_name KeyPickup

@export var key_id: String = "rusty_key"
@export var progress: ProgressManager

func _ready() -> void:
	prompt_text = "Press Enter to pick up"
	super._ready()

func interact() -> void:
	if not can_interact():
		return
	if progress:
		progress.give_key(key_id)
	queue_free()
