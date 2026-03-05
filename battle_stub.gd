extends Node2D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		# Mark encounter as cleared
		var enc = EncounterSceneTransition.current_encounter
		var encounter_id : String = enc.get("encounter_id", "")
		if encounter_id != "":
			Progress.clear_encounter(encounter_id)
		
		EncounterSceneTransition.return_to_scene()
