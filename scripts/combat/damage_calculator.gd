class_name DamageCalculator
extends Node
## Turns a validated word into damage. Combines every factor the
## design calls for -- letter power (classes, modifiers, levels),
## drawn-versus-undrawn letters, word length, part of speech, and
## WordNet semantic similarity to the enemy's tags -- and returns
## a full breakdown so the debug overlay can show its work.

# Undrawn letters contribute only a sliver of their base power.
const UNDRAWN_POWER_FACTOR: float = 0.2

# Bonus multiplier per letter beyond a three-letter word.
const LENGTH_BONUS_STEP: float = 0.1

# Damage multiplier for the word's best part of speech.
const POS_MULTIPLIERS: Dictionary[String, float] = {
	"v": 1.25,
	"a": 1.15,
	"r": 1.1,
	"n": 1.0,
}

# Raw Wu-Palmer scores sit high, so effectiveness rescales them:
# scores at or below the floor count as zero effectiveness.
const SIMILARITY_FLOOR: float = 0.35

# Semantic multiplier range from no relation to a perfect match.
const SEMANTIC_MULTIPLIER_MIN: float = 0.5
const SEMANTIC_MULTIPLIER_MAX: float = 2.0

# Effectiveness bonus per Sage-class letter used from the hand.
const SAGE_EFFECTIVENESS_BONUS: float = 0.08

# Effectiveness bonus while the Tome of Echoes relic is held.
const TOME_EFFECTIVENESS_BONUS: float = 0.08

# Gold earned per Merchant-class letter used from the hand.
const MERCHANT_GOLD: int = 2

# Fraction of dealt damage healed per Leech-class letter used.
const LEECH_HEAL_FRACTION: float = 0.05


## Scores a word against the enemy's tags.
## drawn holds the hand letters covering the word; undrawn holds
## the remaining characters. Returns the breakdown dictionary.
func calculate(
	word: String,
	drawn: Array[LetterStats],
	undrawn: Array[String],
	enemy_tags: Array[String]
) -> Dictionary:
	var letter_rows: Array[Dictionary] = []
	var base_power: float = 0.0
	for stats: LetterStats in drawn:
		var contribution: float = stats.power()
		base_power += contribution
		letter_rows.append({
			"letter": stats.letter,
			"drawn": true,
			"power": contribution,
			"stats": stats,
		})
	for character: String in undrawn:
		var fallback: int = LetterStats.BASE_POWER.get(
			character, 1
		)
		var contribution: float = \
				float(fallback) * UNDRAWN_POWER_FACTOR
		base_power += contribution
		letter_rows.append({
			"letter": character,
			"drawn": false,
			"power": contribution,
			"stats": null,
		})
	var length_multiplier: float = 1.0 + LENGTH_BONUS_STEP \
			* float(maxi(word.length() - 3, 0))
	var pos_data: Dictionary = _best_part_of_speech(word)
	var similarity: Dictionary = _best_tag_similarity(
		word, enemy_tags
	)
	var effectiveness: float = _effectiveness(
		similarity.get("score", 0.0), drawn
	)
	var semantic_multiplier: float = lerpf(
		SEMANTIC_MULTIPLIER_MIN,
		SEMANTIC_MULTIPLIER_MAX,
		effectiveness
	)
	var damage: float = base_power * length_multiplier \
			* pos_data["multiplier"] * semantic_multiplier
	return {
		"word": word,
		"damage": damage,
		"base_power": base_power,
		"letters": letter_rows,
		"drawn_count": drawn.size(),
		"undrawn_count": undrawn.size(),
		"length_multiplier": length_multiplier,
		"pos": pos_data["pos"],
		"pos_multiplier": pos_data["multiplier"],
		"similarity": similarity,
		"effectiveness": effectiveness,
		"semantic_multiplier": semantic_multiplier,
		"gold_bonus": _merchant_gold(drawn),
		"heal_amount": _leech_heal(damage, drawn),
	}


# Picks the part of speech giving the word its best multiplier.
func _best_part_of_speech(word: String) -> Dictionary:
	var best_pos: String = "n"
	var best_multiplier: float = 1.0
	for pos: String in WordNet.parts_of_speech(word):
		var multiplier: float = POS_MULTIPLIERS.get(pos, 1.0)
		if multiplier > best_multiplier:
			best_multiplier = multiplier
			best_pos = pos
	return {"pos": best_pos, "multiplier": best_multiplier}


# Scores the word against every tag and keeps the best match.
func _best_tag_similarity(
	word: String, enemy_tags: Array[String]
) -> Dictionary:
	var best: Dictionary = {
		"score": 0.0,
		"strategy": "none",
		"detail": "no tags",
		"tag": "",
	}
	for tag: String in enemy_tags:
		var result: Dictionary = WordNet.similarity_detailed(
			word, tag
		)
		if result.get("score", 0.0) >= best.get("score", 0.0):
			result["tag"] = tag
			best = result
	return best


# Remaps raw similarity to 0..1 effectiveness and applies Sage
# letter bonuses.
func _effectiveness(
	score: float, drawn: Array[LetterStats]
) -> float:
	var remapped: float = clampf(
		(score - SIMILARITY_FLOOR) / (1.0 - SIMILARITY_FLOOR),
		0.0,
		1.0
	)
	for stats: LetterStats in drawn:
		if stats.letter_class == LetterStats.LetterClass.SAGE:
			remapped += SAGE_EFFECTIVENESS_BONUS
	if RunState.relics.has("tome_of_echoes"):
		remapped += TOME_EFFECTIVENESS_BONUS
	return clampf(remapped, 0.0, 1.0)


func _merchant_gold(drawn: Array[LetterStats]) -> int:
	var total: int = 0
	for stats: LetterStats in drawn:
		if stats.letter_class == LetterStats.LetterClass.MERCHANT:
			total += MERCHANT_GOLD
	return total


func _leech_heal(
	damage: float, drawn: Array[LetterStats]
) -> int:
	var fraction: float = 0.0
	for stats: LetterStats in drawn:
		if stats.letter_class == LetterStats.LetterClass.LEECH:
			fraction += LEECH_HEAL_FRACTION
	return int(damage * fraction)
