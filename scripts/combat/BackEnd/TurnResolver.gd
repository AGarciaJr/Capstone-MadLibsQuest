extends RefCounted
class_name TurnResolver

## Resolves a combat turn: player attacks → enemy attacks → status effects.
## Returns damage messages and final HP. No UI, no Node dependencies.
##
## Order: 1) Player damage, 2) Enemy damage, 3) Status effect damage

## Classic English Scrabble tile values (A–Z).
const _SCRABBLE: Dictionary = {
	"A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4,
	"I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3,
	"Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8,
	"Y": 4, "Z": 10,
}

## Added per letter in the word that matches a player letter (testing mode).
const _PLAYER_LETTER_MULT_PER_HIT: float = 0.25

## Battle UI uses RichTextLabel BBCode for player crit styling.
const _PLAYER_CRIT_COLOR := "#e64545"

var _status_effects := StatusEffects.new()


func _format_player_strike_damage_line(damage: int, is_crit: bool) -> String:
	## Same line as non-crit (default RichTextLabel color). Crit appends only ` (crit)` in red.
	var line := "You dealt: %d damage." % damage
	if is_crit:
		line += "[color=%s] (crit)[/color]" % _PLAYER_CRIT_COLOR
	return line

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

	var use_scrabble: bool = bool(ctx.get("use_scrabble_test_damage", false))

	# One player attack per resolve call (one word). Extra strikes = extra resolve_single_player_attack calls from UI.
	if include_player_attacks:
		if use_scrabble:
			var sw: String = str(ctx.get("strike_word", ""))
			var pl := ctx.get("player_letters", PackedStringArray()) as PackedStringArray
			var uses_player_letters: bool = bool(ctx.get("uses_player_letters", ctx.get("uses_bonus_letters", true)))
			if not uses_player_letters:
				damage_messages.append(
					"Oh no — you missed! You didn't use any of your player letters."
				)
			elif current_enemy_hp > 0:
				var sd: Dictionary = _compute_scrabble_damage(sw, pl)
				var total_player_damage: int = int(sd["damage"])
				current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, total_player_damage)
				_append_scrabble_player_messages(damage_messages, sw, pl, sd, total_player_damage)
			else:
				damage_messages.append("You dealt: 0 damage.")
		else:
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
				damage_messages.append(
					_format_player_strike_damage_line(total_player_damage, bool(outcome.get("is_crit", false)))
				)
			else:
				damage_messages.append("You dealt: 0 damage.")

		if current_enemy_hp <= 0:
			return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	# Enemy attacks
	var total_enemy_damage: int = 0
	if use_scrabble:
		var flat: int = int(ctx.get("test_enemy_damage_per_strike", 5))
		for j in enemy_attacks_per_turn:
			if current_player_hp <= 0:
				break
			current_player_hp = max(0, current_player_hp - flat)
			total_enemy_damage += flat
			if current_player_hp <= 0:
				break
	else:
		for j in enemy_attacks_per_turn:
			if current_player_hp <= 0:
				break
			var outcome := CombatEngine.compute_attack(enemy_stats, player_stats, enemy_move, rng)
			var edmg: int = int(outcome.damage)
			total_enemy_damage += edmg
			current_player_hp = max(0, current_player_hp - edmg)
			if current_player_hp <= 0:
				break
	if use_scrabble:
		var flat_r: int = int(ctx.get("test_enemy_damage_per_strike", 5))
		damage_messages.append("Enemy per attack: %d damage." % flat_r)
		damage_messages.append(
			"Enemy total: %d × %d attack(s) = %d damage." % [flat_r, enemy_attacks_per_turn, total_enemy_damage]
		)
	else:
		damage_messages.append("The enemy dealt: %d damage." % total_enemy_damage)

	if current_player_hp <= 0:
		return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	if not use_scrabble and not active_status_effects.is_empty():
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

	var use_scrabble: bool = bool(ctx.get("use_scrabble_test_damage", false))
	var uses_player_letters: bool = bool(ctx.get("uses_player_letters", ctx.get("uses_bonus_letters", true)))

	if use_scrabble:
		var sw: String = str(ctx.get("strike_word", ""))
		var pl := ctx.get("player_letters", PackedStringArray()) as PackedStringArray
		if not uses_player_letters:
			damage_messages.append(
				"Oh no — you missed! You didn't use any of your player letters."
			)
		elif current_enemy_hp > 0:
			var sd: Dictionary = _compute_scrabble_damage(sw, pl)
			var dmg: int = int(sd["damage"])
			current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, dmg)
			_append_scrabble_player_messages(damage_messages, sw, pl, sd, dmg)
		else:
			damage_messages.append("You dealt: 0 damage.")
	else:
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
			damage_messages.append(_format_player_strike_damage_line(dmg, bool(outcome.get("is_crit", false))))
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

	var use_scrabble: bool = bool(ctx.get("use_scrabble_test_damage", false))

	var total_enemy_damage: int = 0
	if use_scrabble:
		var flat: int = int(ctx.get("test_enemy_damage_per_strike", 5))
		for j in enemy_attacks_per_turn:
			if current_player_hp <= 0:
				break
			current_player_hp = max(0, current_player_hp - flat)
			total_enemy_damage += flat
			if current_player_hp <= 0:
				break
	else:
		for j in enemy_attacks_per_turn:
			if current_player_hp <= 0:
				break
			var outcome := CombatEngine.compute_attack(enemy_stats, player_stats, enemy_move, rng)
			var edmg: int = int(outcome.damage)
			total_enemy_damage += edmg
			current_player_hp = max(0, current_player_hp - edmg)
			if current_player_hp <= 0:
				break
	if use_scrabble:
		var flat_es: int = int(ctx.get("test_enemy_damage_per_strike", 5))
		damage_messages.append("Enemy per attack: %d damage." % flat_es)
		damage_messages.append(
			"Enemy total: %d × %d attack(s) = %d damage." % [flat_es, enemy_attacks_per_turn, total_enemy_damage]
		)
	else:
		damage_messages.append("The enemy dealt: %d damage." % total_enemy_damage)

	if current_player_hp <= 0:
		return _make_result(damage_messages, current_enemy_hp, current_player_hp)

	if not use_scrabble and not active_status_effects.is_empty():
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


