extends Node

const SAVE_PATH := "user://save.json"

func save() -> void:
	if Run.run_mode != RunManager.RunMode.GENERATED:
		return
	
	var data := {
		"player": {
			"player_name": PlayerState.player_name,
			"max_hp": PlayerState.max_hp,
			"current_hp": PlayerState.current_hp,
			"stats": PlayerState.stats,
			"player_letters": Array(PlayerState.player_letters),
			"initial_player_letters": Array(PlayerState.initial_player_letters),
			"letter_bonus_per_match": PlayerState.letter_bonus_per_match,
			"letter_bonus_all_letters_extra": PlayerState.letter_bonus_all_letters_extra,
			"letter_bonus_cap": PlayerState.letter_bonus_cap,
			"letter_limit": PlayerState.letter_limit,
			"inventory": PlayerState.inventory,
			"current_run_score": PlayerState.current_run_score
		},
		"run": {
			"map": Run.map,
			"current_id": Run.current_id,
			"run_mode": Run.run_mode
		},
		"progress": {
			"cleared_encounters": Progress.cleared_encounters,
		}
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	
func load_save() -> bool:
	if not has_save():
		return false
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading")
		return false
	
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: failed to parse save file")
		return false
		
	var data: Dictionary = json.data
	
	# Restore PlayerState
	var p: Dictionary = data.get("player", {})
	PlayerState.player_name = str(p.get("player_name", ""))
	PlayerState.max_hp = int(p.get("max_hp", 100))
	PlayerState.current_hp = int(p.get("current_hp", 100))
	PlayerState.stats = p.get("stats", PlayerState.stats)
	PlayerState.set_initial_player_letters(PackedStringArray(Array(p.get("initial_player_letters", [])).map(func(x): return str(x))))
	PlayerState.set_player_letters(PackedStringArray(Array(p.get("player_letters", [])).map(func(x): return str(x))))
	PlayerState.letter_bonus_per_match = float(p.get("letter_bonus_per_match", 0.05))
	PlayerState.letter_bonus_all_letters_extra = float(p.get("letter_bonus_all_letters_extra", 2.0))
	PlayerState.letter_bonus_cap = float(p.get("letter_bonus_cap", 99.0))
	PlayerState.letter_limit = int(p.get("letter_limit", 6))
	PlayerState.current_run_score = int(p.get("current_run_score", 0))
	var inv = p.get("inventory", [])
	PlayerState.inventory.clear()
	for item in inv:
		if typeof(item) == TYPE_DICTIONARY:
			PlayerState.inventory.append(item)
	
	# Restore Run
	var r: Dictionary = data.get("run", {})
	var raw_map: Dictionary = r.get("map", {})

	# conver the JSON string integer representations back to integers, rebuilding the map
	var fixed_nodes: Dictionary = {}
	if raw_map.has("nodes"):
		for key in raw_map["nodes"].keys():
			var node: Dictionary = raw_map["nodes"][key]
			if node.has("next"):
				var fixed_next: Array = []
				for next_id in node["next"]:
					fixed_next.append(int(next_id))
				node["next"] = fixed_next
			fixed_nodes[int(key)] = node
		raw_map["nodes"] = fixed_nodes

	if raw_map.has("layers"):
		var fixed_layers: Array = []
		for layer in raw_map["layers"]:
			var fixed_layer: Array = []
			for node_id in layer:
				fixed_layer.append(int(node_id))
			fixed_layers.append(fixed_layer)
		raw_map["layers"] = fixed_layers

	Run.map = raw_map
	Run.current_id = int(r.get("current_id", 0))
	Run.run_mode = int(r.get("run_mode", RunManager.RunMode.GENERATED))
	
	# Restore Progress
	var prog: Dictionary = data.get("progress", {})
	Progress.cleared_encounters = prog.get("cleared_encounters", {})
	
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
