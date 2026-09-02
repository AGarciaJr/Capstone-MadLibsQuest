extends Node
class_name WordValidator

@onready var word_dict: Dictionary = RunState.get_word_dict()

func _ready() -> void:
	# Incoming
	Signals.text_sent.connect(is_valid_word)

func is_valid_word(text: String):
	"""
	Signals that word is validated with the new word
	OR
	Signals that the word is invalid
	"""
	if is_in_dict(text) \
	and matches_part_of_speech(text, WordDictionary.SpeechPart.Verb):
		var new_word = create_word(text)
		Signals.emit_word_validated(new_word)
	else:
		Signals.emit_text_invalidated(text)

func is_in_dict(text: String) -> bool:
	return word_dict.has(text.to_lower())

func matches_part_of_speech(
	text: String, 
	part_of_speech: WordDictionary.SpeechPart
) -> bool:
	return word_dict.get(text.to_lower()) == part_of_speech

func create_word(text: String) -> Word:
	var letters := RunState.inventory.consume_letters_for(text)
	var word := Word.new(text, letters)
	# Debug
	#print("Word validated and created")
	#print(word.text, " damage: ", word.get_final_damage())
	#print("Element: ", word.dominant_element)
	#print("Letters: ", word.letters)
	return word
