extends Control

const _TurnResolverScript = preload("res://scripts/combat/BackEnd/TurnResolver.gd")

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
var _encounter_modifier: EncounterModifier = null
var _turn_resolver = _TurnResolverScript.new()
var _active_status_effects_on_turn_start: Array = []
## When > 0, player must enter another word for the next strike (big modifier, etc.).
var _bonus_strikes_remaining: int = 0

@export var use_standalone_postbattle_rewards: bool = true

@onready var fade: ColorRect = $Fade

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_label: Label = $EnemyPanel/EnemyHP
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar
@onready var enemy_sprite: AnimatedSprite2D = $EnemyPanel/EnemySprite

@onready var player_name: Label = $PlayerPanel/PlayerName
@onready var player_hp_label: Label = $PlayerPanel/PlayerHP
@onready var player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var letters_label: Label = $PlayerPanel/LettersLabel
@onready var letter_limit_label: Label = $PlayerPanel/LetterLimit

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
	_encounter_modifier = EnemyModifierDB.get_modifier(modifier_id)
	if _encounter_modifier != null:
		enemy_max_hp = _encounter_modifier.apply_to_enemy(enemy_max_hp, enemy_stats, enemy_move)
		player_attacks_per_turn += int(_encounter_modifier.flat_modifiers.get("player_turns_gained", 0))
		enemy_attacks_per_turn += int(_encounter_modifier.flat_modifiers.get("enemy_turns_gained", 0))
		_active_status_effects_on_turn_start = _encounter_modifier.get_turn_start_effects()
	else:
		_active_status_effects_on_turn_start.clear()

	enemy_hp = enemy_max_hp
	blank_index = 0
	collected_words.clear()
	_bonus_strikes_remaining = 0

	enemy_sprite.stop()
	enemy_sprite.sprite_frames = null
	var sprite_path: String = str(cfg.get("sprite_frames_path", ""))
	if sprite_path != "":
		var frames := load(sprite_path) as SpriteFrames
		if frames != null:
			enemy_sprite.sprite_frames = frames
			var anim := str(cfg.get("sprite_animation_name", ""))
			if anim != "" and frames.has_animation(anim):
				enemy_sprite.play(anim)
		else:
			push_error("BattleV2: Failed to load SpriteFrames from '%s'" % sprite_path)

	victory_panel.visible = false
	submit_button.disabled = false
	word_input.editable = true

	line_preview.text = template_line
	letters_label.text = "Bonus letters: %s" % ", ".join(bonus_letters)
	word_input.max_length = PlayerState.letter_limit
	letter_limit_label.text = "Letter limit: %d" % PlayerState.letter_limit

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

	if _bonus_strikes_remaining > 0:
		await _submit_bonus_strike_word(word)
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
	if player_attacks_per_turn > 1:
		await _resolve_multi_strike_turn_first_word(word, freq_scaling)
		return

	var ctx := _build_turn_context(freq_scaling, _compute_letter_bonus_multiplier(word), word)
	var result: Dictionary = _turn_resolver.resolve_valid_turn(ctx)

	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	var damage_messages: Array = result["damage_messages"]
	for msg in damage_messages:
		result_label.text = msg
		await get_tree().create_timer(1.0).timeout

	if result["enemy_defeated"]:
		_finish_battle()
		return
	if result["player_defeated"]:
		result_label.text = "You were defeated."
		await get_tree().create_timer(0.75).timeout
		_start_battle()
		return

	result_label.text = "Accepted '%s'!" % word
	word_input.text = ""
	word_input.grab_focus()
	_update_prompt_ui()


## First word after madlib when player gets multiple strikes per round.
func _resolve_multi_strike_turn_first_word(word: String, freq_scaling: float) -> void:
	var ctx := _build_turn_context(freq_scaling, _compute_letter_bonus_multiplier(word), word)
	var result: Dictionary = _turn_resolver.resolve_single_player_attack(ctx)

	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	for msg in result["damage_messages"]:
		result_label.text = msg
		await get_tree().create_timer(1.0).timeout

	if result["enemy_defeated"]:
		_finish_battle()
		return

	_bonus_strikes_remaining = player_attacks_per_turn - 1
	if _bonus_strikes_remaining > 0:
		prompt_label.text = "Another strike! Enter a word!"
		result_label.text = "Bonus strike — use a new word!"
		word_input.text = ""
		word_input.grab_focus()
		return

	await _finish_player_round_after_strikes()


