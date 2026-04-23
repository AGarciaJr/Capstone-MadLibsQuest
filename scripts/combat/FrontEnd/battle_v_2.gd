extends Control

const _TurnResolverScript = preload("res://scripts/combat/BackEnd/TurnResolver.gd")

# Config (pulled mostly from BattleConfigFactory and PlayerState at runtime)
@export var use_element_system: bool = true
@export var player_attacks_per_turn: int = 1
@export var enemy_attacks_per_turn: int = 1

var enemy_max_hp: int = 30
var _death_screen = null
## Letter bonus tuning for this battle lives on PlayerState (set from encounter cfg in _start_battle).
var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
var blanks: Array = []

# State
var enemy_hp: int
var blank_index: int = 0
var collected_words: Array[String] = []
var templates: Array = []
var current_sentence_index: int = 0
var _sprite_idle_animation: String = ""
var _battle_log: Array[String] = []
var _completed_sentences: Array[String] = []
var _all_words_used: Array[String] = []
var _defeat_message: String = ""
var _total_damage_dealt: int = 0

## Filled from BattleConfigFactory / encounter each battle; mutated by encounter modifiers.
var enemy_stats: Dictionary = {}

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
## When > 0, player must enter another word for the next strike (only if player_attacks_per_turn > 1).
var _bonus_strikes_remaining: int = 0
## Part of speech for bonus strikes — same blank type as the word played before enemy phase.
var _strike_round_expected_pos: String = "noun"
var _strike_round_pos_display: String = "noun"

@export var use_standalone_postbattle_rewards: bool = true

## When false: no max word length (LineEdit unlimited) and LetterLimit label is hidden. Set in Inspector for testing.
@export var enforce_letter_limit: bool = false

## When true: player damage = Scrabble sum(word) × multiplier from player letters; no stats/armor/freq/elements. Enemy uses flat damage only.
@export var use_scrabble_test_damage: bool = false
@export var test_enemy_damage_per_strike: int = 5
## How long the full Scrabble breakdown stays on ResultLabel before the next step (seconds).
@export var scrabble_result_hold_seconds: float = 2.5
## Per damage tier: index 0 = light (≤5), 1 = medium (6–15), 2 = heavy (>15), same breakpoints as smoke VFX.
## If a tier slot is empty, falls back to the stream on the PlayerHitSound node.
@export var extra_player_hit_sounds: Array[AudioStream] = []
## Optional extra enemy hit clips (same pattern as player).
@export var extra_enemy_hit_sounds: Array[AudioStream] = []

@onready var fade: ColorRect = $Fade

@onready var enemy_name: Label = $EnemyPanel/VBoxContainer/EnemyName
@onready var enemy_hp_label: Label = $EnemyPanel/VBoxContainer/EnemyHP
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/VBoxContainer/EnemyHPBar
@onready var enemy_sprite: AnimatedSprite2D = $CenterContainer/EnemySprite
@onready var damage_effects: AnimatedSprite2D = $CenterContainer/DamageEffects

@onready var player_name: Label = $PlayerPanel/VBoxContainer/PlayerName
@onready var player_hp_label: Label = $PlayerPanel/VBoxContainer/PlayerHP
@onready var player_hp_bar: ProgressBar = $PlayerPanel/VBoxContainer/PlayerHPBar
@onready var letters_label: Label = $PlayerPanel/VBoxContainer/LettersLabel
@onready var letter_bonus_number_label: Label = $PlayerPanel/VBoxContainer/LetterBonusNumber
@onready var current_bonus_multiplier_label: Label = $PlayerPanel/VBoxContainer/CurrentBonusMultiplier

@onready var prompt_label: Label = $BottomPanel/TextBoxBg/VBoxContainer/PromptLabel
@onready var word_input: LineEdit = $BottomPanel/TextBoxBg/VBoxContainer/MarginContainer/HBoxContainer/WordInput
@onready var submit_button: Button = $BottomPanel/TextBoxBg/VBoxContainer/MarginContainer/HBoxContainer/SubmitButton
@onready var result_label: Label = $BottomPanel/TextBoxBg/VBoxContainer/ResultLabel

