extends Control

@export var enforce_letter_rule: bool = true
@export var require_all_letters: bool = false

# TODO: these need to be moved into a json with the rest of the player and enemy data
@export var enemy_max_hp: int = 30
@export var player_max_hp: int = 100

## Which tutorial enemy this battle is currently using.
## For now we support: "goblin", "skeleton", "bug".
@export var enemy_id: String = "goblin"

# Letter set shown to player
var required_letters: PackedStringArray = ["A", "E", "S", "T"]

# Per-enemy madlib templates + blanks (tutorial-focused)
var enemy_templates: Dictionary = {
	"goblin": {
		"title": "~ Greedy Roadside Robber ~",
		"template": "The hero met a {0} goblin guarding a pile of {1}, clutching a {2} and snarling about unpaid {3}.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the goblin's look or mood", "display": "ADJECTIVE"},
			{"type": "plural_noun", "hint": "Treasure the goblin might guard", "display": "PLURAL NOUN"},
			{"type": "noun", "hint": "Something the goblin might swing or hold", "display": "NOUN"},
			{"type": "plural_noun", "hint": "Things people owe: taxes? debts? favors?", "display": "PLURAL NOUN"}
		]
	},
	"skeleton": {
		"title": "~ Rattling Graveguard ~",
		"template": "A {0} wind blew as a {1} skeleton crawled from a cracked {2}, its {3} bones clacking in time with your {4} heartbeat.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the wind or weather", "display": "ADJECTIVE"},
			{"type": "adjective", "hint": "Describe the skeleton", "display": "ADJECTIVE"},
			{"type": "noun", "hint": "Something in a graveyard (tomb, coffin...)", "display": "NOUN"},
			{"type": "adjective", "hint": "How do the bones sound?", "display": "ADJECTIVE"},
			{"type": "noun", "hint": "What pounds in your chest?", "display": "NOUN"}
		]
	},
	"bug": {
		"title": "~ Chittering Swarm ~",
		"template": "Across the {0} forest floor, a {1} bug scuttled from a {2} log, soon followed by a buzzing {3} drawn to the scent of {4}.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the ground or path", "display": "ADJECTIVE"},
			{"type": "adjective", "hint": "Describe the first bug", "display": "ADJECTIVE"},
			{"type": "adjective", "hint": "Describe the old log or stump", "display": "ADJECTIVE"},
			{"type": "noun", "hint": "A word for a group: swarm? cloud?", "display": "NOUN"},
			{"type": "noun", "hint": "Something sweet or smelly that attracts bugs", "display": "NOUN"}
		]
	}
}

var battle_title: String = "~ The Bard's Tale ~"
var template_line: String = "The hero faced a fearsome ___, chose to ___, and won with ___ force!"

# The active blanks for the current enemy (copied from enemy_templates)
# Keep this untyped Array so we can assign JSON-like data without cast issues.
var blanks: Array = []

# Accumulated damage for the current completed sentence
var pending_sentence_damage: float = 0.0
var pending_sentence_debug: Array[String] = []

# State
var enemy_hp: int
var player_hp: int
var blank_index: int = 0
var collected_words: Array[String] = []

# TODO: move combat stats from this dict to a json later 
var player_stats := {"atk": 10, "crit_chance": 0.10, "crit_mult": 1.5, "def": 0, "armor": 0}
var enemy_stats := {"atk": 6, "crit_chance": 0.05, "crit_mult": 1.4, "def": 2, "armor": 10}

# On correct word: player "attacks" enemy
var player_move := {
	"base_damage": 5,     
	"scaling": 0.8,       
	"coefficient": 1.2, 
	"accuracy": 1.0
}

# TODO: this is temp please change me enemies should always attack regardless if the player is correct or not 
# On invalid word: enemy "punishes" player
var enemy_move := {
	"base_damage": 4,
	"scaling": 0.4,
	"coefficient": 1.0,
	"accuracy": 1.0
}

var rng := RandomNumberGenerator.new()

# Use different constant names than the global classes to avoid conflicts
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")
const ElementClassifierScript = preload("res://scripts/combat/element_classifier.gd")

# Track word chaining across turns
var last_word: String = ""
var last_pos: String = ""
var chain_count: int = 0

func _reset_chain() -> void:
	last_word = ""
	last_pos = ""
	chain_count = 0

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
	pending_sentence_damage = 0.0
	pending_sentence_debug.clear()
	goblin_sprite.play("Goblin 2")
	_reset_chain()

	# Configure template and blanks based on enemy_id
	if enemy_templates.has(enemy_id):
		var cfg: Dictionary = enemy_templates.get(enemy_id, {})
		battle_title = cfg.get("title", battle_title)
		template_line = cfg.get("template", template_line)
		blanks = cfg.get("blanks", [])
	else:
		# Fallback: keep defaults
		blanks = [
			{"type": "noun", "hint": "a creature/thing", "display": "NOUN"},
			{"type": "verb", "hint": "an action", "display": "VERB"},
			{"type": "adjective", "hint": "a describing word", "display": "ADJECTIVE"},
		]

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