func _scrabble_word_base(word: String) -> int:
	var total := 0
	var w := word.to_upper()
	for i in w.length():
		var c: String = w.substr(i, 1)
		if _SCRABBLE.has(c):
			total += int(_SCRABBLE[c])
	return total


func _player_letter_hits_in_word(word: String, player_letters: PackedStringArray) -> int:
	if player_letters.is_empty():
		return 0
	var w := word.to_upper()
	var n := 0
	for i in w.length():
		var ch: String = w.substr(i, 1)
		if not _SCRABBLE.has(ch):
			continue
		for j in player_letters.size():
			if String(player_letters[j]).to_upper() == ch:
				n += 1
				break
	return n


## Base = sum of Scrabble tile values (A–Z only). Mult = 1 + bonus per player-letter tile in the word.
func _compute_scrabble_damage(word: String, player_letters: PackedStringArray) -> Dictionary:
	var base: int = _scrabble_word_base(word)
	var hits: int = 0
	var mult: float = 1.0
	if player_letters.is_empty():
		mult = 1.0
	else:
		hits = _player_letter_hits_in_word(word, player_letters)
		mult = 1.0 + _PLAYER_LETTER_MULT_PER_HIT * float(hits)
	var damage: int = maxi(0, int(round(float(base) * mult)))
	return {"damage": damage, "base": base, "mult": mult, "hits": hits}


func _scrabble_float_str(v: float) -> String:
	if is_equal_approx(v, float(int(round(v)))):
		return str(int(round(v)))
	return "%.2f" % v


func _format_scrabble_tile_line(word: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in word.length():
		var ch: String = word.substr(i, 1)
		var u := ch.to_upper()
		if _SCRABBLE.has(u):
			parts.append("%s=%d" % [ch, int(_SCRABBLE[u])])
		else:
			parts.append("%s=0" % ch)
	var base: int = _scrabble_word_base(word)
	if parts.is_empty():
		return "Letters: (empty) → base %d" % base
	return "Letters: %s → base %d" % [" + ".join(parts), base]


func _append_scrabble_player_messages(
	damage_messages: Array,
	word: String,
	player_letters: PackedStringArray,
	sd: Dictionary,
	total_damage: int,
) -> void:
	damage_messages.append(_format_scrabble_tile_line(word))
	var hits: int = int(sd.get("hits", 0))
	var base: int = int(sd["base"])
	var mult: float = float(sd["mult"])
	var mult_explain: String
	if player_letters.is_empty():
		mult_explain = "Multiplier: ×%s (no player letters)" % _scrabble_float_str(mult)
	else:
		var add_part: float = _PLAYER_LETTER_MULT_PER_HIT * float(hits)
		mult_explain = "Multiplier: 1 + (%.2f × %d hits) = 1 + %s = ×%s" % [
			_PLAYER_LETTER_MULT_PER_HIT,
			hits,
			_scrabble_float_str(add_part),
			_scrabble_float_str(mult),
		]
	damage_messages.append(mult_explain)
	damage_messages.append(
		"Damage: round(%d × %s) = %d." % [base, _scrabble_float_str(mult), total_damage]
	)
	damage_messages.append("You dealt %d damage." % total_damage)