@onready var battle_log_button: Button = $BottomPanel/TextBoxBg/VBoxContainer/MarginContainer/HBoxContainer/BattleLogButton
@onready var battle_log_panel: Control = $BattleLogPanel
@onready var battle_log_content: Label = $BattleLogPanel/ScrollContainer/LogContent

@onready var player_hit_sound: AudioStreamPlayer = $PlayerPanel/PlayerHitSound
@onready var enemy_hit_sound: AudioStreamPlayer = $EnemyPanel/EnemyHitSound

@onready var line_preview_before: Label = $BottomPanel/TextBoxBg/VBoxContainer/LinePreviewContainer/LinePreviewBefore
@onready var line_preview_blank: Label = $BottomPanel/TextBoxBg/VBoxContainer/LinePreviewContainer/LinePreviewBlank
@onready var line_preview_after: Label = $BottomPanel/TextBoxBg/VBoxContainer/LinePreviewContainer/LinePreviewAfter

var _enemy_hit_sound_pool: Array[AudioStream] = []


func _ready() -> void:
	AudioPlayer.play_music_battle()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	fade.color = Color(0, 0, 0, 1)
	rng.randomize()
	submit_button.pressed.connect(_on_submit_pressed)
	word_input.text_submitted.connect(_on_text_submitted)
	word_input.text_changed.connect(_on_word_input_text_changed)
	battle_log_button.pressed.connect(func(): battle_log_panel.visible = true)
	player_name.text = PlayerState.player_name
	$BattleLogPanel/CloseButton.pressed.connect(func(): 
		battle_log_panel.visible = false
		_refocus_input()
	)
	
	if not PlayerState.player_letters_changed.is_connected(_update_letters_label):
		PlayerState.player_letters_changed.connect(_update_letters_label)
		
	if not PlayerState.letter_leveled_up.is_connected(_on_letter_leveled_up):
		PlayerState.letter_leveled_up.connect(_on_letter_leveled_up)
	
	_start_battle()
	_rebuild_hit_sound_pools()
	var tween := create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 0), 0.35)
	
	# Load death screen last
	var death_scene = load("res://Scenes/YouDiedScreen.tscn")
	_death_screen = death_scene.instantiate()
	get_tree().root.add_child(_death_screen)

func _refocus_input() -> void:
	word_input.release_focus()
	word_input.grab_focus()

func _exit_tree() -> void:
	if PlayerState.player_letters_changed.is_connected(_update_letters_label):
		PlayerState.player_letters_changed.disconnect(_update_letters_label)
	
	if not PlayerState.letter_leveled_up.is_connected(_on_letter_leveled_up):
		PlayerState.letter_leveled_up.disconnect(_on_letter_leveled_up)


func _update_letters_label(_letters: PackedStringArray = PackedStringArray()) -> void:
	if letters_label == null:
		return
	
	letters_label.text = "Player letters: %s" % PlayerState.format_player_letters_with_levels()
	_update_letter_bonus_number_label()
	_update_current_bonus_multiplier_label()


## Shows PlayerState.letter_bonus_per_match (same value used in damage). Hidden in Scrabble test mode.
func _update_letter_bonus_number_label() -> void:
	if letter_bonus_number_label == null:
		return
	if use_scrabble_test_damage:
		letter_bonus_number_label.visible = false
		return
	letter_bonus_number_label.visible = true
	var v := _format_letter_mult_for_label(PlayerState.letter_bonus_per_match)
	letter_bonus_number_label.text = "Letter bonus per match: %s" % v


func _on_word_input_text_changed(new_text: String) -> void:
	_refresh_current_bonus_multiplier_label(new_text)


func _update_current_bonus_multiplier_label() -> void:
	var w := word_input.text if word_input else ""
	_refresh_current_bonus_multiplier_label(w)


