class_name BaseEntity
extends CharacterBody2D
## Base class for all in-world entities (player, NPCs, enemies).
## Provides shared identity and movement properties.

@export var entity_name: String = "Entity"
@export var max_hp: int = 10
@export var move_speed: float = 100.0


func _ready() -> void:
	_on_entity_ready()


## Override in subclasses to initialize entity-specific properties.
func _on_entity_ready() -> void:
	pass
