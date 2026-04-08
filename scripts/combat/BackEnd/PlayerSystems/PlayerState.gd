extends Node

signal player_letters_changed(letters: PackedStringArray)

var max_hp: int = 100
var current_hp: int = 100

var stats: Dictionary = {
	"atk": 7,
	"crit_chance": 0.10,
	"crit_mult": 1.5,
	"def": 2,
	"armor": 2,
}

var player_letters: PackedStringArray = PackedStringArray(["A", "E", "S", "T" , "O"])
var initial_player_letters: PackedStringArray = PackedStringArray()
var letter_bonus_per_match: float = 0.05
var letter_bonus_all_letters_extra: float = 2.0
var letter_bonus_cap: float = 99.0
var player_name: String = ""
var current_run_score: int = 0

var letter_limit: int = 6

var inventory: Array[Dictionary] = []

func reset_to_defaults() -> void:
	max_hp = 100
	current_hp = max_hp
	stats = {
		"atk": 10,
		"crit_chance": 0.10,
		"crit_mult": 1.5,
		"def": 2,
		"armor": 2,
	}
	player_letters = initial_player_letters.duplicate()
	letter_limit = 6
	letter_bonus_per_match = 0.05
	letter_bonus_all_letters_extra = 2.0
	letter_bonus_cap = 99.0
	player_name = ""
	inventory.clear()
	player_letters_changed.emit(player_letters)
	current_run_score = 0

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

func set_player_letters(letters: PackedStringArray) -> void:
	player_letters = letters
	player_letters_changed.emit(player_letters)
	
func set_initial_player_letters(letters: PackedStringArray) -> void:
	initial_player_letters = letters.duplicate()
	player_letters = letters.duplicate()
	player_letters_changed.emit(player_letters)

func add_player_letter(letter: String) -> void:
	var up := letter.to_upper()
	if up.length() == 1 and up in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		player_letters.append(up)
		player_letters_changed.emit(player_letters)

func add_random_player_letters(count: int, rng: RandomNumberGenerator = null) -> PackedStringArray:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var added: PackedStringArray = PackedStringArray()
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	for _i in range(max(0, count)):
		var idx: int = rng.randi_range(0, alphabet.length() - 1)
		var letter: String = alphabet.substr(idx, 1)
		add_player_letter(letter)
		added.append(letter)

	return added

func modify_letter_bonus_power(extra_per_match: float) -> void:
	letter_bonus_per_match += extra_per_match


## Damage coefficient from featured letters (same math as battle → TurnResolver `letter_bonus_mult`).
## Uses `letter_bonus_per_match` per distinct featured letter present in `word`, plus `letter_bonus_all_letters_extra` when all are used, clamped by `letter_bonus_cap`.
func letter_bonus_multiplier_for_word(word: String) -> float:
	if player_letters.is_empty():
		return 1.0
	var w := word.to_upper()
	var match_count := 0
	for letter in player_letters:
		if w.contains(letter):
			match_count += 1
	var bonus := float(match_count) * letter_bonus_per_match
	if match_count == player_letters.size():
		bonus += letter_bonus_all_letters_extra
	bonus = clampf(bonus, 0.0, letter_bonus_cap)
	return 1.0 + bonus


func add_letter_limit(amount: int) -> void:
	letter_limit = max(1, letter_limit + amount)