## Preview of `PlayerState.letter_bonus_multiplier_for_word` for the text in WordInput (before submit). Hidden in Scrabble test mode.
func _refresh_current_bonus_multiplier_label(word: String) -> void:
	if current_bonus_multiplier_label == null:
		return
	if use_scrabble_test_damage:
		current_bonus_multiplier_label.visible = false
		return
	current_bonus_multiplier_label.visible = true
	var mult := PlayerState.letter_bonus_multiplier_for_word(word)
	current_bonus_multiplier_label.text = "Current letter multiplier: %s" % _format_letter_mult_for_label(mult)
	var ratio := _player_letter_coverage_ratio(word)
	current_bonus_multiplier_label.add_theme_color_override("font_color", _letter_coverage_tier_color(ratio))


## Fraction of distinct `PlayerState.player_letters` that appear in `word` (same distinct count as letter bonus uses).
func _player_letter_coverage_ratio(word: String) -> float:
	var letters := PlayerState.player_letters
	if letters.is_empty():
		return 0.0
	var w := word.to_upper()
	var matched := 0
	for letter in letters:
		if w.contains(letter):
			matched += 1
	return float(matched) / float(letters.size())


## Green ≥25%, orange ≥50%, red ≥75%, blue at 100% coverage; below 25% uses default label color.
func _letter_coverage_tier_color(ratio: float) -> Color:
	if ratio >= 1.0:
		return Color(0.38, 0.62, 1.0)
	if ratio >= 0.75:
		return Color(0.95, 0.32, 0.32)
	if ratio >= 0.50:
		return Color(1.0, 0.58, 0.18)
	if ratio >= 0.25:
		return Color(0.28, 0.88, 0.42)
	return Color(1.0, 1.0, 1.0)


func _reset_current_bonus_multiplier_preview() -> void:
	_refresh_current_bonus_multiplier_label("")


func _format_letter_mult_for_label(mult: float) -> String:
	if is_equal_approx(mult, float(int(round(mult)))):
		return str(int(round(mult)))
	return "%.2f" % mult


## Shows TurnResolver damage lines on ResultLabel. Scrabble mode: all lines at once (multiline). Normal: one line per second.
func _present_damage_messages(damage_messages: Array) -> void:
	if damage_messages.is_empty():
		return
	var lines: PackedStringArray = PackedStringArray()
	for msg in damage_messages:
		var s := str(msg)
		if s.is_empty():
			continue
		_append_log(s)
		lines.append(s)
	if lines.is_empty():
		return
	if use_scrabble_test_damage:
		result_label.text = "\n".join(lines)
		await get_tree().create_timer(maxf(0.1, scrabble_result_hold_seconds)).timeout
	else:
		for s in lines:
			result_label.text = s
			await get_tree().create_timer(1.0).timeout


func _apply_letter_limit_ui() -> void:
	if enforce_letter_limit:
		word_input.max_length = PlayerState.letter_limit
		if letter_limit_label:
			letter_limit_label.visible = true
			letter_limit_label.text = "Letter limit: %d" % PlayerState.letter_limit
	else:
		# Godot: max_length 0 = no limit on LineEdit
		word_input.max_length = 0
		if letter_limit_label:
			letter_limit_label.visible = false


