extends Node

const BATTLE_SCENE := preload("res://Scenes/Battle/BattleV1.tscn")
const PREBATTLE_SCENE := preload("res://Scenes/PreBattle/PreBattleModifier.tscn")
const POSTBATTLE_SCENE := preload("res://Scenes/PostBattle/PlayerItemChoice.tscn")

var current_encounter: Dictionary = {}
## Set by PreBattle when player continues; battle reads this and applies the modifier.
var current_encounter_modifier_id: String = ""
var pending_reward_items: Array = []

var _return_scene_path: String = ""
var _return_state: Dictionary = {}

## Go straight to battle (no prebattle modifier step).
func start_battle(encounter: Dictionary, return_scene_path: String, return_state: Dictionary = {}) -> void:
	current_encounter = encounter
	current_encounter_modifier_id = ""
	_return_scene_path = return_scene_path
	_return_state = return_state
	get_tree().change_scene_to_packed(BATTLE_SCENE)

## Go to PreBattle first; PreBattle then transitions to battle with modifier set.
func start_battle_with_prebattle(encounter: Dictionary, return_scene_path: String, return_state: Dictionary = {}) -> void:
	current_encounter = encounter
	current_encounter_modifier_id = ""
	_return_scene_path = return_scene_path
	_return_state = return_state
	get_tree().change_scene_to_packed(PREBATTLE_SCENE)

## Called by PreBattle when player clicks Continue; switches to battle and passes modifier id.
func transition_to_battle(modifier_id: String) -> void:
	current_encounter_modifier_id = modifier_id
	get_tree().change_scene_to_packed(BATTLE_SCENE)

func transition_to_postbattle(items: Array) -> void:
	pending_reward_items = items
	get_tree().change_scene_to_packed(POSTBATTLE_SCENE)

func consume_pending_reward_items() -> Array:
	var out := pending_reward_items
	pending_reward_items = []
	return out

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
	current_encounter_modifier_id = ""
	pending_reward_items = []
	_return_scene_path = ""
	_return_state = {}
