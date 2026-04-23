extends Control

const _EXPECTED_POS := "adjective"

## When running standalone, we store the chosen modifier and transition to battle on Continue.
var _last_modifier: EncounterModifier = null

@onready var modifier_prompt: Label = $ModifierPrompt
@onready var user_input: LineEdit = $UserInput
@onready var submit_button: Button = $Button
@onready var effect_description_label: Label = $EffectDescriptionLabel
@onready var continue_button: Button = $ContinueToBattle


func _ready() -> void:
	MouseModeStack.set_default_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	user_input.grab_focus()
	submit_button.pressed.connect(_on_submit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	user_input.text_submitted.connect(_on_text_submitted)
	continue_button.disabled = true
	_set_prompt_from_encounter()


func _set_prompt_from_encounter() -> void:
	var enc: Dictionary = EncounterSceneTransition.current_encounter
	var enemy_id: String = str(enc.get("encounter_id", ""))
	if enemy_id != "":
		modifier_prompt.text = "Describe the %s with an adjective." % enemy_id
	else:
		modifier_prompt.text = "Describe your foe with an adjective."


func _on_submit_pressed() -> void:
	_submit()


func _on_text_submitted(_new_text: String) -> void:
	_submit()


func _submit() -> void:
	var adj: String = user_input.text.strip_edges()
	if adj.is_empty():
		return

	if adj.contains(" ") or adj.contains("\t"):
		_reject_input("Please enter a single adjective (one word).")
		return

	if not _validate_pos_if_possible(adj, _EXPECTED_POS):
		var hint := _get_pos_hint_if_possible(adj, _EXPECTED_POS)
		var msg: String = hint if hint != "" else "That doesn't look like an adjective — try another word!"
		_reject_input(msg)
		return

	_last_modifier = EnemyModifierDB.classify_adjective(adj)
	effect_description_label.text = _last_modifier.get_description_for_ui()
	continue_button.disabled = false
	submit_button.visible = false
	user_input.editable = false


func _reject_input(message: String) -> void:
	_last_modifier = null
	continue_button.disabled = true
	effect_description_label.text = message
	submit_button.visible = true
	user_input.editable = true


func _validate_pos_if_possible(word: String, expected_pos: String) -> bool:
	if not _has_wordnet():
		return true
	if not WordNet.IsReady:
		return true
	return WordNet.ValidatePos(word, expected_pos)


func _get_pos_hint_if_possible(word: String, expected_pos: String) -> String:
	if not _has_wordnet():
		return ""
	if not WordNet.IsReady:
		return ""
	return WordNet.GetPosHint(word, expected_pos)


func _has_wordnet() -> bool:
	return get_tree() != null and get_tree().root.has_node("WordNet")


func _on_continue_pressed() -> void:
	if _last_modifier != null:
		EncounterSceneTransition.transition_to_battle(_last_modifier.id)
	else:
		EncounterSceneTransition.transition_to_battle(EnemyModifierDB.fallback_modifier_id)
