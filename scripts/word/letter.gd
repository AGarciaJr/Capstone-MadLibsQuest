extends Resource
class_name Letter

enum Element {
	NONE,
	FIRE,
	ICE,
	POISON,
	HOLY
}

@export var character: String
@export var element: int
@export var base_multiplier: float
@export var rarity_multiplier: float

func _init(
	character_string: String, 
	elem: Element=Element.NONE,
	base_mult: float=1.0,
	rare_mult: float=1.0
	) -> void:
	character = character_string
	element = elem
	base_multiplier = base_mult
	rarity_multiplier = rare_mult
