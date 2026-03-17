extends Control

# Config (pulled mostly from BattleConfigFactory and PlayerState at runtime)
@export var use_element_system: bool = true
@export var player_attacks_per_turn: int = 1
@export var enemy_attacks_per_turn: int = 1

var enemy_max_hp: int = 30

var bonus_letters: PackedStringArray = []
var letter_bonus_per_match: float = 0.05
var letter_bonus_all_letters_extra: float = 0.15
var letter_bonus_cap: float = 0.50
var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
var blanks: Array = []

# State
var enemy_hp: int
var blank_index: int = 0
var collected_words: Array[String] = []

var enemy_stats := {"atk": 6, "crit_chance": 0.05, "crit_mult": 1.4, "def": 2, "armor": 10}

var enemy_move := {
	"base_damage": 4,
	"scaling": 0.4,
	"coefficient": 1.0,
	"accuracy": 1.0,
}

var rng := RandomNumberGenerator.new()
var pending_item_choices: Array[Dictionary] = []

@export var use_standalone_postbattle_rewards: bool = true

@onready var fade: ColorRect = $Fade

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_label: Label = $EnemyPanel/EnemyHP
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar
@onready var goblin_sprite: AnimatedSprite2D = $EnemyPanel/GoblinSprite

@onready var player_name: Label = $PlayerPanel/PlayerName
@onready var player_hp_label: Label = $PlayerPanel/PlayerHP
@onready var player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var letters_label: Label = $PlayerPanel/LettersLabel

@onready var prompt_label: Label = $BottomPanel/PromptLabel
@onready var line_preview: Label = $BottomPanel/LinePreview
@onready var word_input: LineEdit = $BottomPanel/WordInput
@onready var submit_button: Button = $BottomPanel/SubmitButton
@onready var result_label: Label = $BottomPanel/ResultLabel

@onready var victory_panel: Control = $VictoryPanel
@onready var victory_continue_button: Button = $VictoryPanel/ContinueButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	fade.color = Color(0, 0, 0, 1)
	rng.randomize()

	submit_button.pressed.connect(_on_submit_pressed)
	word_input.text_submitted.connect(_on_text_submitted)
	victory_continue_button.pressed.connect(_on_continue_pressed)

	_start_battle()
	var tween := create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 0), 0.35)


func _start_battle() -> void:
	var enc = EncounterSceneTransition.current_encounter
	var cfg := BattleConfigFactory.build(enc)

	enemy_max_hp = int(cfg.get("enemy_max_hp", enemy_max_hp))
	PlayerState.max_hp = int(cfg.get("player_max_hp", PlayerState.max_hp))
	if PlayerState.current_hp <= 0:
		PlayerState.current_hp = PlayerState.max_hp

	PlayerState.stats = cfg.get("player_stats", PlayerState.stats)
	enemy_stats = cfg.get("enemy_stats", enemy_stats)
	enemy_move = cfg.get("enemy_move", enemy_move)

	template_line = str(cfg.get("template_line", template_line))
	blanks = cfg.get("blanks", blanks)

	bonus_letters = cfg.get("bonus_letters", PlayerState.bonus_letters)
	PlayerState.bonus_letters = bonus_letters
	letter_bonus_per_match = float(cfg.get("letter_bonus_per_match", PlayerState.letter_bonus_per_match))
	letter_bonus_all_letters_extra = float(cfg.get("letter_bonus_all_letters_extra", PlayerState.letter_bonus_all_letters_extra))
	letter_bonus_cap = float(cfg.get("letter_bonus_cap", PlayerState.letter_bonus_cap))

	PlayerState.letter_bonus_per_match = letter_bonus_per_match
	PlayerState.letter_bonus_all_letters_extra = letter_bonus_all_letters_extra
	PlayerState.letter_bonus_cap = letter_bonus_cap

	use_element_system = bool(cfg.get("use_element_system", use_element_system))
	player_attacks_per_turn = int(cfg.get("player_attacks_per_turn", player_attacks_per_turn))
	enemy_attacks_per_turn = int(cfg.get("enemy_attacks_per_turn", enemy_attacks_per_turn))

	enemy_name.text = str(cfg.get("enemy_name", enemy_name.text))

	var modifier_id: String = EncounterSceneTransition.current_encounter_modifier_id
	var encounter_modifier: EncounterModifier = EnemyModifierDB.get_modifier(modifier_id)
	if encounter_modifier != null:
		enemy_max_hp = encounter_modifier.apply_to_enemy(enemy_max_hp, enemy_stats, enemy_move)

	enemy_hp = enemy_max_hp
	blank_index = 0
	collected_words.clear()

	goblin_sprite.play("Goblin 2")

	victory_panel.visible = false
	submit_button.disabled = false
	word_input.editable = true

	line_preview.text = template_line
	letters_label.text = "Letters (bonus): %s" % ", ".join(bonus_letters)

	_update_hp_ui()
	_update_prompt_ui()

	result_label.text = "Type a word and press Enter!"
	word_input.text = ""
	word_input.grab_focus()


