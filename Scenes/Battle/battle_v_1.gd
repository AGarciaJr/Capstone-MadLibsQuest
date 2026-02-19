# File: res://scenes/Battle/battle_v_1.gd
extends Control

# -----------------------------
# Config you can tweak per demo
# -----------------------------

# If true, the word must contain at least ONE of the required letters.
# If false, letter rule is disabled.
@export var enforce_letter_rule: bool = true

# If true, requires ALL letters to appear at least once (hard mode).
@export var require_all_letters: bool = false

# Total HP values
@export var enemy_max_hp: int = 30
@export var player_max_hp: int = 100

# Damage tuning
@export var damage_per_correct_word: int = 10
@export var damage_per_invalid_word: int = 5

# Letter set shown to player
var required_letters: PackedStringArray = ["A", "E", "S", "T"]

# The "madlib" template + blanks for this demo battle
var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"

# Each blank: { type: "noun"/"verb"/"adjective", hint: "...", display: "NOUN" }
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

# -----------------------------
# Node refs (match your .tscn)
# -----------------------------
@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_label: Label = $EnemyPanel/EnemyHP
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar

@onready var player_name: Label = $PlayerPanel/PlayerName
@onready var player_hp_label: Label = $PlayerPanel/PlayerHP
@onready var player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var letters_label: Label = $PlayerPanel/LettersLabel

@onready var story_text: Label = $StoryPanel/StoryText

@onready var prompt_label: Label = $BottomPanel/PromptLabel
@onready var line_preview: Label = $BottomPanel/LinePreview
@onready var word_input: LineEdit = $BottomPanel/WordInput
@onready var submit_button: Button = $BottomPanel/SubmitButton
@onready var result_label: Label = $BottomPanel/ResultLabel

@onready var victory_panel: Control = $VictoryPanel
@onready var victory_continue_button: Button = $VictoryPanel/ContinueButton

func _ready() -> void:
	# Wire signals in code so the scene works immediately.
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

	story_text.text = battle_title
	line_preview.text = template_line

	letters_label.text = "Letters: %s" % ", ".join(required_letters)

	_update_hp_ui()
	_update_prompt_ui()

	result_label.text = "Type a word and press Enter!"

	word_input.text = ""
	word_input.editable = true
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
		# All blanks filled; finish the battle
		_finish_battle()
		return

	var b: Dictionary = blanks[blank_index]
	var display: String = str(b.get("display", "WORD"))
	prompt_label.text = "The Bard needs a %s!" % display

	# Update preview line with filled words
	line_preview.text = _render_preview_line()

func _replace_first(haystack: String, needle: String, replacement: String) -> String:
	var i := haystack.find(needle)
	if i == -1:
		return haystack
	return haystack.substr(0, i) + replacement + haystack.substr(i + needle.length())

func _render_preview_line() -> String:
	var text := template_line
	for w in collected_words:
		text = _replace_first(text, "___", w)
	return text


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
	var pos_ok := _validate_pos_if_possible(word, expected_pos)
	if not pos_ok:
		# If WordNet can provide a hint, show it; otherwise generic.
		var hint := _get_pos_hint_if_possible(word, expected_pos)
		var msg := "That doesn't look like %s %s." % [_get_article(expected_pos), expected_pos]
		if hint != "":
			msg = hint
		_apply_invalid_input(msg)
		return

	# Accept word
	collected_words.append(word)
	blank_index += 1

	# Deal damage to enemy for correct word
	enemy_hp -= damage_per_correct_word
	_update_hp_ui()

	result_label.text = "Nice. '%s' accepted." % word

	word_input.text = ""
	word_input.grab_focus()

	# Next blank or win
	_update_prompt_ui()

func _apply_invalid_input(message: String) -> void:
	player_hp -= damage_per_invalid_word
	_update_hp_ui()

	result_label.text = message

	word_input.text = ""
	word_input.grab_focus()

	if player_hp <= 0:
		# Minimal "lose" behavior: reset battle
		result_label.text = "You were defeated. Restarting..."
		await get_tree().create_timer(0.75).timeout
		_start_battle()

func _finish_battle() -> void:
	# If enemy still alive, you can keep going, but for demo we treat blanks as the battle end condition.
	word_input.editable = false
	submit_button.disabled = true

	# If enemy HP > 0 (e.g., low damage_per_correct_word), force to 0 for demo victory
	if enemy_hp > 0:
		enemy_hp = 0
		_update_hp_ui()

	result_label.text = "The Bard weaves your words into legend!"

	victory_panel.visible = true

func _on_continue_pressed() -> void:
	# For demo: restart battle quickly
	submit_button.disabled = false
	word_input.editable = true
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
		# Any-of rule
		for letter in required_letters:
			if w.contains(letter):
				return true
		return false

func _validate_pos_if_possible(word: String, expected_pos: String) -> bool:
	# If WordNet autoload isn't present or not ready, fail open.
	if not _has_wordnet():
		return true
	if not WordNet.is_node_ready():
		print("Word Net Died")
		return true
	return WordNet.validate_pos(word, expected_pos)

func _get_pos_hint_if_possible(word: String, expected_pos: String) -> String:
	if not _has_wordnet():
		return ""
	if not WordNet.is_ready:
		return ""
	return WordNet.get_pos_hint(word, expected_pos)

func _has_wordnet() -> bool:
	# Autoload name must be "WordNet"
	# In GDScript, referencing a missing global can error; guard via Engine.has_singleton.
	# Godot's Engine singletons are different from Autoloads, so we do a safe try-catch-ish pattern:
	# We'll rely on `has_node` on SceneTree root.
	return get_tree() != null and get_tree().root.has_node("WordNet")

func _get_article(word: String) -> String:
	if word.length() == 0:
		return "a"
	var first := word.to_lower()[0]
	return "an" if first in ["a", "e", "i", "o", "u"] else "a"
