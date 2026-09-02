extends Control
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, then retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, and EnemyFactory child nodes and keeps only
## the flow and the screen updates here.

enum State {
	PLAYER_INPUT,
	RESOLVING,
	ENEMY_TURN,
	WON,
	LOST,
}

const LETTER_TILE_SCENE: PackedScene = \
		preload("res://scenes/combat/letter_tile.tscn")

# Pause before and after the enemy's retaliation, in seconds.
const ENEMY_TURN_DELAY: float = 0.7

var _state: State = State.PLAYER_INPUT

@onready var deck_manager: DeckManager = $Systems/DeckManager
@onready var validator: WordValidator = $Systems/WordValidator
@onready var calculator: DamageCalculator = \
		$Systems/DamageCalculator
@onready var factory: EnemyFactory = $Systems/EnemyFactory
@onready var enemy: Enemy = $Layout/EnemyArea/Enemy
@onready var hand_box: HBoxContainer = \
		$Layout/HandArea/HandBox
@onready var word_input: LineEdit = \
		$Layout/InputArea/InputRow/WordInput
@onready var submit_button: Button = \
		$Layout/InputArea/InputRow/SubmitButton
@onready var feedback_label: Label = \
		$Layout/InputArea/FeedbackLabel
@onready var log_label: RichTextLabel = \
		$Layout/SidePanel/LogLabel
@onready var player_health_bar: ProgressBar = \
		$Layout/StatusArea/PlayerHealthBar
@onready var player_health_label: Label = \
		$Layout/StatusArea/PlayerHealthBar/PlayerHealthLabel
@onready var gold_label: Label = $Layout/StatusArea/GoldLabel
@onready var stage_label: Label = $Layout/StatusArea/StageLabel
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_label: Label = \
		$VictoryPanel/VictoryBox/VictoryLabel
@onready var continue_button: Button = \
		$VictoryPanel/VictoryBox/ContinueButton


func _ready() -> void:
	submit_button.pressed.connect(_on_submit)
	word_input.text_submitted.connect(_on_text_submitted)
	word_input.text_changed.connect(_on_text_changed)
	continue_button.pressed.connect(_on_continue_pressed)
	enemy.died.connect(_on_enemy_died)
	victory_panel.hide()
	_start_encounter()


func _start_encounter() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	validator.start_encounter()
	deck_manager.start_encounter()
	var spawn_data: Dictionary = _pick_spawn_data()
	enemy.setup(spawn_data)
	EventBus.emit_encounter_started(spawn_data)
	_rebuild_hand_tiles()
	_refresh_status()
	_log("A %s appears! Its nature: %s" % [
		spawn_data["name"], " • ".join(spawn_data["tags"])
	])
	_enter_player_input()


func _pick_spawn_data() -> Dictionary:
	var enemy_id: String = RunState.next_enemy_id
	RunState.next_enemy_id = ""
	if enemy_id.is_empty():
		if RunState.is_boss_next():
			enemy_id = factory.boss_id()
		else:
			var choices: Array[String] = factory.ids_for_stage(
				RunState.encounter_index
			)
			enemy_id = choices.pick_random()
	return factory.build_spawn_data(enemy_id)


# --- Turn flow -----------------------------------------------------

func _enter_player_input() -> void:
	_state = State.PLAYER_INPUT
	word_input.editable = true
	submit_button.disabled = false
	word_input.grab_focus()


func _on_text_submitted(_text: String) -> void:
	_on_submit()


func _on_submit() -> void:
	if _state != State.PLAYER_INPUT:
		return
	var word: String = word_input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word)
	if not verdict["valid"]:
		feedback_label.text = verdict["reason"]
		EventBus.emit_word_rejected(word, verdict["reason"])
		return
	_state = State.RESOLVING
	word_input.editable = false
	submit_button.disabled = true
	feedback_label.text = ""
	_resolve_word(word)


