# Tracks which gates/areas players have unlocked
extends Node
class_name ProgressManager

var unlocked_gates := {}
var keys := {}

func give_key(id: String) -> void:
	keys[id] = true

func has_key(id: String) -> bool:
	return keys.get(id, false)

func unlock_gate(id: String) -> void:
	unlocked_gates[id] = true

func is_gate_unlocked(id: String) -> bool:
	return unlocked_gates.get(id, false)
