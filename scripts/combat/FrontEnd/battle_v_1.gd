extends Control


# Config

# TODO: move these into a json with the rest of the player and enemy data
@export var enemy_max_hp: int = 30
@export var player_max_hp: int = 100

# TODO: also move this to the player json
# Letter set shown to player (now used for BONUS, not rejection)
@export var bonus_letters: PackedStringArray = ["A", "E", "S", "T"]

# Bonus tuning
@export var letter_bonus_per_match: float = 0.05      # +5% dmg per matched featured letter
@export var letter_bonus_all_letters_extra: float = 0.15 # extra +15% if word contains ALL featured letters
@export var letter_bonus_cap: float = 0.50            # cap total bonus to +50%

# Demo madlib template + blanks
var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"

# TODO: move these to a json for clarity probably need a bunch of different word prompts per move used 
var blanks := [
	{"type": "noun", "hint": "a creature/thing", "display": "NOUN"},
	{"type": "verb", "hint": "an action", "display": "VERB"},
	{"type": "adjective", "hint": "a describing word", "display": "ADJECTIVE"},
]

# State
var enemy_hp: int
var player_hp: int
var blank_index: int = 0
var collected_words: Array[String] = []

# TODO: move combat stats from this dict to a json later
var player_stats := {"atk": 10, "crit_chance": 0.10, "crit_mult": 1.5, "def": 0, "armor": 0}
var enemy_stats := {"atk": 6, "crit_chance": 0.05, "crit_mult": 1.4, "def": 2, "armor": 10}

# Enemy move (still used on invalid input for now)
var enemy_move := {
	"base_damage": 4,
	"scaling": 0.4,
	"coefficient": 1.0,
	"accuracy": 1.0
}

var rng := RandomNumberGenerator.new()

@onready var fade: ColorRect = $Fade

# UI refs
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
# @onready var attack_button: Label = $BottomPanel/AttackButton
# @onready var buff_button: Label = $BottomPanel/BuffButton
# @onready var cancel_button: Label = $BottomPanel/CancelButton

@onready var victory_panel: Control = $VictoryPanel
@onready var victory_continue_button: Button = $VictoryPanel/ContinueButton


# Lifecycle
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	fade.color = Color( 0, 0, 0, 1)
	
	# Godot 4 auto-seeds globally at startup, but per-instance RNG randomize is
	rng.randomize()

	submit_button.pressed.connect(_on_submit_pressed)
	# TODO: make shii for all of the buttons that we need for basic combat
	# attack_button.pressed.connect(_on_attack_pressed)
	word_input.text_submitted.connect(_on_text_submitted)
	victory_continue_button.pressed.connect(_on_continue_pressed)

	_start_battle()
	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 0), 0.35)


# Battle flow
func _start_battle() -> void:
	var enc = EncounterSceneTransition.current_encounter
	var encounter_id: String = enc.get("encounter_id", "Goblin 2")
	
	match encounter_id:
		"Goblin 2":
			enemy_max_hp = 30
			enemy_name.text = "Goblin"
			template_line = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"
			blanks = [
				{"type": "noun", "hint": "a creature/thing", "display": "NOUN"},
				{"type": "verb", "hint": "an action", "display": "VERB"},
				{"type": "adjective", "hint": "a describing word", "display": "ADJECTIVE"},
			]
		"Goblin King":
			enemy_max_hp = 50
			enemy_name.text = "Goblin King"
			template_line = "The hero challenged the monstrous ___, tried to ___, and struck with ___ power!"
			blanks = [
				{"type": "noun", "hint": "a monster/title", "display": "NOUN"},
				{"type": "verb", "hint": "an action", "display": "VERB"},
				{"type": "adjective", "hint": "a powerful describing word", "display": "ADJECTIVE"},
			]
		_:
			enemy_max_hp = 30
			enemy_name.text = "Enemy"
	
	enemy_hp = enemy_max_hp
	player_hp = player_max_hp
	blank_index = 0
	collected_words.clear()

	# TODO: have the different animations for the goblin and change the idle animation 
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
	player_hp = clampi(player_hp, 0, player_max_hp)

	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	player_hp_label.text = "HP: %d/%d" % [player_hp, player_max_hp]

	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

