extends Resource
class_name Word

var text: String
var letters: Array[Letter] = []

var total_multiplier := 1.0
var dominant_element := Letter.Element.NONE
var base_damage := 0

func _init(word_text: String, used_letters: Array[Letter]):
	text = word_text
	letters = used_letters
	_calculate_stats()

func _calculate_stats() -> void:
	base_damage = letters.size()
	total_multiplier = 1.0

	var element_counts := {}

	for letter in letters:
		total_multiplier *= letter.base_multiplier
		total_multiplier *= letter.rarity_multiplier

		if letter.element != Letter.Element.NONE:
			element_counts[letter.element] = element_counts.get(letter.element, 0) + 1

	dominant_element = _get_dominant_element(element_counts)

func _get_dominant_element(counts: Dictionary) -> Letter.Element:
	var max_count := 0
	var chosen := Letter.Element.NONE

	for element in counts.keys():
		if counts[element] > max_count:
			max_count = counts[element]
			chosen = element

	return chosen

func get_final_damage() -> int:
	return int(base_damage * total_multiplier)
