extends Node

var max_hp: int = 100
var current_hp: int = 100

var stats: Dictionary = {
	"atk": 10,
	"crit_chance": 0.10,
	"crit_mult": 1.5,
	"def": 0,
	"armor": 0,
}

var bonus_letters: PackedStringArray = PackedStringArray(["A", "E", "S", "T"])
var letter_bonus_per_match: float = 0.05
var letter_bonus_all_letters_extra: float = 0.15
var letter_bonus_cap: float = 0.50

var inventory: Array[Dictionary] = []

func reset_to_defaults() -> void:
	max_hp = 100
	current_hp = max_hp
	stats = {
		"atk": 10,
		"crit_chance": 0.10,
		"crit_mult": 1.5,
		"def": 0,
		"armor": 0,
	}
	bonus_letters = PackedStringArray(["A", "E", "S", "T"])
	letter_bonus_per_match = 0.05
	letter_bonus_all_letters_extra = 0.15
	letter_bonus_cap = 0.50
	inventory.clear()

func apply_damage(dmg: int) -> void:
	current_hp = max(0, current_hp - max(0, dmg))

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + max(0, amount))

func apply_stat_mod(flat: Dictionary, mult: Dictionary) -> void:
	for k in flat.keys():
		var key := String(k)
		stats[key] = float(stats.get(key, 0.0)) + float(flat[key])
	for k2 in mult.keys():
		var key2 := String(k2)
		stats[key2] = float(stats.get(key2, 0.0)) * float(mult[key2])

func add_bonus_letter(letter: String) -> void:
	var up := letter.to_upper()
	if up.length() == 1 and up in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		bonus_letters.append(up)

func add_random_bonus_letters(count: int, rng: RandomNumberGenerator = null) -> PackedStringArray:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var added: PackedStringArray = PackedStringArray()
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	for _i in range(max(0, count)):
		var idx: int = rng.randi_range(0, alphabet.length() - 1)
		var letter: String = alphabet.substr(idx, 1)
		add_bonus_letter(letter)
		added.append(letter)

	return added

func modify_bonus_letter_power(extra_per_match: float) -> void:
	letter_bonus_per_match += extra_per_match
