extends Resource
class_name EnemyData

@export var enemy_name: String
@export var max_health := 5.0
@export var health := max_health
@export var attack_speed := 10.0
@export var damage := 10.0
@export var resistance: Array[Letter.Element] = []
@export var weakness: Array[Letter.Element] = []
@export var sprite_scale := Vector2(1.0, 1.0)
@export var sprite: Texture2D
@export var background: Texture2D
