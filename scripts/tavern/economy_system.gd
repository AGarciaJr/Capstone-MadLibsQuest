class_name EconomySystem
extends Node
## The tavern's till: prices and transactions for letter training,
## letter forging, relics, and meals. Only this class spends the
## run's gold; the tavern screen just asks and displays.

const RELICS_DATA_PATH: String = "res://data/relics.json"

const CLASS_PRICE: int = 25
const MODIFIER_PRICE: int = 20
const DROP_REFUND: int = 2
const MEAL_PRICE: int = 15
const MEAL_HEAL: int = 10

# Relic id -> {"name", "description", "price"}.
var _relics: Dictionary = {}


func _ready() -> void:
	_load_relics()


func relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _relics:
		ids.append(id)
	return ids


func relic_info(relic_id: String) -> Dictionary:
	return _relics.get(relic_id, {})


## Price to raise the letter to its next level.
func upgrade_price(stats: LetterStats) -> int:
	return 10 + 5 * stats.level


## Levels the letter up if the player can afford it.
func buy_upgrade(stats: LetterStats) -> bool:
	if not RunState.spend_gold(upgrade_price(stats)):
		return false
	stats.level += 1
	EventBus.emit_deck_changed()
	return true


## Trains the letter into a class.
func buy_class(
	stats: LetterStats, new_class: LetterStats.LetterClass
) -> bool:
	if stats.letter_class == new_class:
		return false
	if not RunState.spend_gold(CLASS_PRICE):
		return false
	stats.letter_class = new_class
	EventBus.emit_deck_changed()
	return true


## Forges a modifier onto the letter.
func buy_modifier(
	stats: LetterStats, new_modifier: LetterStats.Modifier
) -> bool:
	if stats.modifier == new_modifier:
		return false
	if not RunState.spend_gold(MODIFIER_PRICE):
		return false
	stats.modifier = new_modifier
	EventBus.emit_deck_changed()
	return true


## Removes a letter from the deck for a small refund. The deck
## keeps a floor of ten letters so words stay spellable.
func drop_letter(stats: LetterStats) -> bool:
	if RunState.deck.size() <= 10:
		return false
	if not RunState.deck.has(stats):
		return false
	RunState.deck.erase(stats)
	RunState.add_gold(DROP_REFUND)
	EventBus.emit_deck_changed()
	return true


func owns_relic(relic_id: String) -> bool:
	return RunState.relics.has(relic_id)


## Buys a relic and applies any immediate effect.
func buy_relic(relic_id: String) -> bool:
	if owns_relic(relic_id) or not _relics.has(relic_id):
		return false
	var price: int = _relics[relic_id]["price"]
	if not RunState.spend_gold(price):
		return false
	RunState.relics.append(relic_id)
	if relic_id == "iron_bookmark":
		RunState.player_max_health += 10
		RunState.heal_player(10)
	EventBus.emit_relic_gained(relic_id)
	return true


## Buys a meal that heals part of the player's health.
func buy_meal() -> bool:
	if RunState.player_health >= RunState.player_max_health:
		return false
	if not RunState.spend_gold(MEAL_PRICE):
		return false
	RunState.heal_player(MEAL_HEAL)
	return true


func _load_relics() -> void:
	var file: FileAccess = FileAccess.open(
		RELICS_DATA_PATH, FileAccess.READ
	)
	if file == null:
		push_error("EconomySystem: cannot open relic data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EconomySystem: relic data is not valid JSON")
		return
	_relics = parsed
