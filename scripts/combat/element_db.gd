extends Node
class_name ElementDB

@export var json_path: String = "res://data/combat/Elements.json"

# element_id -> {"keywords": PackedStringArray, "weight": float}
var elements: Dictionary = {}
var loaded: bool = false

func _ready() -> void:
	load_db(json_path)

func load_db(path: String) -> bool:
	elements.clear()
	loaded = false

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ElementDB: Failed to open: %s" % path)
		return false

	var text: String = f.get_as_text()
	f.close()

	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("ElementDB: JSON parse error: %s line=%d" % [json.get_error_message(), json.get_error_line()])
		return false

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ElementDB: Expected root Dictionary in %s" % path)
		return false

	var root: Dictionary = data

	# -------- Shape A: root = { "fire": {...}, "water": {...} }
	var looks_like_shape_a: bool = false
	for k in root.keys():
		if typeof(root[k]) == TYPE_DICTIONARY and (root[k] as Dictionary).has("keywords"):
			looks_like_shape_a = true
			break

	if looks_like_shape_a:
		for k in root.keys():
			var elem_id: String = String(k).strip_edges().to_lower()
			var entry: Dictionary = root[k]
			var kw_arr = entry.get("keywords", [])
			var weight: float = float(entry.get("weight", 1.0))
			var kws: PackedStringArray = PackedStringArray()
			for kw in kw_arr:
				var s := String(kw).strip_edges().to_lower()
				if s != "":
					kws.append(s)
			elements[elem_id] = {"keywords": kws, "weight": weight}
		loaded = elements.size() > 0
		print("ElementDB: Loaded elements (shape A) =", elements.size())
		return loaded

	# -------- Shape B: root = { "elements": [ {id, keywords}, ... ] }
	if root.has("elements") and typeof(root["elements"]) == TYPE_ARRAY:
		var arr: Array = root["elements"]
		for item in arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = item
			var elem_id_b: String = String(d.get("id", "")).strip_edges().to_lower()
			if elem_id_b == "":
				continue
			var kw_arr_b = d.get("keywords", [])
			var weight_b: float = float(d.get("weight", 1.0))
			var kws_b: PackedStringArray = PackedStringArray()
			for kw in kw_arr_b:
				var s2 := String(kw).strip_edges().to_lower()
				if s2 != "":
					kws_b.append(s2)
			elements[elem_id_b] = {"keywords": kws_b, "weight": weight_b}
		loaded = elements.size() > 0
		print("ElementDB: Loaded elements (shape B) =", elements.size())
		return loaded

	push_error("ElementDB: Unrecognized JSON schema in %s" % path)
	return false

func is_loaded() -> bool:
	return loaded

func get_element_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in elements.keys():
		out.append(String(k))
	return out
