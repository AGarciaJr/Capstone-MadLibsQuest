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

## Per prior use of the same word this encounter, damage is reduced by this fraction (additive stacks).
const REPEAT_WORD_DAMAGE_PENALTY_PER_PRIOR := 0.15

## Battle UI uses RichTextLabel BBCode for player crit styling.
const _PLAYER_CRIT_COLOR := "#e64545"

var _status_effects := StatusEffects.new()


func _apply_repeat_word_damage_penalty(damage: int, prior_uses: int, damage_messages: Array) -> int:
	if prior_uses <= 0:
		return damage
	var mult: float = maxf(0.05, 1.0 - REPEAT_WORD_DAMAGE_PENALTY_PER_PRIOR * float(prior_uses))
	var pct: int = int(round(float(prior_uses) * 100.0 * REPEAT_WORD_DAMAGE_PENALTY_PER_PRIOR))
	damage_messages.append(
		"Repeat word — this hit dealt %d%% less damage due to repeat word usage." % pct
	)
	return maxi(0, int(round(float(damage) * mult)))


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
		var strike_res: Dictionary = _player_strike_with_word(
			ctx,
			damage_messages,
			current_enemy_hp,
			current_player_hp,
			use_scrabble,
			freq_scaling,
			letter_bonus_mult,
			player_stats,
			enemy_stats,
			rng,
		)
		current_enemy_hp = int(strike_res["enemy_hp"])
		current_player_hp = int(strike_res["player_hp"])

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
	var strike_res: Dictionary = _player_strike_with_word(
		ctx,
		damage_messages,
		current_enemy_hp,
		current_player_hp,
		use_scrabble,
		freq_scaling,
		letter_bonus_mult,
		player_stats,
		enemy_stats,
		rng,
	)
	current_enemy_hp = int(strike_res["enemy_hp"])
	current_player_hp = int(strike_res["player_hp"])

	return _make_result(damage_messages, current_enemy_hp, current_player_hp)