func _update_prompt_ui() -> void:
	if blank_index >= blanks.size():
		_finish_battle()
		return

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

	# POS validation via WordNet autoload if available
	var expected_pos: String = str(blanks[blank_index].get("type", "noun"))
	if not _validate_pos_if_possible(word, expected_pos):
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := hint if hint != "" else ("That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos])
		_apply_invalid_input(msg)
		return

	# Accept word
	collected_words.append(word)
	blank_index += 1

	# Word complexity scaling (fails open if WordFreq autoload not present)
	var S: float = _get_word_freq_scaling(word)

	# Element classification (your existing system)
	var element_res := ElementClassifier.classify(word, expected_pos)

	# TODO: for debugging purposes only 
	print("---- Element Scores ----")
	print("Player Word Choice: ", word)
	for k in element_res["raw_scores"].keys():
		print(k, ":", element_res["raw_scores"][k])
	print("Chosen:", element_res["element"], " | Confidence:", element_res["confidence"])
	print("Word Freq Scaling: ", S)

	# Player attack with letter bonus
	var bonus_mult := _compute_letter_bonus_multiplier(word)
	var outcome := _player_attack(S, bonus_mult)

	enemy_hp = CombatEngine.apply_damage(enemy_hp, int(outcome.damage))
	_update_hp_ui()

	# End battle immediately if enemy or player dies
	if enemy_hp <= 0 || player_hp <=0:
		_finish_battle()
		return

	var bonus_msg := _format_letter_bonus_msg(word, bonus_mult)
	result_label.text = "Accepted '%s'%s  (%s)" % [word, bonus_msg, str(outcome.debug)]

	word_input.text = ""
	word_input.grab_focus()

	_update_prompt_ui()

func _player_attack(freq_scaling: float, letter_bonus_mult: float) -> Dictionary:
	# Base move (still TODO: move to json later)
	var move := {
		"base_damage": 5,
		"scaling": freq_scaling,
		"coefficient": 1.2 * letter_bonus_mult, # apply bonus as multiplicative coefficient
		"accuracy": 1.0
	}

	var outcome := CombatEngine.compute_attack(player_stats, enemy_stats, move, rng)
	print("PLAYER ATTACK -> ", outcome)
	return outcome

func _apply_invalid_input(message: String) -> void:
	# Still: enemy attacks on invalid input (you noted this is temporary)
	var outcome := CombatEngine.compute_attack(enemy_stats, player_stats, enemy_move, rng)
	player_hp = CombatEngine.apply_damage(player_hp, int(outcome.damage))
	_update_hp_ui()

	result_label.text = "%s  (%s)" % [message, str(outcome.debug)]

	word_input.text = ""
	word_input.grab_focus()

	if player_hp <= 0:
		result_label.text = "You were defeated. Restarting..."
		await get_tree().create_timer(0.75).timeout
		_start_battle()

func _finish_battle() -> void:
	word_input.editable = false
	submit_button.disabled = true

	# For demo: force victory if blanks are done
	if enemy_hp > 0:
		enemy_hp = 0
		_update_hp_ui()

	result_label.text = "The Bard weaves your words into legend!"
	victory_panel.visible = true

func _on_continue_pressed() -> void:
	var enc = EncounterSceneTransition.current_encounter
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


# Letter bonus
func _compute_letter_bonus_multiplier(word: String) -> float:
	if bonus_letters.is_empty():
		return 1.0

	var w := word.to_upper()

	# Count UNIQUE featured letters present
	var match_count := 0
	for letter in bonus_letters:
		if w.contains(letter):
			match_count += 1

	var bonus := float(match_count) * letter_bonus_per_match

	# Optional: extra bonus if ALL featured letters are present
	if match_count == bonus_letters.size():
		bonus += letter_bonus_all_letters_extra

	bonus = clampf(bonus, 0.0, letter_bonus_cap)  # type-safe clamp :contentReference[oaicite:5]{index=5}
	return 1.0 + bonus

#TODO: fix me this function can be combined with the regular letter bonus function
func _format_letter_bonus_msg(word: String, mult: float) -> String:
	var bonus := mult - 1.0
	if bonus <= 0.00001:
		return ""
	var pct := int(round(bonus * 100.0))
	return " (+%d%% letter bonus)" % pct


# POS / autoload guards
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
	# If WordFreq autoload isn't present, fail open to neutral scaling.
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
