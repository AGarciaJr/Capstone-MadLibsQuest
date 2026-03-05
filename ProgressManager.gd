extends Node
class_name ProgressManager

var cleared_encounters := {}
	
func clear_encounter(id: String) -> void:
	cleared_encounters[id] = true

func is_encounter_cleared(id: String) -> bool:
	return cleared_encounters.get(id, false)
