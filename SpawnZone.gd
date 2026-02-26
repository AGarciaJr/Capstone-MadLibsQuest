extends Area2D
class_name SpawnZone

@export var zone_id: String = "starter_zone"

@export var encounter_ids: Array[String] = ["rat"]
@export var encounter_weights: Array[float] = [1.0]

@export var max_alive: int = 3
@export var spawn_interval: float = 3.0

@export var min_dist_from_player_pixels: float = 96.0
@export var despawn_distance_pixels: float = 900.0
@export var sample_attempts: int = 16

var is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		is_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		is_player_inside = false


func pick_encounter_id() -> String:
	if encounter_ids.is_empty():
		return ""
	if encounter_ids.size() != encounter_weights.size():
		push_error("Spawnzone has mismatched encounter ids and weights")
		return ""
	
	var total_weights = 0.0
	for weight in encounter_weights:
		total_weights += max(weight, 0.0)
	
	if total_weights <= 0.0:
		push_error("weights must be > 0")
		return ""
	
	var roll : float = total_weights * randf()
	var curr := 0.0
	for i in range(encounter_ids.size()):
		curr += max(encounter_weights[i], 0.0)
		if roll < curr:
			return encounter_ids[i]
			
	return encounter_ids.back()
