extends Control

## When running standalone, we store the chosen modifier and transition to battle on Continue.
var _last_modifier: EncounterModifier = null

@onready var modifier_prompt: Label = $ModifierPrompt
@onready var user_input: LineEdit = $UserInput
@onready var submit_button: Button = $Button
@onready var effect_description_label: Label = $EffectDescriptionLabel
@onready var continue_button: Button = $ContinueToBattle


func _ready() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	user_input.text_submitted.connect(_on_text_submitted)
	continue_button.disabled = true
	_set_prompt_from_encounter()


func _set_prompt_from_encounter() -> void:
	var enc: Dictionary = EncounterSceneTransition.current_encounter
	var enemy_id: String = str(enc.get("encounter_id", ""))
	if enemy_id != "":
		modifier_prompt.text = "Describe the %s with an adjective (e.g. big, small, cursed, plain)." % enemy_id
	else:
		modifier_prompt.text = "Describe your foe with an adjective (e.g. big, small, cursed, plain)."


func _on_submit_pressed() -> void:
	_submit()


func _on_text_submitted(_new_text: String) -> void:
	_submit()


func _submit() -> void:
	var adj: String = user_input.text.strip_edges()
	if adj.is_empty():
		return
	_last_modifier = EnemyModifierDB.classify_adjective(adj)
	effect_description_label.text = _last_modifier.get_description_for_ui()
	continue_button.disabled = false


func _on_continue_pressed() -> void:
	if _last_modifier != null:
		EncounterSceneTransition.transition_to_battle(_last_modifier.id)
	else:
		EncounterSceneTransition.transition_to_battle(EnemyModifierDB.fallback_modifier_id)