func _player_strike_with_word(
	ctx: Dictionary,
	damage_messages: Array[String],
	start_enemy_hp: int,
	start_player_hp: int,
	use_scrabble: bool,
	freq_scaling: float,
	letter_bonus_mult: float,
	player_stats: Dictionary,
	enemy_stats: Dictionary,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var strike_word: String = str(ctx.get("strike_word", ""))
	var pl := ctx.get("player_letters", PackedStringArray()) as PackedStringArray
	var uses_player_letters: bool = bool(ctx.get("uses_player_letters", ctx.get("uses_bonus_letters", true)))
	var enemy_max_hp: int = maxi(1, int(ctx.get("enemy_max_hp", 1)))
	var player_max_hp: int = maxi(1, int(ctx.get("player_max_hp", start_player_hp)))

	var current_enemy_hp: int = start_enemy_hp
	var current_player_hp: int = start_player_hp

	if not uses_player_letters:
		damage_messages.append(
			"Oh no — you missed! You didn't use any of your player letters."
		)
		return {"enemy_hp": current_enemy_hp, "player_hp": current_player_hp}

	var grp: Dictionary = LetterGroupBonuses.compute_strike_bonuses(
		strike_word, pl, enemy_max_hp, player_max_hp
	)
	var vowel_heal: int = int(grp.get("vowel_heal", 0))
	if vowel_heal > 0:
		current_player_hp = mini(player_max_hp, current_player_hp + vowel_heal)
		var vc: int = int(grp.get("vowel_count", 0))
		damage_messages.append(
			"%s: you recovered %d HP (%d vowel%s × 2%% max HP)." % [
				LetterGroupBonuses.GROUP_THEME_VOWEL,
				vowel_heal,
				vc,
				"s" if vc != 1 else "",
			]
		)

	if current_enemy_hp <= 0:
		damage_messages.append("You dealt: 0 damage.")
		return {"enemy_hp": current_enemy_hp, "player_hp": current_player_hp}

	var prior_rw: int = int(ctx.get("repeat_word_prior_uses", 0))
	var flat_add: int = int(grp.get("flat_damage_add", 0))
	var rare_flat: int = int(grp.get("rare_max_hp_damage", 0))
	var common_n: int = int(grp.get("common_count", 0))
	var vr_n: int = int(grp.get("very_rare_count", 0))
	var rare_n: int = int(grp.get("rare_count", 0))

	if use_scrabble:
		var sd: Dictionary = _compute_scrabble_damage(strike_word, pl)
		var scrabble_core: int = int(sd["damage"])
		var pre_repeat: int = scrabble_core + flat_add + rare_flat
		var total_player_damage: int = _apply_repeat_word_damage_penalty(
			pre_repeat, prior_rw, damage_messages
		)
		current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, total_player_damage)
		_append_scrabble_player_messages(
			damage_messages,
			strike_word,
			pl,
			sd,
			scrabble_core,
			pre_repeat,
			total_player_damage,
			flat_add,
			rare_flat,
		)
	else:
		var player_move := {
			"base_damage": 5 + int(grp.get("flat_base_damage_bonus", 0)),
			"scaling": freq_scaling,
			"coefficient": 1.2 * letter_bonus_mult,
			"accuracy": 1.0,
		}
		var outcome := CombatEngine.compute_attack(player_stats, enemy_stats, player_move, rng)
		var pre_repeat2: int = int(outcome.damage) + rare_flat
		var total_dmg: int = _apply_repeat_word_damage_penalty(pre_repeat2, prior_rw, damage_messages)
		current_enemy_hp = CombatEngine.apply_damage(current_enemy_hp, total_dmg)
		if common_n > 0 or vr_n > 0:
			damage_messages.append(
				"%s / %s: +%d base damage on this strike (%d Knight letters × 2, %d Royalty × 10)."
				% [
					LetterGroupBonuses.GROUP_THEME_COMMON,
					LetterGroupBonuses.GROUP_THEME_VERY_RARE,
					common_n * 2 + vr_n * 10,
					common_n,
					vr_n,
				]
			)
		if rare_n > 0 and rare_flat > 0:
			damage_messages.append(
				"%s: +%d damage (%d rare × 5%% enemy max HP)." % [
					LetterGroupBonuses.GROUP_THEME_RARE,
					rare_flat,
					rare_n,
				]
			)
		damage_messages.append(
			_format_player_strike_damage_line(total_dmg, bool(outcome.get("is_crit", false)))
		)

	return {"enemy_hp": current_enemy_hp, "player_hp": current_player_hp}

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
	scrabble_core_damage: int,
	pre_repeat_total: int,
	final_damage: int = -1,
	letter_group_flat_add: int = 0,
	letter_group_rare_damage: int = 0,
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
		"Damage: round(%d × %s) = %d." % [base, _scrabble_float_str(mult), scrabble_core_damage]
	)
	if pre_repeat_total > scrabble_core_damage:
		var delta: int = pre_repeat_total - scrabble_core_damage
		var explain: String
		if letter_group_flat_add > 0 and letter_group_rare_damage > 0:
			explain = "%s / %s +%d, %s +%d" % [
				LetterGroupBonuses.GROUP_THEME_COMMON,
				LetterGroupBonuses.GROUP_THEME_VERY_RARE,
				letter_group_flat_add,
				LetterGroupBonuses.GROUP_THEME_RARE,
				letter_group_rare_damage,
			]
		elif letter_group_flat_add > 0:
			explain = "%s / %s +%d" % [
				LetterGroupBonuses.GROUP_THEME_COMMON,
				LetterGroupBonuses.GROUP_THEME_VERY_RARE,
				letter_group_flat_add,
			]
		else:
			explain = "%s +%d (5%% max HP per rare letter)" % [
				LetterGroupBonuses.GROUP_THEME_RARE,
				letter_group_rare_damage,
			]
		damage_messages.append("Letter groups (%s) → subtotal %d." % [explain, pre_repeat_total])
	var dealt: int = pre_repeat_total if final_damage < 0 else final_damage
	damage_messages.append("You dealt %d damage." % dealt)