func _update_hp_ui() -> void:
	enemy_hp = clampi(enemy_hp, 0, enemy_max_hp)
	PlayerState.current_hp = clampi(PlayerState.current_hp, 0, PlayerState.max_hp)

	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	player_hp_label.text = "HP: %d/%d" % [PlayerState.current_hp, PlayerState.max_hp]

	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp

	player_hp_bar.max_value = PlayerState.max_hp
	player_hp_bar.value = PlayerState.current_hp


func _update_prompt_ui() -> void:
	if blank_index >= blanks.size():
		blank_index = 0
		collected_words.clear()

	var b: Dictionary = blanks[blank_index]
	var display: String = str(b.get("display", "WORD"))
	prompt_label.text = "The Bard needs a %s!" % display
	line_preview.text = _render_preview_line()


func _render_preview_line() -> String:
	var text := template_line
	for w in collected_words:
		text = _replace_first(text, "___", w)
	return text


func _replace_first(haystack: String, needle: String, replacement: String) -> String:
	var i := haystack.find(needle)
	if i == -1:
		return haystack
	return haystack.substr(0, i) + replacement + haystack.substr(i + needle.length())


func _on_submit_pressed() -> void:
	_submit_word(word_input.text)


func _on_text_submitted(new_text: String) -> void:
	_submit_word(new_text)


