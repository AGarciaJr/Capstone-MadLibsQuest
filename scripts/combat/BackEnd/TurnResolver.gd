extends RefCounted
class_name TurnResolver

## Resolves a combat turn: player attacks → enemy attacks → status effects.
## Returns damage messages and final HP. No UI, no Node dependencies.
##
## Order: 1) Player damage, 2) Enemy damage, 3) Status effect damage

var _status_effects := StatusEffects.new()

## Full turn in one call when player_attacks_per_turn is 1 (single word for the round).
func resolve_valid_turn(ctx: Dictionary) -> Dictionary:
	return _resolve(ctx, true)

## Resolves an invalid turn (player submitted bad word - no player attacks).
func resolve_invalid_turn(ctx: Dictionary) -> Dictionary:
	return _resolve(ctx, false)

func _resolve(ctx: Dictionary, include_player_attacks: bool) -> Dictionary:
	var damage_messages: Array[String] = []
	var current_enemy_hp: int = int(ctx.get("enemy_hp", 0))
	var current_player_hp: int = int(ctx.get("player_hp", 0))
	var enemy_max_hp: int = int(ctx.get("enemy_max_hp", 1))
	var player_stats: Dictionary = ctx.get("player_stats", {})
	var enemy_stats: Dictionary = ctx.get("enemy_stats", {})
	var enemy_move: Dictionary = ctx.get("enemy_move", {})
	var enemy_attacks_per_turn: int = int(ctx.get("enemy_attacks_per_turn", 1))
	var active_status_effects: Array = ctx.get("active_status_effects", [])
	var freq_scaling: float = float(ctx.get("freq_scaling", 0.0))
	var letter_bonus_mult: float = float(ctx.get("letter_bonus_mult", 1.0))
	var rng: RandomNumberGenerator = ctx.get("rng", null)

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# One player attack per resolve call (one word). Extra strikes = extra resolve_single_player_attack calls from UI.
	if include_player_attacks:
		var uses_player_letters: bool = bool(ctx.get("uses_player_letters", ctx.get("uses_bonus_letters", true)))
		if not uses_player_letters:
			damage_messages.append(
				"Oh no — you missed! You didn't use any of your player letters."
			)
		elif current_enemy_hp > 0:
			var player_move := {
				"base_damage": 5,
				"scaling": freq_scaling,
				"coefficient": 1.2 * letter_bonus_mult,
				"accuracy": 1.0,
			}
			var outcome := CombatEngine.compute_attack(player_stats, enemy_stats, player_move, rng)
			var total_player_damage: int = int(outcome.damage)
			current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, total_player_damage)
			damage_messages.append("You dealt: %d damage." % total_player_damage)
		else:
			damage_messages.append("You dealt: 0 damage.")

		if current_enemy_hp <= 0:
			return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	# Enemy attacks (CombatEngine)
	var total_enemy_damage: int = 0
	for j in enemy_attacks_per_turn:
		if current_player_hp <= 0:
			break
		var outcome := CombatEngine.compute_attack(enemy_stats, player_stats, enemy_move, rng)
		var edmg: int = int(outcome.damage)
		total_enemy_damage += edmg
		current_player_hp = max(0, current_player_hp - edmg)
		if current_player_hp <= 0:
			break
	damage_messages.append("The enemy dealt: %d damage." % total_enemy_damage)

	if current_player_hp <= 0:
		return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	if not active_status_effects.is_empty():
		var status_context := {"enemy_hp": current_enemy_hp, "enemy_max_hp": enemy_max_hp}
		_status_effects.apply_turn_start_effects(active_status_effects, status_context)
		current_enemy_hp = int(status_context["enemy_hp"])
		for entry in status_context.get("status_damage_entries", []):
			var d: Dictionary = entry as Dictionary
			damage_messages.append("Enemy took %d damage from %s." % [int(d.get("amount", 0)), str(d.get("source", "status"))])

	return _make_result(damage_messages, current_enemy_hp, current_player_hp)

