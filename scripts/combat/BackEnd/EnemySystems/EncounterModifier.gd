extends RefCounted
class_name EncounterModifier

## Wraps one encounter modifier (adjective → buff/debuff). Add or remove properties
## here as you extend Customizer.json; apply_to_enemy() centralizes stat application.

var id: String = ""
var display_name: String = ""
var definition: String = ""

var flat_modifiers: Dictionary = {}
var mult_modifiers: Dictionary = {}

var status_effects_on_turn_start: Array = []
var status_effects_on_hit: Array = []
var post_fight_modifiers: Array = []
var behavior_flags: Array = []

var element_override: String = ""
var difficulty: int = 0
var stackable: bool = false
var rarity_weight: int = 0

## Words that map to this modifier (e.g. "big", "cursed"). Used for adjective lookup.
var forced_words: PackedStringArray = PackedStringArray()
var semantic_hints: PackedStringArray = PackedStringArray()


static func from_dict(data: Dictionary) -> EncounterModifier:
	var m := EncounterModifier.new()
	m.id = str(data.get("id", ""))
	m.display_name = str(data.get("display_name", ""))
	m.definition = str(data.get("definition", ""))
	m.flat_modifiers = _to_str_key_dict(data.get("flat_modifiers", {}))
	m.mult_modifiers = _to_str_key_dict(data.get("mult_modifiers", {}))
	m.status_effects_on_turn_start = _to_array(data.get("status_effects_on_turn_start", []))
	m.status_effects_on_hit = _to_array(data.get("status_effects_on_hit", []))
	m.post_fight_modifiers = _to_array(data.get("post_fight_modifiers", []))
	m.behavior_flags = _to_array(data.get("behavior_flags", []))
	m.element_override = str(data.get("element_override", ""))
	m.difficulty = int(data.get("difficulty", 0))
	m.stackable = bool(data.get("stackable", false))
	m.rarity_weight = int(data.get("rarity_weight", 0))
	m.forced_words = _to_psa(data.get("forced_words", []))
	m.semantic_hints = _to_psa(data.get("semantic_hints", []))
	return m


static func _to_psa(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(v) == TYPE_PACKED_STRING_ARRAY:
		return v as PackedStringArray
	if typeof(v) == TYPE_ARRAY:
		for x in (v as Array):
			out.append(str(x))
	return out


static func _to_str_key_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in (v as Dictionary).keys():
		out[str(k)] = (v as Dictionary)[k]
	return out


static func _to_array(v: Variant) -> Array:
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	return []


## Apply this modifier to enemy config. Mutates enemy_max_hp and enemy_stats in place.
## Add handling for new modifier keys here (e.g. accuracy on enemy_move) as you extend.
func apply_to_enemy(enemy_max_hp_ref: int, enemy_stats_ref: Dictionary, enemy_move_ref: Dictionary) -> int:
	var new_max_hp: int = enemy_max_hp_ref

	for key in flat_modifiers.keys():
		var val = flat_modifiers[key]
		if key == "hp":
			new_max_hp += int(val)
		elif enemy_stats_ref.has(key):
			enemy_stats_ref[key] = float(enemy_stats_ref[key]) + float(val)
		else:
			enemy_stats_ref[key] = float(val)

	for key in mult_modifiers.keys():
		var val: float = float(mult_modifiers[key])
		if key == "hp":
			new_max_hp = int(float(new_max_hp) * val)
		elif key == "accuracy":
			if enemy_move_ref.has("accuracy"):
				enemy_move_ref["accuracy"] = clampf(float(enemy_move_ref["accuracy"]) * val, 0.0, 1.0)
			elif enemy_stats_ref.has("accuracy"):
				enemy_stats_ref["accuracy"] = clampf(float(enemy_stats_ref["accuracy"]) * val, 0.0, 1.0)
		elif enemy_stats_ref.has(key):
			enemy_stats_ref[key] = float(enemy_stats_ref[key]) * val
		else:
			enemy_stats_ref[key] = val

	return new_max_hp


func get_description_for_ui() -> String:
	if definition != "":
		return definition
	return display_name + " modifier applied."
