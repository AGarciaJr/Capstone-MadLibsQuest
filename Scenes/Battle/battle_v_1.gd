extends Control

@export var enforce_letter_rule: bool = true
@export var require_all_letters: bool = false

@export var enemy_max_hp: int = 30
@export var player_max_hp: int = 100

# Letter set shown to player
var required_letters: PackedStringArray = ["A", "E", "S", "T"]

# Demo madlib template + blanks
var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"

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

# Combat stats (for now, hardcoded demo dicts; later you can load from JSON)
var player_stats := {"atk": 10, "crit_chance": 0.10, "crit_mult": 1.5, "def": 0, "armor": 0}
var enemy_stats := {"atk": 6, "crit_chance": 0.05, "crit_mult": 1.4, "def": 2, "armor": 10}

# Moves (these replace your old fixed damage numbers)
# On correct word: player "attacks" enemy
var player_move := {
	"base_damage": 5,     
	"scaling": 0.8,       
	"coefficient": 1.2, 
	"accuracy": 1.0
}
# On invalid word: enemy "punishes" player
var enemy_move := {
	"base_damage": 4,
	"scaling": 0.6,
	"coefficient": 1.0,
	"accuracy": 1.0
}

var rng := RandomNumberGenerator.new()

const CombatEngine = preload("res://scripts/combat/combat_engine.gd")

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_label: Label = $EnemyPanel/EnemyHP
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar

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
	rng.randomize()

	submit_button.pressed.connect(_on_submit_pressed)
	word_input.text_submitted.connect(_on_text_submitted)
	victory_continue_button.pressed.connect(_on_continue_pressed)

	_start_battle()

func _start_battle() -> void:
	enemy_hp = enemy_max_hp
	player_hp = player_max_hp
	blank_index = 0
	collected_words.clear()

	victory_panel.visible = false
	submit_button.disabled = false
	word_input.editable = true

	line_preview.text = template_line
	letters_label.text = "Letters: %s" % ", ".join(required_letters)

	_update_hp_ui()
	_update_prompt_ui()

	result_label.text = "Type a word and press Enter!"
	word_input.text = ""
	word_input.grab_focus()

func _update_hp_ui() -> void:
	enemy_hp = clamp(enemy_hp, 0, enemy_max_hp)
	player_hp = clamp(player_hp, 0, player_max_hp)

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

	# Local validation: letters rule
	if enforce_letter_rule and not _passes_letter_rule(word):
		_apply_invalid_input("That word doesn't match the letter rule.")
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

	# Combat: player attacks enemy (MOVED OUT of scene math)
	var outcome := CombatEngine.compute_attack(player_stats, enemy_stats, player_move, rng)
	print("PLAYER ATTACK -> ", outcome)
	
	enemy_hp = CombatEngine.apply_damage(enemy_hp, int(outcome.damage))
	_update_hp_ui()

	result_label.text = "Accepted '%s'. %s" % [word, str(outcome.debug)]

	word_input.text = ""
	word_input.grab_focus()

	_update_prompt_ui()

func _apply_invalid_input(message: String) -> void:
	# Combat: enemy attacks player (MOVED OUT of scene math)
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
	_start_battle()

# -----------------------------
# Validation helpers
# -----------------------------

func _passes_letter_rule(word: String) -> bool:
	var w := word.to_upper()

	if require_all_letters:
		for letter in required_letters:
			if not w.contains(letter):
				return false
		return true
	else:
		for letter in required_letters:
			if w.contains(letter):
				return true
		return false

func _validate_pos_if_possible(word: String, expected_pos: String) -> bool:
	# If WordNet autoload isn't present or not initialized, fail open.
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
	# Autoload name must be "WordNet"
	return get_tree() != null and get_tree().root.has_node("WordNet")

func _get_article(word: String) -> String:
	if word.length() == 0:
		return "a"
	var first := word.to_lower()[0]
	return "an" if first in ["a", "e", "i", "o", "u"] else "a"
