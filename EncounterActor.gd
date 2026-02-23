extends Area2D
class_name EncounterActor

@export var overworld: Node2D
@export var player: Player

@export var encounter_id: String = "rat"
@export var auto_start: bool = true
@export var one_time: bool = true

var _player_inside := false
var _used := false

func _ready() -> void:
	# Remove one time encounter if it was already completed
	if one_time and Progress.is_encounter_cleared(encounter_id):
		queue_free()
		return
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if body is Player:
		_player_inside = true
		if auto_start:
			_start_encounter()

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false

func _start_encounter() -> void:
	if _used:
		return
	if not overworld or not player:
		push_error("EncounterActor missing overworld or player")
		return
	
	_used = true
	
	if one_time:
		# mark as cleared
		Progress.clear_encounter(encounter_id)
	
	var encounter := { "encounter_id": encounter_id }
	
	EncounterSceneTransition.start_battle(
		encounter,
		overworld.scene_file_path,
		player.global_position
	)
	
	queue_free()
