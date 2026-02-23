# Tracks which gates/areas players have unlocked
extends Node
class_name ProgressManager

var unlocked_gates := {}
var keys := {}
# use this only for limited encounters like bosses
var cleared_encounters := {}

func give_key(id: String) -> void:
	keys[id] = true

func has_key(id: String) -> bool:
	return keys.get(id, false)

func unlock_gate(id: String) -> void:
	unlocked_gates[id] = true

func is_gate_unlocked(id: String) -> bool:
	return unlocked_gates.get(id, false)
	
func clear_encounter(id: String) -> void:
	cleared_encounters[id] = true

func is_encounter_cleared(id: String) -> bool:
	return cleared_encounters.get(id, false)
