class_name Player
extends BaseEntity
## The player character - controllable entity that can interact with the world.

signal interacted_with(target: Node)

@export var player_class: SpriteAtlas.Rogues = SpriteAtlas.Rogues.RANGER

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var can_move: bool = true
var nearby_interactables: Array[Node] = []

func _on_entity_ready() -> void:
	entity_name = "Player"
	_setup_sprite()

func _setup_sprite() -> void:
	if sprite:
		sprite.texture = SpriteAtlas.get_rogue_texture(player_class)

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		# Flip sprite based on direction
		if sprite and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	
	velocity = input_dir * move_speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		try_interact()

func try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	
	# Interact with the closest interactable
	var closest: Node = nearby_interactables[0]
	interacted_with.emit(closest)
	
	# If it's a Bard, start dialogue
	if closest is Bard:
		var bard := closest as Bard
		if not bard.is_in_dialogue:
			bard.start_dialogue("intro_greeting")

func _on_interaction_area_body_entered(body: Node) -> void:
	if body != self and body.has_method("start_dialogue"):
		nearby_interactables.append(body)

func _on_interaction_area_body_exited(body: Node) -> void:
	nearby_interactables.erase(body)

## Disable movement (e.g., during dialogue)
func freeze() -> void:
	can_move = false
	velocity = Vector2.ZERO

## Re-enable movement
func unfreeze() -> void:
	can_move = true