# TODO: probably needs to be refined and changed later 
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
		# All blanks for this sentence are filled; damage will be applied
		# when the last word is submitted.
		return

	var b: Dictionary = blanks[blank_index]
	var display: String = str(b.get("display", "WORD"))
	prompt_label.text = "The Bard needs a %s!" % display
	line_preview.text = _render_preview_line()

func _render_preview_line() -> String:
	var text := template_line
	for i in range(collected_words.size()):
		var placeholder := "{" + str(i) + "}"
		text = text.replace(placeholder, collected_words[i])
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
	
	var S: float = WordFreq.get_scaling_S(word)
	var element_res := ElementClassifierScript.classify(word, expected_pos)

	print("---- Element Scores ----")
	print("Player Word Choice: ", word)
	for k in element_res["raw_scores"].keys():
		print(k, ":", element_res["raw_scores"][k])

	print("Chosen:", element_res["element"], " | Confidence:", element_res["confidence"])
	
	# Base move values
	var move := {
		"base_damage": 5,
		"scaling": S,
		"coefficient": 1.2,
		"accuracy": 1.0
	}

	# Apply word chaining bonus/debuff
	var chain_multiplier := _get_chain_multiplier(word, expected_pos)
	move["coefficient"] *= chain_multiplier

	# just to see the word complexity scaling in action
	print("Word Freq Scaling: ", S)
	var outcome := CombatEngineScript.compute_attack(player_stats, enemy_stats, move, rng)
	print("PLAYER ATTACK (stored) -> ", outcome)
	
	# Store this word's damage contribution for the current sentence
	pending_sentence_damage += outcome.damage
	pending_sentence_debug.append(str(outcome.debug))
	
	result_label.text = "Accepted '%s'. Your sentence grows in power..." % word

	word_input.text = ""
	word_input.grab_focus()
	
	if blank_index >= blanks.size():
		_apply_sentence_damage()
	else:
		_update_prompt_ui()


func _get_chain_multiplier(word: String, expected_pos: String) -> float:
	# Same exact word repeatedly = debuff
	if word.to_lower() == last_word.to_lower():
		chain_count += 1
		last_pos = expected_pos
		result_label.text = "You repeat yourself... the magic fizzles."
		return 0.5

	# Same type of word chained = bonus
	if expected_pos == last_pos and last_pos != "":
		chain_count += 1
		# Cap bonus so it does not explode
		var capped_chain: int = min(chain_count, 3)
		var bonus := 1.0 + float(capped_chain) * 0.15
		result_label.text = "Word chain! Staying with %s powers up your attack." % expected_pos
		last_word = word
		last_pos = expected_pos
		return bonus

	# New type breaks the chain but is neutral
	chain_count = 0
	last_word = word
	last_pos = expected_pos
	return 1.0


func _apply_sentence_damage() -> void:
	# Apply all stored damage from this completed sentence at once.
	var total_damage := int(round(pending_sentence_damage))
	
	# Ensure each enemy takes at least two sentences: cap per-sentence damage
	var max_sentence_damage := int(ceil(float(enemy_max_hp) / 2.0))
	if total_damage <= 0:
		total_damage = 1
	else:
		total_damage = clamp(total_damage, 1, max_sentence_damage)
	
	enemy_hp = CombatEngineScript.apply_damage(enemy_hp, total_damage)
	_update_hp_ui()
	
	var debug_summary := ", ".join(pending_sentence_debug)
	result_label.text = "Your completed sentence strikes for %d damage! (%s)" % [total_damage, debug_summary]
	
	# Reset sentence accumulators
	pending_sentence_damage = 0.0
	pending_sentence_debug.clear()
	collected_words.clear()
	blank_index = 0
	line_preview.text = template_line
	
	# Check for victory
	if enemy_hp <= 0:
		_finish_battle()
		return
	
	# Otherwise, start a fresh sentence
	_update_prompt_ui()

# TODO: probably needs to change to have the enemy always attack and this needs to be just a fall back
func _apply_invalid_input(message: String) -> void:
	# Combat: enemy attacks player (MOVED OUT of scene math)
	var outcome := CombatEngineScript.compute_attack(enemy_stats, player_stats, enemy_move, rng)
	player_hp = CombatEngineScript.apply_damage(player_hp, int(outcome.damage))
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
	result_label.text = "The Bard weaves your words into legend!"
	victory_panel.visible = true

func _on_continue_pressed() -> void:
	_start_battle()

# Validation helpers
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
