extends Node
class_name Inventory

var letters: Array[Letter] = []

func _ready() -> void:
	# Receive
	Signals.letter_chosen.connect(add_letter)

func add_letter(letter: Letter) -> void:
	letters.append(letter)
	Signals.emit_inventory_updated(letters)

func remove_letter(letter: Letter) -> void:
	letters.erase(letter)
	Signals.emit_inventory_updated(letters)

func has_letters_for(word: String) -> bool:
	var temp := letters.map(func(l): return l.char)
	
	for c in word:
		if not temp.has(c):
			return false
		temp.erase(c)

	return true

func consume_letters_for(text: String) -> Array[Letter]:
	var used: Array[Letter] = []
	for c in text:
		for letter in letters:
			if letter.character == c:
				used.append(letter)
				# letters.erase(letter)
				# break
	return used

func _get_counts() -> Dictionary:
	var counts := {}
	for letter in letters:
		counts[letter.char] = counts.get(letter.char, 0) + 1
	return counts
