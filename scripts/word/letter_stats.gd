class_name LetterStats
extends Resource
## One letter character in the player's deck. Letters level up,
## take on a class, and carry a modifier; all three feed the damage
## calculation and the tavern economy.

## Combat classes a letter can be trained into.
enum LetterClass {
	NONE,
	## Bonus flat power on every use.
	STRIKER,
	## Amplifies the semantic similarity multiplier.
	SAGE,
	## Earns gold whenever used in a word.
	MERCHANT,
	## Heals the player for part of the damage dealt.
	LEECH,
}

## Forge modifiers a letter can carry.
enum Modifier {
	NONE,
	## Doubles this letter's power contribution.
	KEEN,
	## Earns 1 gold when drawn into the hand.
	GILDED,
	## Adds flat bonus power on every use.
	HEAVY,
}

# Scrabble-style base power for each letter.
const BASE_POWER: Dictionary[String, int] = {
	"a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2,
	"h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1,
	"o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1,
	"v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
}

# Additional power multiplier gained per level past 1.
const LEVEL_POWER_STEP: float = 0.25

@export var letter: String = "a"
@export var level: int = 1
@export var letter_class: LetterClass = LetterClass.NONE
@export var modifier: Modifier = Modifier.NONE


static func create(new_letter: String) -> LetterStats:
	var stats: LetterStats = LetterStats.new()
	stats.letter = new_letter.to_lower()
	return stats


## Power this letter contributes when used in a word.
func power() -> float:
	var base: int = BASE_POWER.get(letter, 1)
	var level_bonus: float = 1.0 \
			+ LEVEL_POWER_STEP * float(level - 1)
	var amount: float = float(base) * level_bonus
	if letter_class == LetterClass.STRIKER:
		amount += 2.0
	if modifier == Modifier.HEAVY:
		amount += 4.0
	if modifier == Modifier.KEEN:
		amount *= 2.0
	return amount


## Short label such as "R Lv2 Sage [Keen]" for tooltips and shops.
func describe() -> String:
	var text: String = "%s Lv%d" % [letter.to_upper(), level]
	if letter_class != LetterClass.NONE:
		text += " " + class_name_text()
	if modifier != Modifier.NONE:
		text += " [" + modifier_name_text() + "]"
	return text


func class_name_text() -> String:
	return LetterClass.keys()[letter_class].capitalize()


func modifier_name_text() -> String:
	return Modifier.keys()[modifier].capitalize()
