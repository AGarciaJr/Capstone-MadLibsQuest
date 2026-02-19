extends CharacterBody2D
class_name Player

@export var speed := 400

enum PlayerState { FREE, LOCKED }
var state := PlayerState.FREE 

func _get_input():
	if state != PlayerState.FREE:
		velocity = Vector2(0, 0)
		return
	
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed

func lock_movement() -> void:
	state = PlayerState.LOCKED
	velocity = Vector2(0, 0)
	
func unlock_movement() -> void:
	state = PlayerState.FREE
	
func _physics_process(delta):
	_get_input()
	move_and_slide()