func _submit_bonus_strike_word(word: String) -> void:
	var expected_pos := "noun"
	if not _validate_pos_if_possible(word, expected_pos):
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := hint if hint != "" else ("That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos])
		await _apply_invalid_turn(msg)
		return

	var S: float = _get_word_freq_scaling(word)
	if use_element_system:
		var element_res := ElementClassifier.classify(word, expected_pos)
		print("---- Bonus strike element ---- ", word, " ", element_res.get("element", ""))

	var ctx := _build_turn_context(S, _compute_letter_bonus_multiplier(word), word)
	var result: Dictionary = _turn_resolver.resolve_single_player_attack(ctx)

	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	for msg in result["damage_messages"]:
		result_label.text = msg
		await get_tree().create_timer(1.0).timeout

	if result["enemy_defeated"]:
		_bonus_strikes_remaining = 0
		_finish_battle()
		return

	_bonus_strikes_remaining -= 1
	if _bonus_strikes_remaining > 0:
		prompt_label.text = "Another strike! Enter a word!"
		result_label.text = "Bonus strike — use a new word!"
		word_input.text = ""
		word_input.grab_focus()
		return

	await _finish_player_round_after_strikes()


func _finish_player_round_after_strikes() -> void:
	_bonus_strikes_remaining = 0
	var ctx := _build_turn_context(0.0, 1.0)
	var result: Dictionary = _turn_resolver.resolve_enemy_and_status(ctx)

	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	for msg in result["damage_messages"]:
		result_label.text = msg
		await get_tree().create_timer(1.0).timeout

	if result["enemy_defeated"]:
		_finish_battle()
		return
	if result["player_defeated"]:
		result_label.text = "You were defeated."
		await get_tree().create_timer(0.75).timeout
		_start_battle()
		return

	result_label.text = "Round complete!"
	word_input.text = ""
	word_input.grab_focus()
	_update_prompt_ui()


func _build_turn_context(freq_scaling: float, letter_bonus_mult: float, strike_word: String = "") -> Dictionary:
	var ctx := {
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"player_hp": PlayerState.current_hp,
		"player_stats": PlayerState.stats,
		"enemy_stats": enemy_stats,
		"enemy_move": enemy_move,
		"player_attacks_per_turn": player_attacks_per_turn,
		"enemy_attacks_per_turn": enemy_attacks_per_turn,
		"active_status_effects": _active_status_effects_on_turn_start,
		"freq_scaling": freq_scaling,
		"letter_bonus_mult": letter_bonus_mult,
		"rng": rng,
	}
	if strike_word != "":
		ctx["uses_bonus_letters"] = _word_uses_any_bonus_letter(strike_word)
	return ctx


## True if the word contains at least one bonus letter (or there are no bonus letters — strike always counts).
func _word_uses_any_bonus_letter(word: String) -> bool:
	if bonus_letters.is_empty():
		return true
	var w := word.to_upper()
	for letter in bonus_letters:
		if w.contains(letter):
			return true
	return false


func _apply_invalid_turn(message: String) -> void:
	_bonus_strikes_remaining = 0
	var ctx := _build_turn_context(0.0, 1.0)
	var result: Dictionary = _turn_resolver.resolve_invalid_turn(ctx)

	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	var damage_messages: Array = result["damage_messages"]
	if result["enemy_defeated"]:
		for msg in damage_messages:
			result_label.text = msg
			await get_tree().create_timer(1.0).timeout
		_finish_battle()
		return

	result_label.text = message
	await get_tree().create_timer(1.0).timeout
	for msg in damage_messages:
		result_label.text = msg
		await get_tree().create_timer(1.0).timeout

	word_input.text = ""
	word_input.grab_focus()

	if result["player_defeated"]:
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


func _format_letter_bonus_msg(mult: float) -> String:
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
