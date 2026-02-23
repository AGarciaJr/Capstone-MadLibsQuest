extends InteractableArea
class_name KeyPickup

@export var key_id: String = "rusty_key"

func _ready() -> void:
	super._ready()
	
	# If already collected, don't spawn
	if Progress.has_key(key_id):
		queue_free()
		return
	
	set_prompt("Press Enter to pick up")

func interact() -> void:
	if not can_interact():
		return
		
	Progress.give_key(key_id)
	queue_free()