func _start_battle() -> void:
	var enc = EncounterSceneTransition.current_encounter
	var cfg := BattleConfigFactory.build(enc)

	enemy_max_hp = int(cfg.get("enemy_max_hp", enemy_max_hp))
	PlayerState.max_hp = int(cfg.get("player_max_hp", PlayerState.max_hp))
	if PlayerState.current_hp <= 0:
		PlayerState.current_hp = PlayerState.max_hp

	enemy_stats = cfg["enemy_stats"]
	enemy_move = cfg.get("enemy_move", enemy_move)

	templates = cfg.get("templates", [])
	current_sentence_index = 0
	template_line = str(cfg.get("template_line", template_line))
	blanks = cfg.get("blanks", blanks)
	_defeat_message = cfg.get("defeat_message", "You were defeated!")

	if cfg.has("player_letters"):
		PlayerState.set_player_letters(cfg["player_letters"])
	elif cfg.has("bonus_letters"):
		PlayerState.set_player_letters(cfg["bonus_letters"])
	if enc.has("letter_bonus_per_match"):
		PlayerState.letter_bonus_per_match = float(enc["letter_bonus_per_match"])
	if enc.has("letter_bonus_all_letters_extra"):
		PlayerState.letter_bonus_all_letters_extra = float(enc["letter_bonus_all_letters_extra"])
	if enc.has("letter_bonus_cap"):
		PlayerState.letter_bonus_cap = float(enc["letter_bonus_cap"])

	use_element_system = bool(cfg.get("use_element_system", use_element_system))
	player_attacks_per_turn = int(cfg.get("player_attacks_per_turn", player_attacks_per_turn))
	enemy_attacks_per_turn = int(cfg.get("enemy_attacks_per_turn", enemy_attacks_per_turn))

	enemy_name.text = str(cfg.get("enemy_name", enemy_name.text))

	var modifier_id: String = EncounterSceneTransition.current_encounter_modifier_id
	_encounter_modifier = EnemyModifierDB.get_modifier(modifier_id)
	if _encounter_modifier != null:
		enemy_max_hp = _encounter_modifier.apply_to_enemy(enemy_max_hp, enemy_stats, enemy_move)
		_active_status_effects_on_turn_start = _encounter_modifier.get_turn_start_effects()
	else:
		_active_status_effects_on_turn_start.clear()

	enemy_hp = enemy_max_hp
	blank_index = 0
	collected_words.clear()
	_bonus_strikes_remaining = 0
	_strike_round_expected_pos = "noun"
	_strike_round_pos_display = "NOUN"

	_battle_log.clear()
	battle_log_content.text = ""
	battle_log_panel.visible = false
	
	_all_words_used.clear()
	
	_total_damage_dealt = 0

	_sprite_idle_animation = str(cfg.get("sprite_animation_name", ""))
	enemy_sprite.stop()
	enemy_sprite.sprite_frames = null
	var sprite_path: String = str(cfg.get("sprite_frames_path", ""))
	if sprite_path != "":
		var frames := load(sprite_path) as SpriteFrames
		if frames != null:
			enemy_sprite.sprite_frames = frames
			if _sprite_idle_animation != "" and frames.has_animation(_sprite_idle_animation):
				enemy_sprite.play(_sprite_idle_animation)
		else:
			push_error("BattleV2: Failed to load SpriteFrames from '%s'" % sprite_path)

	if not enemy_sprite.animation_finished.is_connected(_on_enemy_animation_finished):
		enemy_sprite.animation_finished.connect(_on_enemy_animation_finished)

	if not damage_effects.animation_finished.is_connected(_on_damage_effects_animation_finished):
		damage_effects.animation_finished.connect(_on_damage_effects_animation_finished)

	submit_button.disabled = false
	word_input.editable = true

	_update_line_preview()
	_update_letters_label()
	_apply_letter_limit_ui()

	_update_hp_ui()
	_update_prompt_ui()

	damage_effects.visible = false
	damage_effects.stop()

	if Run.run_mode == RunManager.RunMode.TUTORIAL:
		result_label.text = "Use words containing your letters to deal damage!"
	else:
		result_label.text = "Type a word and press Enter!"
	word_input.text = ""
	_reset_current_bonus_multiplier_preview()
	_refocus_input()
	_update_letter_bonus_number_label()


func _update_hp_ui() -> void:
	enemy_hp = clampi(enemy_hp, 0, enemy_max_hp)
	PlayerState.current_hp = clampi(PlayerState.current_hp, 0, PlayerState.max_hp)

	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	player_hp_label.text = "HP: %d/%d" % [PlayerState.current_hp, PlayerState.max_hp]

	enemy_hp_bar.max_value = enemy_max_hp
	player_hp_bar.max_value = PlayerState.max_hp

	# Smooth sliding animation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy_hp_bar, "value", enemy_hp, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_hp_bar, "value", PlayerState.current_hp, 0.4).set_ease(Tween.EASE_OUT)

	# Update colors
	_update_hp_bar_color(enemy_hp_bar, enemy_hp, enemy_max_hp)
	_update_hp_bar_color(player_hp_bar, PlayerState.current_hp, PlayerState.max_hp)