func _resolve_word(word: String) -> void:
	var split: Dictionary = deck_manager.split_word(word)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags
	)
	validator.mark_played(word)
	RunState.record_word(
		word, enemy.enemy_name, enemy.tags, result["damage"]
	)
	if result["gold_bonus"] > 0:
		RunState.add_gold(result["gold_bonus"])
	if result["heal_amount"] > 0:
		RunState.heal_player(result["heal_amount"])
	EventBus.emit_word_resolved(result)
	_log(_describe_result(result))
	deck_manager.spend_letters(drawn)
	_rebuild_hand_tiles()
	word_input.clear()
	_refresh_status()
	enemy.take_damage(result["damage"])
	if enemy.is_alive():
		_enemy_turn()


func _enemy_turn() -> void:
	_state = State.ENEMY_TURN
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state != State.ENEMY_TURN:
		return
	_log("The %s retaliates for %d damage!" % [
		enemy.enemy_name, enemy.attack
	])
	RunState.damage_player(enemy.attack)
	_refresh_status()
	if RunState.player_health <= 0:
		_on_player_died()
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state == State.ENEMY_TURN:
		_enter_player_input()


func _on_enemy_died() -> void:
	if _state == State.WON:
		return
	_state = State.WON
	var earned: int = enemy.gold_reward
	# The Quill of Fortune relic pays a bonus on every victory.
	if RunState.relics.has("quill_of_fortune"):
		earned += 5
	RunState.add_gold(earned)
	RunState.is_run_active = true
	EventBus.emit_encounter_won(earned)
	_refresh_status()
	victory_label.text = "%s defeated!\n+%d gold" % [
		enemy.enemy_name, earned
	]
	victory_panel.show()


func _on_player_died() -> void:
	_state = State.LOST
	get_tree().change_scene_to_file(ScenePaths.RUN_LOST)


func _on_continue_pressed() -> void:
	var beaten_boss: bool = RunState.is_boss_next()
	RunState.advance_encounter()
	if beaten_boss:
		get_tree().change_scene_to_file(ScenePaths.RUN_WON)
	else:
		get_tree().change_scene_to_file(ScenePaths.TAVERN)


# --- Screen updates ------------------------------------------------

func _on_text_changed(new_text: String) -> void:
	var typing: bool = not new_text.strip_edges().is_empty()
	var split: Dictionary = deck_manager.split_word(
		new_text.strip_edges().to_lower()
	)
	var drawn: Array[LetterStats] = split["drawn"]
	for tile: LetterTile in hand_box.get_children():
		tile.set_used(drawn.has(tile.stats), typing)


func _rebuild_hand_tiles() -> void:
	for child: Node in hand_box.get_children():
		hand_box.remove_child(child)
		child.queue_free()
	for stats: LetterStats in deck_manager.hand():
		var tile: LetterTile = LETTER_TILE_SCENE.instantiate()
		hand_box.add_child(tile)
		tile.setup(stats)


func _refresh_status() -> void:
	player_health_bar.max_value = RunState.player_max_health
	player_health_bar.value = RunState.player_health
	player_health_label.text = "%d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold: %d" % RunState.gold
	var stage_text: String = "Encounter %d of %d" % [
		RunState.encounter_index, RunState.ENCOUNTERS_PER_RUN
	]
	if RunState.is_boss_next():
		stage_text = "Final Encounter"
	stage_label.text = stage_text


func _describe_result(result: Dictionary) -> String:
	var similarity: Dictionary = result["similarity"]
	var lines: Array[String] = []
	lines.append("[b]%s[/b] hits for %.0f!" % [
		result["word"].to_upper(), result["damage"]
	])
	lines.append(
		"  power %.1f × length %.1f × %s %.2f × tag %.2f" % [
			result["base_power"],
			result["length_multiplier"],
			WordNet.pos_name(result["pos"]),
			result["pos_multiplier"],
			result["semantic_multiplier"],
		]
	)
	if not String(similarity.get("tag", "")).is_empty():
		lines.append("  best match: %s (%.2f, %s)" % [
			similarity["tag"],
			similarity["score"],
			similarity["strategy"],
		])
	return "\n".join(lines)


func _log(message: String) -> void:
	log_label.append_text(message + "\n")
