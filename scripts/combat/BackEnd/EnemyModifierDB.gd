extends Node

var modifiers: Dictionary = {}

@export var customizer_json_path: String = "res://data/Encounter/Customizer.json"

func _ready() -> void:
	_load_modifiers(customizer_json_path)

func _load_modifiers(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed as Dictionary
	if not root.has("modifiers"):
		return
	modifiers.clear()
	for m_any in root["modifiers"]:
		if typeof(m_any) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m_any
		var id := String(m.get("id", ""))
		if id == "":
			continue
		modifiers[id] = m

func get_modifier(id: String) -> Dictionary:
	return modifiers.get(id, {})

func pick_by_adjective(adj: String) -> Dictionary:
	var w := adj.to_lower().strip_edges()
	if w == "":
		return {}
	for id in modifiers.keys():
		var m: Dictionary = modifiers[id]
		var forced = m.get("forced_words", [])
		for fw in forced:
			if String(fw).to_lower() == w:
				return m
	return {}
