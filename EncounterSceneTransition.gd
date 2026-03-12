extends Node

const BATTLE_SCENE := preload("res://Scenes/Battle/BattleV1.tscn")

var current_encounter: Dictionary = {}

var _return_scene_path: String = ""
var _return_state: Dictionary = {}

func start_battle(encounter: Dictionary, return_scene_path: String, return_state: Dictionary = {}) -> void:
	current_encounter = encounter
	_return_scene_path = return_scene_path
	_return_state = return_state

	get_tree().change_scene_to_packed(BATTLE_SCENE)

func return_to_scene() -> void:
	if _return_scene_path.is_empty():
		push_error("EncounterSceneTransition: return scene path is empty.")
		return

	get_tree().change_scene_to_file(_return_scene_path)

func consume_return_state() -> Dictionary:
	var state := _return_state
	_return_state = {}
	return state
		
func clear() -> void:
	current_encounter = {}
	_return_scene_path = ""
	_return_state = {}
