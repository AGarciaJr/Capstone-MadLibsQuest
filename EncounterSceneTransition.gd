extends Node

const BATTLE_SCENE := preload("res://BattleStub.tscn")

var current_encounter: Dictionary = {}

var _return_scene_path: String = ""
var _return_player_pos: Vector2 = Vector2.ZERO

func start_battle(encounter: Dictionary, return_scene_path: String, return_player_pos: Vector2) -> void:
	current_encounter = encounter
	_return_scene_path = return_scene_path
	_return_player_pos = return_player_pos

	get_tree().change_scene_to_packed(BATTLE_SCENE)

func return_to_overworld() -> void:
	if _return_scene_path.is_empty():
		push_error("GameFlow return scene path is empty.")
		return

	get_tree().change_scene_to_file(_return_scene_path)

func apply_return_state(overworld_root: Node) -> void:
	# Call this from the overworld's _ready() to restore position.
	if overworld_root == null:
		return

	# Find Player by type (no hard-coded node paths)
	var player := _find_first_player(overworld_root)
	if player:
		player.global_position = _return_player_pos
		
func _find_first_player(root: Node) -> Node:
	# Searches the scene tree for the Player 
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is Player:
			return n
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	return null
