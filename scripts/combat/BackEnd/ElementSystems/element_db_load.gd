extends Node

var elements: Variant = {}                    
var classification_settings: Dictionary = {} 
var _loaded: bool = false
var _last_error: String = ""

@export var elements_json_path: String = "res://data/combat/Elements.json"

func _ready() -> void:
	load_elements(elements_json_path)

func is_loaded() -> bool:
	return _loaded

func get_last_error() -> String:
	return _last_error

func get_settings() -> Dictionary:
	return classification_settings


func load_elements(path: String) -> void:
	_loaded = false
	_last_error = ""

	if not FileAccess.file_exists(path):
		_last_error = "Elements JSON not found at: %s" % path
		push_error(_last_error)
		return

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_last_error = "Failed to open Elements JSON at: %s" % path
		push_error(_last_error)
		return

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_last_error = "Elements JSON parse failed or root is not an object (Dictionary)."
		push_error(_last_error)
		return

	var root: Dictionary = parsed as Dictionary

	# ----- Pull settings -----
	# Prefer "classification_settings" if present; otherwise "settings"; otherwise defaults.
	if root.has("classification_settings") and typeof(root["classification_settings"]) == TYPE_DICTIONARY:
		classification_settings = root["classification_settings"] as Dictionary
	elif root.has("settings") and typeof(root["settings"]) == TYPE_DICTIONARY:
		classification_settings = root["settings"] as Dictionary
	else:
		classification_settings = {}

	_apply_default_settings()

	# pull elements 
	# Prefer "elements" field; otherwise treat root as the elements dictionary.
	var raw_elements: Variant
	if root.has("elements"):
		raw_elements = root["elements"]
	else:
		raw_elements = root

	# Normalize to either:
	# - Dictionary keyed by id -> entry dict with explicit "id"
	# - Array of entry dicts with explicit "id"
	if typeof(raw_elements) == TYPE_DICTIONARY:
		elements = _normalize_elements_dict(raw_elements as Dictionary)
	elif typeof(raw_elements) == TYPE_ARRAY:
		elements = _normalize_elements_array(raw_elements as Array)
	else:
		_last_error = "Elements field is not a Dictionary or Array."
		push_error(_last_error)
		return

	_loaded = true
	print("Elements loaded OK. Count =", _count_elements())


func _apply_default_settings() -> void:
	if not classification_settings.has("fallback_element"):
		classification_settings["fallback_element"] = "physical"
	if not classification_settings.has("confidence_threshold"):
		classification_settings["confidence_threshold"] = 0.15
	if not classification_settings.has("normalize_input"):
		classification_settings["normalize_input"] = true
	if not classification_settings.has("allow_manual_overrides"):
		classification_settings["allow_manual_overrides"] = true


func _normalize_elements_dict(d: Dictionary) -> Dictionary:
	# Input: { "fire": {...}, "water": {...} }
	# Output: same, but ensures each entry is Dictionary and has "id".
	var out: Dictionary = {}
	for k_any: Variant in d.keys():
		var id: String = String(k_any)
		var entry_any: Variant = d[k_any]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_any as Dictionary
		var normalized: Dictionary = _normalize_one_entry(entry, id)
		out[id] = normalized
	return out


func _normalize_elements_array(a: Array) -> Array:
	# Input: [ { "id": "fire", ... }, ... ]
	# Output: same entries normalized; entries missing id are skipped.
	var out: Array = []
	for entry_any: Variant in a:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if not entry.has("id"):
			continue
		var id: String = String(entry["id"])
		out.append(_normalize_one_entry(entry, id))
	return out


func _normalize_one_entry(entry: Dictionary, id: String) -> Dictionary:
	# Ensures required fields exist and types are sane.
	var e: Dictionary = entry.duplicate(true)
	e["id"] = id

	# Coerce arrays to PackedStringArray where applicable
	e["semantic_hints"] = _to_psa(e.get("semantic_hints", PackedStringArray()))
	e["forced_words"] = _to_psa(e.get("forced_words", PackedStringArray()))

	# Optional: allow older key name "keywords" and merge
	if e.has("keywords"):
		var kws: PackedStringArray = _to_psa(e.get("keywords"))
		var hints: PackedStringArray = e["semantic_hints"] as PackedStringArray
		for kw: String in kws:
			if not hints.has(kw):
				hints.append(kw)
		e["semantic_hints"] = hints

	# Weight default
	if not e.has("weight"):
		e["weight"] = 1.0
	else:
		e["weight"] = float(e["weight"])

	return e


func _to_psa(v: Variant) -> PackedStringArray:
	if typeof(v) == TYPE_PACKED_STRING_ARRAY:
		return v as PackedStringArray
	if typeof(v) == TYPE_ARRAY:
		var out := PackedStringArray()
		for x_any: Variant in (v as Array):
			out.append(String(x_any))
		return out
	return PackedStringArray()


func _count_elements() -> int:
	if typeof(elements) == TYPE_DICTIONARY:
		return (elements as Dictionary).size()
	if typeof(elements) == TYPE_ARRAY:
		return (elements as Array).size()
	return 0
