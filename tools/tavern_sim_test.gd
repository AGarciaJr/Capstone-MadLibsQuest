extends Node
## Headless simulation of the tavern: exercises the economy
## (upgrades, classes, modifiers, dropping letters, relics, meals)
## and checks the storyteller produces a tale from history.
##
## Run from the project root:
##   godot --headless --path . res://tools/tavern_sim_test.tscn

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	RunState.record_word(
		"torrent", "Red Dragon", ["fiery"], 31.0
	)
	RunState.record_word(
		"pebble", "Red Dragon", ["fiery"], 4.0
	)
	RunState.damage_player(20)
	var scene: PackedScene = load(ScenePaths.TAVERN)
	var tavern: Control = scene.instantiate()
	get_tree().root.add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	var economy: EconomySystem = tavern.economy
	var first: LetterStats = RunState.deck[0]
	# Broke: nothing should be purchasable.
	_expect(
		not economy.buy_upgrade(first),
		"upgrade refused when broke"
	)
	RunState.add_gold(500)
	_expect(economy.buy_upgrade(first), "upgrade bought")
	_expect(first.level == 2, "letter reached level 2")
	_expect(
		economy.buy_class(
			first, LetterStats.LetterClass.SAGE
		),
		"class trained"
	)
	_expect(
		economy.buy_modifier(
			first, LetterStats.Modifier.KEEN
		),
		"modifier forged"
	)
	var deck_size: int = RunState.deck.size()
	_expect(
		economy.drop_letter(RunState.deck[1]),
		"letter dropped"
	)
	_expect(
		RunState.deck.size() == deck_size - 1,
		"deck shrank by one"
	)
	var max_before: int = RunState.player_max_health
	_expect(
		economy.buy_relic("iron_bookmark"), "relic bought"
	)
	_expect(
		RunState.player_max_health == max_before + 10,
		"bookmark raised max health"
	)
	_expect(
		not economy.buy_relic("iron_bookmark"),
		"relic not sold twice"
	)
	var health_before: int = RunState.player_health
	_expect(economy.buy_meal(), "meal bought")
	_expect(
		RunState.player_health > health_before, "meal healed"
	)
	var bard: Storyteller = Storyteller.new()
	var tale: String = bard.generate()
	print("--- tale ---")
	print(tale)
	print("------------")
	_expect(tale.contains("TORRENT"), "tale features best word")
	_expect(
		tavern.deck_grid.get_child_count() \
				== RunState.deck.size(),
		"deck grid matches deck"
	)
	print("=== %d failure(s) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
