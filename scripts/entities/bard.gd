class_name Bard
extends CharacterBody2D
## The Bard - A mystical storyteller who guides players through Mad Libs adventures.
## Handles dialogue, word collection, and story completion.

signal dialogue_started
signal dialogue_ended
signal word_validated(word: String, is_valid: bool, hint: String)
signal mad_lib_completed(result: String)

# Dialogue templates - each has a title, template text with {0}, {1} placeholders, and blank definitions
var dialogue_templates := {
	"intro_greeting": {
		"title": "A Hero's Welcome",
		"template": "Greetings, {0} traveler! I see you carry a {1} and wear a look of {2} determination. Perhaps you've come seeking {3}? Many {4} adventurers have passed through here, but none quite as {5} as you!",
		"blanks": [
			{"type": "adjective", "hint": "Describe yourself - brave? weary? curious?"},
			{"type": "noun", "hint": "What item might a traveler carry?"},
			{"type": "adjective", "hint": "How determined are you?"},
			{"type": "noun", "hint": "What do heroes seek? Glory? Treasure? Knowledge?"},
			{"type": "adjective", "hint": "What kind of adventurers?"},
			{"type": "adjective", "hint": "What makes you unique?"}
		]
	},
	"tutorial_story": {
		"title": "The Broken Bridge",
		"template": "Once upon a time, a {0} bridge connected two {1} kingdoms. But one {2} night, a {3} creature appeared and {4} destroyed it! Now the villagers must {5} across the {6} river. Perhaps a {7} hero could help?",
		"blanks": [
			{"type": "adjective", "hint": "Describe the bridge"},
			{"type": "adjective", "hint": "What kind of kingdoms?"},
			{"type": "adjective", "hint": "What kind of night was it?"},
			{"type": "adjective", "hint": "Describe the creature"},
			{"type": "adverb", "hint": "How did it destroy the bridge?"},
			{"type": "verb", "hint": "How do they cross now?"},
			{"type": "adjective", "hint": "Describe the river"},
			{"type": "adjective", "hint": "What kind of hero?"}
		]
	},
	"victory_tale": {
		"title": "The Hero's Triumph",
		"template": "And so the {0} hero {1} defeated the {2} villain! The crowd cheered {3} as {4} rained from the sky. Our hero felt {5} and vowed to always {6} those in need.",
		"blanks": [
			{"type": "adjective", "hint": "Describe the hero"},
			{"type": "adverb", "hint": "How did they defeat the villain?"},
			{"type": "adjective", "hint": "Describe the villain"},
			{"type": "adverb", "hint": "How did the crowd cheer?"},
			{"type": "noun", "hint": "What celebration item?"},
			{"type": "adjective", "hint": "How did the hero feel?"},
			{"type": "verb", "hint": "What will the hero do?"}
		]
	}
}

# Bard's responses when player enters wrong word type
var wrong_word_responses := [
	"Hmm, that doesn't quite fit the story, friend...",
	"Woah there! That's not quite right!",
	"My quill hesitates... try a different type of word!",
	"The magic words resist! Perhaps another choice?",
	"Ah, the story rejects that word. What else have you got?",
	"That word's magic doesn't match. Try again!",
]

# Bard's responses when word is valid
var correct_word_responses := [
	"Splendid!",
	"Ah, perfect!",
	"The words sing!",
	"Marvelous choice!",
	"Yes, yes!",
	"The story approves!",
]

# State
var is_in_dialogue: bool = false
var current_dialogue_key: String = ""
var current_collected_words: Array[String] = []

# Reference to WordNet (will be set if available)
var wordnet: Node = null


func _ready() -> void:
	# Try to get WordNet autoload
	wordnet = get_node_or_null("/root/WordNet")
	if wordnet:
		print("[Bard] WordNet service connected!")
	else:
		print("[Bard] WordNet not available - word validation disabled")


## Start a dialogue/mad lib sequence. Returns the prompt data.
func start_dialogue(dialogue_key: String) -> Dictionary:
	if not dialogue_templates.has(dialogue_key):
		push_error("Unknown dialogue key: " + dialogue_key)
		return {}
	
	is_in_dialogue = true
	current_dialogue_key = dialogue_key
	current_collected_words.clear()
	
	dialogue_started.emit()
	
	return dialogue_templates[dialogue_key]


## Validate a word against the expected part of speech.
## Returns a dictionary with "valid" (bool) and "hint" (String) keys.
func validate_word(word: String, expected_pos: String) -> Dictionary:
	var result := {"valid": true, "hint": "", "feedback": ""}
	
	if word.strip_edges().is_empty():
		result.valid = false
		result.hint = "Please enter a word!"
		return result
	
	# If WordNet is available, use it for validation
	if wordnet and wordnet.has_method("ValidatePos"):
		var is_valid: bool = wordnet.ValidatePos(word, expected_pos)
		
		if is_valid:
			result.valid = true
			result.feedback = correct_word_responses[randi() % correct_word_responses.size()]
		else:
			result.valid = false
			# Get a helpful hint about what the word actually is
			if wordnet.has_method("GetPosHint"):
				result.hint = wordnet.GetPosHint(word, expected_pos)
			else:
				result.hint = "That's not " + _get_article(expected_pos) + " " + expected_pos + "."
			result.feedback = wrong_word_responses[randi() % wrong_word_responses.size()]
	else:
		# No WordNet - accept all words
		result.valid = true
		result.feedback = correct_word_responses[randi() % correct_word_responses.size()]
	
	word_validated.emit(word, result.valid, result.hint)
	return result


## Complete the mad lib with the collected words and return the finished story.
func complete_mad_lib(dialogue_key: String, words: Array) -> String:
	if not dialogue_templates.has(dialogue_key):
		return "Error: Unknown dialogue"
	
	var template: String = dialogue_templates[dialogue_key].get("template", "")
	var result := template
	
	# Replace placeholders with collected words
	for i in range(words.size()):
		var placeholder := "{" + str(i) + "}"
		var word: String = words[i] if i < words.size() else "???"
		# Highlight the player's words in the result
		result = result.replace(placeholder, "[color=#ffdd88][b]" + word + "[/b][/color]")
	
	is_in_dialogue = false
	current_dialogue_key = ""
	
	dialogue_ended.emit()
	mad_lib_completed.emit(result)
	
	return result


## Get a random Bard quip for various situations
func get_waiting_quip() -> String:
	var quips := [
		"Take your time, the story will wait...",
		"Words have power, choose wisely!",
		"What wonders will you weave?",
		"The blank page yearns for your creativity!",
	]
	return quips[randi() % quips.size()]


## Get article (a/an) for a word
func _get_article(word: String) -> String:
	if word.is_empty():
		return "a"
	var first_letter := word.to_lower()[0]
	if first_letter in ["a", "e", "i", "o", "u"]:
		return "an"
	return "a"


## Format a POS type for display (e.g., "verb_past" -> "Verb (Past Tense)")
func format_pos_display(pos_type: String) -> String:
	match pos_type:
		"noun":
			return "Noun"
		"noun_plural":
			return "Noun (Plural)"
		"verb":
			return "Verb"
		"verb_past":
			return "Verb (Past Tense)"
		"verb_ing":
			return "Verb (-ing form)"
		"adjective", "adj":
			return "Adjective"
		"adverb", "adv":
			return "Adverb"
		_:
			return pos_type.replace("_", " ").capitalize()
