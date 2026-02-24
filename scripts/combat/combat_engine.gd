class_name CombatEngine

# Pure combat math -> No Nodes. No UI.
# Return dictionaries

static func compute_attack(attacker: Dictionary, defender: Dictionary, move: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	# Returns:
	# { "hit": bool, "damage": int, "is_crit": bool, "pre_mitigation": float,
	#   "post_mitigation": float, "debug": String }

	# attacker base stats
	var attacker_atk: float = float(attacker.get("atk", 0))
	var attacker_crit: float = float(attacker.get("crit_chance", 0.0))
	var attacker_crit_mult: float = float(attacker.get("crit_mult", 1.5))
	
	# move stats
	var move_base_dmg: float = float(move.get("base_damage", 0))
	var word_scaling_const: float = float(move.get("scaling", 0))
	var coef: float = float(move.get("coefficient", 1.0))
	var accuracy: float = float(move.get("accuracy", 1.0))

	# defender stats
	var defenders_def: float = float(defender.get("def", 0))
	var defenders_armor: float = float(defender.get("armor", 0))

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Accuracy roll
	if accuracy < 1.0:
		var roll_acc := rng.randf()
		if roll_acc > accuracy:
			return {
				"hit": false,
				"damage": 0,
				"is_crit": false,
				"pre_mitigation": 0.0,
				"post_mitigation": 0.0,
				"debug": "Miss (accuracy roll %.3f > %.3f)" % [roll_acc, accuracy]
			}

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Accuracy check
	if accuracy < 1.0:
		var roll_acc := rng.randf()
		if roll_acc > accuracy:
			return {
				"hit": false,
				"damage": 0,
				"is_crit": false,
				"raw_damage": 0.0,
				"post_mitigation": 0.0,
				"debug": "Miss (accuracy)"
			}

	# RAW DAMAGE
	# D_raw = (B + S * A) * C
	var raw_damage: float = (move_base_dmg + word_scaling_const * attacker_atk) * coef

	# Optional: subtract defense before armor
	raw_damage = max(0.0, raw_damage - defenders_def)

	# ARMOR MITIGATION 
	var armor_mult: float = 100.0 / (100.0 + max(0.0, defenders_armor))
	var after_armor: float = raw_damage * armor_mult

	# CRIT
	var is_crit := false
	if attacker_crit > 0.0:
		var roll_crit := rng.randf()
		is_crit = roll_crit < attacker_crit

	var final_float: float = after_armor * (attacker_crit_mult if is_crit else 1.0)

	var final_damage: int = int(round(final_float))
	final_damage = max(0, final_damage)

	return {
		"hit": true,
		"damage": final_damage,
		"is_crit": is_crit,
		"raw_damage": raw_damage,
		"post_mitigation": final_float,
		"debug": "raw=%.2f armor_mult=%.3f crit=%s final=%d" % [
			raw_damage, armor_mult, str(is_crit), final_damage
		]
	}

static func apply_damage(current_hp: int, damage: int) -> int:
	return max(0, current_hp - max(0, damage))
