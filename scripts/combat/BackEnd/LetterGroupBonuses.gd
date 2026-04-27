extends RefCounted
class_name LetterGroupBonuses

## Bonus-letter groups: effects apply only when the letter appears in the word AND the player owns it (bonus letters).
## Themes / roster tint (RGBA, last channel = highlight alpha on roster cards).

const VOWELS := "AEIOU"
const COMMON_KNIGHTS := "NRTLSDG" ## N, R, T, L, S, D, G
const RARE_SCHOLARS := "BCFHMPVW"
const VERY_RARE_ROYALTY := "YKJQXZ"

const GROUP_THEME_VOWEL := "Jesters"
const GROUP_THEME_COMMON := "Knights"
const GROUP_THEME_RARE := "Scholars"
const GROUP_THEME_VERY_RARE := "Royalty"

const HIGHLIGHT_VOWEL := Color(1.0, 1.0, 1.0, 0.38)
const HIGHLIGHT_COMMON := Color(0.28, 0.88, 0.42, 0.38)
const HIGHLIGHT_RARE := Color(0.35, 0.55, 1.0, 0.38)
const HIGHLIGHT_VERY_RARE := Color(0.92, 0.78, 0.22, 0.42)


static func highlight_color_for_bonus_letter(letter: String) -> Color:
	var u := String(letter).to_upper()
	if u.length() != 1:
		return Color(0.3, 0.5, 1.0, 0.25)
	if VOWELS.contains(u):
		return HIGHLIGHT_VOWEL
	if COMMON_KNIGHTS.contains(u):
		return HIGHLIGHT_COMMON
	if RARE_SCHOLARS.contains(u):
		return HIGHLIGHT_RARE
	if VERY_RARE_ROYALTY.contains(u):
		return HIGHLIGHT_VERY_RARE
	return Color(0.3, 0.5, 1.0, 0.25)


static func _owned_letter_set(player_letters: PackedStringArray) -> Dictionary:
	var d: Dictionary = {}
	for j in player_letters.size():
		var s := String(player_letters[j]).to_upper()
		if s.length() == 1:
			d[s] = true
	return d


## Counts each word character that is both in `player_letters` and in a letter group (per occurrence).
static func compute_strike_bonuses(
	word: String,
	player_letters: PackedStringArray,
	enemy_max_hp: int,
	player_max_hp: int,
) -> Dictionary:
	var owned := _owned_letter_set(player_letters)
	var w := word.to_upper()
	var vowel_n := 0
	var common_n := 0
	var rare_n := 0
	var very_rare_n := 0
	for i in w.length():
		var ch: String = w.substr(i, 1)
		if not owned.has(ch):
			continue
		if VOWELS.contains(ch):
			vowel_n += 1
		elif COMMON_KNIGHTS.contains(ch):
			common_n += 1
		elif RARE_SCHOLARS.contains(ch):
			rare_n += 1
		elif VERY_RARE_ROYALTY.contains(ch):
			very_rare_n += 1

	var flat_from_knights_royalty: int = common_n * 2 + very_rare_n * 10
	var rare_damage: int = int(floor(float(enemy_max_hp) * 0.05 * float(rare_n)))
	var vowel_heal: int = int(floor(float(player_max_hp) * 0.02 * float(vowel_n)))

	return {
		"vowel_count": vowel_n,
		"common_count": common_n,
		"rare_count": rare_n,
		"very_rare_count": very_rare_n,
		"vowel_heal": vowel_heal,
		"flat_damage_add": flat_from_knights_royalty,
		"flat_base_damage_bonus": flat_from_knights_royalty,
		"rare_max_hp_damage": rare_damage,
	}
