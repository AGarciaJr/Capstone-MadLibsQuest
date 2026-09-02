extends Control
## The tavern hub between fights: the shop where the letter deck
## is trained, forged, and thinned; the relic shelf; a hot meal;
## and the bard retelling the journey. Leaving heads to the
## encounter-select screen. All spending goes through the
## EconomySystem child.

var _selected: LetterStats = null
var _letter_group: ButtonGroup = ButtonGroup.new()

@onready var economy: EconomySystem = $Systems/EconomySystem
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var health_label: Label = $TopBar/HealthLabel
@onready var story_label: RichTextLabel = \
		$Layout/StoryPanel/StoryMargin/StoryLabel
@onready var deck_grid: GridContainer = \
		$Layout/ShopPanel/ShopMargin/ShopBox/DeckScroll/DeckGrid
@onready var selected_label: Label = \
		$Layout/ShopPanel/ShopMargin/ShopBox/SelectedLabel
@onready var upgrade_button: Button = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow1/UpgradeButton
@onready var drop_button: Button = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow1/DropButton
@onready var class_option: OptionButton = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow2/ClassOption
@onready var class_button: Button = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow2/ClassButton
@onready var modifier_option: OptionButton = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow2/ModifierOption
@onready var modifier_button: Button = \
		$Layout/ShopPanel/ShopMargin/ShopBox/ActionRow2/ModifierButton
@onready var relics_row: HBoxContainer = \
		$Layout/ShopPanel/ShopMargin/ShopBox/RelicsRow
@onready var meal_button: Button = \
		$Layout/ShopPanel/ShopMargin/ShopBox/MealButton
@onready var feedback_label: Label = \
		$Layout/ShopPanel/ShopMargin/ShopBox/FeedbackLabel
@onready var continue_button: Button = $ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	class_button.pressed.connect(_on_class_pressed)
	modifier_button.pressed.connect(_on_modifier_pressed)
	meal_button.pressed.connect(_on_meal_pressed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.deck_changed.connect(_on_deck_changed)
	_fill_options()
	_build_relic_buttons()
	_rebuild_deck_grid()
	_refresh_top_bar()
	_refresh_actions()
	var bard: Storyteller = Storyteller.new()
	story_label.text = bard.generate()


# --- Shop actions --------------------------------------------------

func _on_upgrade_pressed() -> void:
	if _selected == null:
		return
	if economy.buy_upgrade(_selected):
		_note("%s studies hard." % _selected.letter.to_upper())
	else:
		_note("Not enough gold.")


func _on_drop_pressed() -> void:
	if _selected == null:
		return
	if economy.drop_letter(_selected):
		_note("The letter departs.")
		_selected = null
	else:
		_note("The deck must keep at least ten letters.")


func _on_class_pressed() -> void:
	if _selected == null:
		return
	var choice: LetterStats.LetterClass = \
			class_option.get_selected_id() as \
			LetterStats.LetterClass
	if economy.buy_class(_selected, choice):
		_note("%s takes up a new calling." % \
				_selected.letter.to_upper())
	else:
		_note("Cannot train that (gold, or already trained).")


func _on_modifier_pressed() -> void:
	if _selected == null:
		return
	var choice: LetterStats.Modifier = \
			modifier_option.get_selected_id() as \
			LetterStats.Modifier
	if economy.buy_modifier(_selected, choice):
		_note("The forge sings.")
	else:
		_note("Cannot forge that (gold, or already forged).")


func _on_meal_pressed() -> void:
	if economy.buy_meal():
		_note("Warm stew. +%d health." % economy.MEAL_HEAL)
		_refresh_top_bar()
	else:
		_note("No need, or no gold.")


func _on_relic_pressed(relic_id: String) -> void:
	if economy.buy_relic(relic_id):
		_note("The relic hums in your pack.")
		_build_relic_buttons()
		_refresh_top_bar()
	else:
		_note("Not enough gold.")


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(
		ScenePaths.ENCOUNTER_SELECT
	)


# --- Screen updates ------------------------------------------------

func _on_gold_changed(_new_total: int) -> void:
	_refresh_top_bar()
	_refresh_actions()


func _on_deck_changed() -> void:
	_rebuild_deck_grid()
	_refresh_actions()


func _fill_options() -> void:
	class_option.clear()
	class_option.add_item(
		"Striker", LetterStats.LetterClass.STRIKER
	)
	class_option.add_item("Sage", LetterStats.LetterClass.SAGE)
	class_option.add_item(
		"Merchant", LetterStats.LetterClass.MERCHANT
	)
	class_option.add_item("Leech", LetterStats.LetterClass.LEECH)
	modifier_option.clear()
	modifier_option.add_item("Keen", LetterStats.Modifier.KEEN)
	modifier_option.add_item(
		"Gilded", LetterStats.Modifier.GILDED
	)
	modifier_option.add_item("Heavy", LetterStats.Modifier.HEAVY)


func _build_relic_buttons() -> void:
	for child: Node in relics_row.get_children():
		relics_row.remove_child(child)
		child.queue_free()
	for relic_id: String in economy.relic_ids():
		var info: Dictionary = economy.relic_info(relic_id)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		if economy.owns_relic(relic_id):
			button.text = "%s\n(owned)" % info["name"]
			button.disabled = true
		else:
			button.text = "%s\n%dg" % [
				info["name"], info["price"]
			]
		button.tooltip_text = info["description"]
		button.pressed.connect(
			_on_relic_pressed.bind(relic_id)
		)
		relics_row.add_child(button)


func _rebuild_deck_grid() -> void:
	for child: Node in deck_grid.get_children():
		deck_grid.remove_child(child)
		child.queue_free()
	for stats: LetterStats in RunState.deck:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _letter_group
		button.custom_minimum_size = Vector2(56, 48)
		button.text = "%s\nLv%d" % [
			stats.letter.to_upper(), stats.level
		]
		button.tooltip_text = stats.describe()
		button.pressed.connect(
			_on_letter_selected.bind(stats, button)
		)
		deck_grid.add_child(button)


func _on_letter_selected(
	stats: LetterStats, _button: Button
) -> void:
	_selected = stats
	_refresh_actions()


func _refresh_top_bar() -> void:
	gold_label.text = "Gold: %d" % RunState.gold
	health_label.text = "Health: %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]


func _refresh_actions() -> void:
	if _selected == null:
		selected_label.text = "Pick a letter to train"
		upgrade_button.disabled = true
		drop_button.disabled = true
		class_button.disabled = true
		modifier_button.disabled = true
		return
	selected_label.text = _selected.describe()
	upgrade_button.text = "Level Up (%dg)" % \
			economy.upgrade_price(_selected)
	upgrade_button.disabled = false
	drop_button.disabled = false
	class_button.text = "Train (%dg)" % economy.CLASS_PRICE
	class_button.disabled = false
	modifier_button.text = "Forge (%dg)" % \
			economy.MODIFIER_PRICE
	modifier_button.disabled = false


func _note(message: String) -> void:
	feedback_label.text = message