func _update_hp_bar_color(bar: ProgressBar, current: int, maximum: int) -> void:
	var percent := float(current) / float(maximum)
	var color: Color
	if percent > 0.5:
		color = Color(0.2, 0.8, 0.2)  # green
	elif percent > 0.1:
		color = Color(0.9, 0.8, 0.1)  # yellow
	else:
		color = Color(0.9, 0.1, 0.1)  # red
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)
	
func _update_prompt_ui() -> void:
	if blank_index >= blanks.size():
		_advance_sentence()
		return

	var b: Dictionary = blanks[blank_index]
	var display: String = str(b.get("display", "WORD"))
	var hint: String = str(b.get("hint", "")).strip_edges()
	if hint != "":
		prompt_label.text = "The Bard needs a %s — %s." % [display, hint]
	else:
		prompt_label.text = "The Bard needs a %s!" % display
	_update_line_preview()


func _advance_sentence() -> void:
	# Show completed sentence before moving on
	var completed := _render_preview_line()
	line_preview_before.text = completed
	line_preview_before.visible = true
	line_preview_blank.visible = false
	line_preview_after.visible = false
	
	word_input.editable = false
	await get_tree().create_timer(2.0).timeout
	word_input.editable = true
	
	_completed_sentences.append(completed)
	
	current_sentence_index += 1
	if current_sentence_index >= templates.size():
		# All sentences exhausted — loop back to the first
		current_sentence_index = 0

	var t: Dictionary = templates[current_sentence_index]
	template_line = t.get("line", template_line)
	blanks        = t.get("blanks", blanks)
	blank_index   = 0
	_all_words_used.append_array(collected_words)
	collected_words.clear()

	_update_line_preview()
	word_input.text   = ""
	_reset_current_bonus_multiplier_preview()
	_refocus_input()
	_update_prompt_ui()


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
	var word := raw.strip_edges()
	if word == "":
		return

	if _bonus_strikes_remaining > 0:
		await _submit_bonus_strike_word(word)
		return

	if blank_index >= blanks.size():
		return

	var blank_entry: Dictionary = blanks[blank_index]
	var expected_pos: String = str(blank_entry.get("type", "noun"))
	if not _validate_pos_if_possible(word, expected_pos):
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := hint if hint != "" else ("That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos])
		await _apply_invalid_turn(msg)
		return
		
	_add_xp_for_word(word)

	collected_words.append(word)
	_strike_round_expected_pos = expected_pos
	_strike_round_pos_display = str(blank_entry.get("display", expected_pos.to_upper()))
	blank_index += 1

	var S: float = _get_word_freq_scaling(word)

	if use_element_system and not use_scrabble_test_damage:
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

	var letter_mult := PlayerState.letter_bonus_multiplier_for_word(word)
	var ctx_attack := _build_turn_context(freq_scaling, letter_mult, word)
	var result: Dictionary = _turn_resolver.resolve_single_player_attack(ctx_attack)
	
	var hp_before_attack := enemy_hp
	enemy_hp = int(result["enemy_hp"])
	var player_damage_dealt: int = maxi(0, hp_before_attack - enemy_hp)
	_total_damage_dealt += player_damage_dealt
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()
	_play_enemy_hit_smoke(player_damage_dealt)

	await _present_damage_messages(result["damage_messages"])

	if result["enemy_defeated"]:
		_finish_battle()
		return

	var sentence_just_completed := blank_index >= blanks.size()
	if not sentence_just_completed:
		result_label.text = "Accepted '%s'!" % word
		word_input.text = ""
		_reset_current_bonus_multiplier_preview()
		_refocus_input()
		_update_prompt_ui()
		return

	var ctx_enemy := _build_turn_context(0.0, 1.0)
	var result2: Dictionary = _turn_resolver.resolve_enemy_and_status(ctx_enemy)

	var hp_before := PlayerState.current_hp
	enemy_hp = int(result2["enemy_hp"])
	PlayerState.current_hp = int(result2["player_hp"])
	_update_hp_ui()

	if PlayerState.current_hp < hp_before:
		_play_enemy_attack()

	await _present_damage_messages(result2["damage_messages"])

	if result2["enemy_defeated"]:
		_finish_battle()
		return

	if result2["player_defeated"]:
		await _handle_player_defeat()
		return

	result_label.text = "Accepted '%s'!" % word
	word_input.text = ""
	_reset_current_bonus_multiplier_preview()
	_refocus_input()
	_update_prompt_ui()


## First word after madlib when player gets multiple strikes per round.
func _resolve_multi_strike_turn_first_word(word: String, freq_scaling: float) -> void:
	var ctx := _build_turn_context(freq_scaling, PlayerState.letter_bonus_multiplier_for_word(word), word)
	var result: Dictionary = _turn_resolver.resolve_single_player_attack(ctx)

	var hp_before_attack := enemy_hp
	enemy_hp = int(result["enemy_hp"])
	var player_damage_dealt: int = maxi(0, hp_before_attack - enemy_hp)
	_total_damage_dealt += player_damage_dealt
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()
	_play_enemy_hit_smoke(player_damage_dealt)

	await _present_damage_messages(result["damage_messages"])

	if result["enemy_defeated"]:
		_finish_battle()
		return

	_bonus_strikes_remaining = player_attacks_per_turn - 1
	if _bonus_strikes_remaining > 0:
		prompt_label.text = "Bonus strike — another %s!" % _strike_round_pos_display
		result_label.text = "Enter a %s (same part of speech as before the enemy acts)." % _strike_round_pos_display
		word_input.text = ""
		_reset_current_bonus_multiplier_preview()
		_refocus_input()
		return

	await _finish_player_round_after_strikes()


func _submit_bonus_strike_word(word: String) -> void:
	var expected_pos := _strike_round_expected_pos
	if not _validate_pos_if_possible(word, expected_pos):
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := hint if hint != "" else ("That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos])
		await _apply_invalid_turn(msg)
		return
		
	_add_xp_for_word(word)

	var S: float = _get_word_freq_scaling(word)
	if use_element_system and not use_scrabble_test_damage:
		var element_res := ElementClassifier.classify(word, expected_pos)
		print("---- Bonus strike element ---- ", word, " ", element_res.get("element", ""))

	var ctx := _build_turn_context(S, PlayerState.letter_bonus_multiplier_for_word(word), word)
	var result: Dictionary = _turn_resolver.resolve_single_player_attack(ctx)

	var hp_before_attack := enemy_hp
	enemy_hp = int(result["enemy_hp"])
	var player_damage_dealt: int = maxi(0, hp_before_attack - enemy_hp)
	_total_damage_dealt += player_damage_dealt
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()
	_play_enemy_hit_smoke(player_damage_dealt)

	await _present_damage_messages(result["damage_messages"])

	if result["enemy_defeated"]:
		_bonus_strikes_remaining = 0
		_finish_battle()
		return

	_bonus_strikes_remaining -= 1
	if _bonus_strikes_remaining > 0:
		prompt_label.text = "Bonus strike — another %s!" % _strike_round_pos_display
		result_label.text = "Enter a %s (same part of speech as before the enemy acts)." % _strike_round_pos_display
		word_input.text = ""
		_reset_current_bonus_multiplier_preview()
		_refocus_input()
		return

	await _finish_player_round_after_strikes()


func _finish_player_round_after_strikes() -> void:
	_bonus_strikes_remaining = 0
	var ctx := _build_turn_context(0.0, 1.0)
	var result: Dictionary = _turn_resolver.resolve_enemy_and_status(ctx)

	var hp_before := PlayerState.current_hp
	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	if PlayerState.current_hp < hp_before:
		_play_enemy_attack()

	await _present_damage_messages(result["damage_messages"])

	if result["enemy_defeated"]:
		_finish_battle()
		return
	if result["player_defeated"]:
		await _handle_player_defeat()
		return

	result_label.text = "Round complete!"
	word_input.text = ""
	_reset_current_bonus_multiplier_preview()
	_refocus_input()
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
		"use_scrabble_test_damage": use_scrabble_test_damage,
		"player_letters": PlayerState.player_letters,
		"test_enemy_damage_per_strike": test_enemy_damage_per_strike,
	}
	if strike_word != "":
		ctx["strike_word"] = strike_word
		ctx["uses_player_letters"] = _word_uses_any_player_letter(strike_word)
	return ctx


## True if the word contains at least one player letter (or there are none — strike always counts).
func _word_uses_any_player_letter(word: String) -> bool:
	if PlayerState.player_letters.is_empty():
		return true
	var w := word.to_upper()
	for letter in PlayerState.player_letters:
		if w.contains(letter):
			return true
	return false


func _apply_invalid_turn(message: String) -> void:
	_bonus_strikes_remaining = 0
	var ctx := _build_turn_context(0.0, 1.0)
	var result: Dictionary = _turn_resolver.resolve_invalid_turn(ctx)

	var hp_before := PlayerState.current_hp
	enemy_hp = int(result["enemy_hp"])
	PlayerState.current_hp = int(result["player_hp"])
	_update_hp_ui()

	if PlayerState.current_hp < hp_before:
		_play_enemy_attack()

	var damage_messages: Array = result["damage_messages"]
	if result["enemy_defeated"]:
		await _present_damage_messages(damage_messages)
		_finish_battle()
		return

	_append_log(message)
	result_label.text = message
	await get_tree().create_timer(1.0).timeout
	await _present_damage_messages(damage_messages)

	word_input.text = ""
	_reset_current_bonus_multiplier_preview()
	_refocus_input()

	if result["player_defeated"]:
		await _handle_player_defeat()
		return


func _finish_battle() -> void:
	word_input.editable = false
	submit_button.disabled = true
	
	# save current sentence if some blanks were filled
	if collected_words.size() > 0:
		_completed_sentences.append(_render_preview_line())
	
	var enc: Dictionary = EncounterSceneTransition.current_encounter
	var encounter_id: String = str(enc.get("encounter_id", ""))
	if encounter_id != "":
		Progress.clear_encounter(encounter_id)
	
	# record player stats and score
	_all_words_used.append_array(collected_words)
	var longest_word := ""
	for w in _all_words_used:
		if w.length() > longest_word.length():
			longest_word = w
	
	var battle_score: int = (
		_total_damage_dealt + (_all_words_used.size() * 10) 
		+ (longest_word.length() * 15) + (PlayerState.current_hp * 2)
		+ (_completed_sentences.size() * 5)
	)
	
	PlayerState.current_run_score += battle_score
	
	var recap := {
		"enemy_name": enemy_name.text,
		"completed_sentences": _completed_sentences.duplicate(),
		"player_hp_remaining": PlayerState.current_hp,
		"player_hp_max": PlayerState.max_hp,
		"longest_word": longest_word,
		"total_words": _all_words_used.size(),
		"battle_score": battle_score,
	}

	var items = ItemSystem.get_random_choices(3)
	
	var tween := create_tween()
	tween.tween_property(fade, "color", Color(0,0,0,1), 0.35)
	await tween.finished
	
	EncounterSceneTransition.transition_to_recap(recap, items)

func _play_enemy_hit_smoke(damage: int) -> void:
	if damage <= 0:
		return
	var anim_name: String
	if damage > 15:
		anim_name = "Smoke 2"
	elif damage > 5:
		anim_name = "Smoke 1"
	else:
		anim_name = "Smoke 3"
	var frames := damage_effects.sprite_frames
	if frames == null or not frames.has_animation(anim_name):
		return
	damage_effects.visible = true
	damage_effects.play(anim_name)
	_play_player_hit_sfx_for_damage(damage)


func _player_hit_tier_index(damage: int) -> int:
	if damage > 15:
		return 2
	if damage > 5:
		return 1
	return 0


func _rebuild_hit_sound_pools() -> void:
	_enemy_hit_sound_pool.clear()
	if enemy_hit_sound.stream != null:
		_enemy_hit_sound_pool.append(enemy_hit_sound.stream)
	for s in extra_enemy_hit_sounds:
		if s != null:
			_enemy_hit_sound_pool.append(s)


func _play_player_hit_sfx_for_damage(damage: int) -> void:
	var tier: int = _player_hit_tier_index(damage)
	var stream: AudioStream = null
	if tier < extra_player_hit_sounds.size():
		stream = extra_player_hit_sounds[tier]
	if stream == null:
		stream = player_hit_sound.stream
	if stream == null:
		return
	player_hit_sound.stream = stream
	player_hit_sound.play()


func _play_enemy_hit_sfx() -> void:
	if _enemy_hit_sound_pool.is_empty():
		return
	enemy_hit_sound.stream = _enemy_hit_sound_pool[rng.randi_range(0, _enemy_hit_sound_pool.size() - 1)]
	enemy_hit_sound.play()


func _on_damage_effects_animation_finished() -> void:
	damage_effects.visible = false
	damage_effects.stop()


func _play_enemy_attack() -> void:
	_play_enemy_hit_sfx()
	var frames := enemy_sprite.sprite_frames
	if frames != null and frames.has_animation("Attack"):
		enemy_sprite.play("Attack")


func _on_enemy_animation_finished() -> void:
	if enemy_sprite.animation == "Attack":
		var frames := enemy_sprite.sprite_frames
		if frames != null and _sprite_idle_animation != "" \
				and frames.has_animation(_sprite_idle_animation):
			enemy_sprite.play(_sprite_idle_animation)


func _append_log(msg: String) -> void:
	_battle_log.append(msg)
	battle_log_content.text = "\n".join(_battle_log)


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
	
func _handle_player_defeat() -> void:
	word_input.editable = false
	submit_button.disabled = true
	SaveManager.delete_save()
	$DefeatPanel/DefeatMessage.text = _defeat_message
	$DefeatPanel.visible = true
	await get_tree().create_timer(2.5).timeout
	$DefeatPanel.visible = false
	if _death_screen:
		_death_screen.show_death_screen()
		
func _update_line_preview() -> void:
	var rendered := template_line
	for w in collected_words:
		rendered = _replace_first(rendered, "___", w)
		
	var blank_pos := rendered.find("___")
	if blank_pos == -1:
		line_preview_before.text = rendered
		line_preview_before.visible = true
		line_preview_blank.visible = false
		line_preview_after.visible = false
		return

	var before := rendered.substr(0, blank_pos)
	var after := rendered.substr(blank_pos + 3)

	line_preview_before.visible = not before.is_empty()
	line_preview_before.text = before

	line_preview_blank.visible = true
	var display : String = blanks[blank_index].get("display", "___") if blank_index < blanks.size() else "___"
	line_preview_blank.text = "[ %s ]" % display

	line_preview_after.visible = not after.is_empty()
	line_preview_after.text = after

func _add_xp_for_word(word: String) -> void:
	if PlayerState.player_letters.is_empty():
		return
	
	var counts := {}
	var upper := word.to_upper()
	for ch in upper:
		counts[ch] = counts.get(ch, 0) + 1
	
	for letter in PlayerState.player_letters:
		if counts.has(letter):
			PlayerState.add_letter_xp(letter, counts[letter])

func _on_letter_leveled_up(letter: String, new_level: int) -> void:
	var msg := "Letter %s reached level %d!" % [letter, new_level]
	_append_log(msg)
	result_label.text = msg
	_update_letters_label()