## One player attack using this word's scaling / letter bonus. Use once per word the player enters.
func resolve_single_player_attack(ctx: Dictionary) -> Dictionary:
	var damage_messages: Array[String] = []
	var current_enemy_hp: int = int(ctx.get("enemy_hp", 0))
	var current_player_hp: int = int(ctx.get("player_hp", 0))
	var player_stats: Dictionary = ctx.get("player_stats", {})
	var enemy_stats: Dictionary = ctx.get("enemy_stats", {})
	var freq_scaling: float = float(ctx.get("freq_scaling", 0.0))
	var letter_bonus_mult: float = float(ctx.get("letter_bonus_mult", 1.0))
	var rng: RandomNumberGenerator = ctx.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var uses_player_letters: bool = bool(ctx.get("uses_player_letters", ctx.get("uses_bonus_letters", true)))
	if not uses_player_letters:
		damage_messages.append(
			"Oh no — you missed! You didn't use any of your player letters."
		)
	elif current_enemy_hp > 0:
		var player_move := {
			"base_damage": 5,
			"scaling": freq_scaling,
			"coefficient": 1.2 * letter_bonus_mult,
			"accuracy": 1.0,
		}
		var outcome := CombatEngine.compute_attack(player_stats, enemy_stats, player_move, rng)
		var dmg: int = int(outcome.damage)
		current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, dmg)
		damage_messages.append("You dealt: %d damage." % dmg)
	else:
		damage_messages.append("You dealt: 0 damage.")

	return _make_result(damage_messages, current_enemy_hp, current_player_hp)

## After all player strikes for the round, run enemy attacks + status effects.
func resolve_enemy_and_status(ctx: Dictionary) -> Dictionary:
	var damage_messages: Array[String] = []
	var current_enemy_hp: int = int(ctx.get("enemy_hp", 0))
	var current_player_hp: int = int(ctx.get("player_hp", 0))
	var enemy_max_hp: int = int(ctx.get("enemy_max_hp", 1))
	var player_stats: Dictionary = ctx.get("player_stats", {})
	var enemy_stats: Dictionary = ctx.get("enemy_stats", {})
	var enemy_move: Dictionary = ctx.get("enemy_move", {})
	var enemy_attacks_per_turn: int = int(ctx.get("enemy_attacks_per_turn", 1))
	var active_status_effects: Array = ctx.get("active_status_effects", [])
	var rng: RandomNumberGenerator = ctx.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Enemy attacks (CombatEngine)
	var total_enemy_damage: int = 0
	for j in enemy_attacks_per_turn:
		if current_player_hp <= 0:
			break
		var outcome := CombatEngine.compute_attack(enemy_stats, player_stats, enemy_move, rng)
		var edmg: int = int(outcome.damage)
		total_enemy_damage += edmg
		current_player_hp = max(0, current_player_hp - edmg)
		if current_player_hp <= 0:
			break
	damage_messages.append("The enemy dealt: %d damage." % total_enemy_damage)

	if current_player_hp <= 0:
		return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	# 3. Status effects (StatusEffects)
	if not active_status_effects.is_empty():
		var status_context := {"enemy_hp": current_enemy_hp, "enemy_max_hp": enemy_max_hp}
		_status_effects.apply_turn_start_effects(active_status_effects, status_context)
		current_enemy_hp = int(status_context["enemy_hp"])
		for entry in status_context.get("status_damage_entries", []):
			var d: Dictionary = entry as Dictionary
			damage_messages.append("Enemy took %d damage from %s." % [int(d.get("amount", 0)), str(d.get("source", "status"))])

	return _make_result(damage_messages, current_enemy_hp, current_player_hp)


func _make_result(damage_messages: Array, enemy_hp: int, player_hp: int) -> Dictionary:
	return {
		"damage_messages": damage_messages,
		"enemy_hp": enemy_hp,
		"player_hp": player_hp,
		"enemy_defeated": enemy_hp <= 0,
		"player_defeated": player_hp <= 0,
	}