func _submit_word(raw: String) -> void:
	if victory_panel.visible:
		return

	var word := raw.strip_edges()
	if word == "":
		return
	if blank_index >= blanks.size():
		return

	var expected_pos: String = str(blanks[blank_index].get("type", "noun"))
	if not _validate_pos_if_possible(word, expected_pos):
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := hint if hint != "" else ("That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos])
		await _apply_invalid_turn(msg)
		return

	collected_words.append(word)
	blank_index += 1

	var S: float = _get_word_freq_scaling(word)

	if use_element_system:
		var element_res := ElementClassifier.classify(word, expected_pos)
		print("---- Element Scores ----")
		print("Player Word Choice: ", word)
		for k in element_res["raw_scores"].keys():
			print(k, ":", element_res["raw_scores"][k])
		print("Chosen:", element_res["element"], " | Confidence:", element_res["confidence"])
		print("Word Freq Scaling: ", S)

	await _resolve_turn(word, S)


func _resolve_turn(word: String, freq_scaling: float) -> void:
	# Player attacks multiple times
	var bonus_mult := _compute_letter_bonus_multiplier(word)
	var player_debug := ""

	for i in player_attacks_per_turn:
		var outcome := _player_attack(freq_scaling, bonus_mult)
		enemy_hp = CombatEngine.apply_damage(enemy_hp, int(outcome.damage))
		_update_hp_ui()
		player_debug = str(outcome.debug)
		if enemy_hp <= 0:
			break

	if enemy_hp <= 0:
		var bonus_msg := _format_letter_bonus_msg(word, bonus_mult)
		result_label.text = "Accepted '%s'%s  (%s)" % [word, bonus_msg, player_debug]
		_finish_battle()
		return

	# Enemy attacks multiple times
	var enemy_debug := ""
	for j in enemy_attacks_per_turn:
		var outcome_enemy := CombatEngine.compute_attack(enemy_stats, PlayerState.stats, enemy_move, rng)
		PlayerState.apply_damage(int(outcome_enemy.damage))
		_update_hp_ui()
		enemy_debug = str(outcome_enemy.debug)
		if PlayerState.current_hp <= 0:
			break

	if PlayerState.current_hp <= 0:
		result_label.text = "You were defeated. (%s)" % enemy_debug
		await get_tree().create_timer(0.75).timeout
		_start_battle()
		return

	var bonus_msg2 := _format_letter_bonus_msg(word, bonus_mult)
	result_label.text = "Accepted '%s'%s  (Player: %s | Enemy: %s)" % [word, bonus_msg2, player_debug, enemy_debug]

	word_input.text = ""
	word_input.grab_focus()
	_update_prompt_ui()


func _player_attack(freq_scaling: float, letter_bonus_mult: float) -> Dictionary:
	var move := {
		"base_damage": 5,
		"scaling": freq_scaling,
		"coefficient": 1.2 * letter_bonus_mult,
		"accuracy": 1.0,
	}
	return CombatEngine.compute_attack(PlayerState.stats, enemy_stats, move, rng)


func _apply_invalid_turn(message: String) -> void:
	# Enemy still gets their attacks on invalid input.
	var enemy_debug := ""
	for i in enemy_attacks_per_turn:
		var outcome := CombatEngine.compute_attack(enemy_stats, PlayerState.stats, enemy_move, rng)
		PlayerState.apply_damage(int(outcome.damage))
		_update_hp_ui()
		enemy_debug = str(outcome.debug)
		if PlayerState.current_hp <= 0:
			break

	result_label.text = "%s  (Enemy: %s)" % [message, enemy_debug]

	word_input.text = ""
	word_input.grab_focus()

	if PlayerState.current_hp <= 0:
		result_label.text = "You were defeated. Restarting..."
		await get_tree().create_timer(0.75).timeout
		_start_battle()


func _finish_battle() -> void:
	word_input.editable = false
	submit_button.disabled = true

	var enc: Dictionary = EncounterSceneTransition.current_encounter
	var encounter_id: String = str(enc.get("encounter_id", ""))
	if encounter_id != "":
		Progress.clear_encounter(encounter_id)

	pending_item_choices = ItemSystem.get_random_choices(3)
	result_label.text = "The Bard weaves your words into legend!"
	victory_panel.visible = true
	victory_continue_button.visible = true


func _on_continue_pressed() -> void:
	# If we have rewards queued, go to the standalone post-battle item scene.
	if use_standalone_postbattle_rewards and pending_item_choices.size() > 0:
		EncounterSceneTransition.transition_to_postbattle(pending_item_choices)
		return
	_return_to_map()


func _return_to_map() -> void:
	var enc: Dictionary = EncounterSceneTransition.current_encounter
	var encounter_id: String = enc.get("encounter_id", "")
	if encounter_id != "":
		Progress.clear_encounter(encounter_id)

	word_input.editable = false
	submit_button.disabled = true
	victory_continue_button.disabled = true

	var tween := create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.35)
	await tween.finished

	EncounterSceneTransition.return_to_scene()


func _compute_letter_bonus_multiplier(word: String) -> float:
	if bonus_letters.is_empty():
		return 1.0

	var w := word.to_upper()
	var match_count := 0
	for letter in bonus_letters:
		if w.contains(letter):
			match_count += 1

	var bonus := float(match_count) * letter_bonus_per_match
	if match_count == bonus_letters.size():
		bonus += letter_bonus_all_letters_extra

	bonus = clampf(bonus, 0.0, letter_bonus_cap)
	return 1.0 + bonus


func _format_letter_bonus_msg(word: String, mult: float) -> String:
	var bonus := mult - 1.0
	if bonus <= 0.00001:
		return ""
	var pct := int(round(bonus * 100.0))
	return " (+%d%% letter bonus)" % pct


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


func _get_word_freq_scaling(word: String) -> float:
	if get_tree() == null:
		return 1.0
	if not get_tree().root.has_node("WordFreq"):
		return 1.0
	return WordFreq.get_scaling_S(word)


func _get_article(word: String) -> String:
	if word.length() == 0:
		return "a"
	var first := word.to_lower()[0]
	return "an" if first in ["a", "e", "i", "o", "u"] else "a"
