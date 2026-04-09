extends Control

@onready var title_label: Label = $ColorRect/CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var enemy_label: Label = $ColorRect/CenterContainer/Panel/MarginContainer/VBoxContainer/EnemyLabel
@onready var sentences_label: Label = $ColorRect/CenterContainer/Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/SentencesLabel
@onready var stats_label: Label = $ColorRect/CenterContainer/Panel/MarginContainer/VBoxContainer/StatsLabel
@onready var continue_button: Button = $ColorRect/CenterContainer/Panel/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	var recap := EncounterSceneTransition.consume_recap()
	
	var enemy_name: String = recap.get("enemy_name", "the enemy")
	title_label.text = "Victory!"
	enemy_label.text = "You defeated the %s!" %  enemy_name
	
	var sentences: Array = recap.get("completed_sentences", [])
	if sentences.is_empty():
		sentences_label.text = "(No story completed)"
	else:
		sentences_label.text = "\n\n".join(sentences)
	
	var hp: int = recap.get("player_hp_remaining", 0)
	var max_hp: int = recap.get("player_hp_max", 100)
	var longest: String = recap.get("longest_word", "")
	var total: int = recap.get("total_words", 0)
	var score : int = recap.get("battle_score", 0)
	
	var stats_parts: Array[String] = []
	stats_parts.append("HP remaining: %d / %d" % [hp, max_hp])
	stats_parts.append("Words used: %d" % total)
	stats_parts.append("Longest word: %s (%d letters)" % [longest, longest.length()])
	stats_parts.append("Battle score: %d" % score)
	
	stats_label.text = "\n".join(stats_parts)
	
	continue_button.pressed.connect(_on_continue_pressed)
	
func _on_continue_pressed() -> void:
	var items: Array = EncounterSceneTransition.consume_pending_reward_items()
	if items.size() > 0:
		EncounterSceneTransition.transition_to_postbattle(items)
	else:
		EncounterSceneTransition.return_to_scene()
