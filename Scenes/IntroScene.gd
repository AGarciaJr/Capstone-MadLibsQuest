extends Control
## All-text intro scene - The player meets the Bard and plays their first Mad Lib.

signal intro_completed

# UI References
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var narrative_label: RichTextLabel = $VBoxContainer/NarrativeLabel
@onready var bard_speech_label: RichTextLabel = $VBoxContainer/BardSpeechLabel
@onready var input_container: HBoxContainer = $VBoxContainer/InputContainer
@onready var prompt_label: Label = $VBoxContainer/InputContainer/PromptLabel
@onready var word_input: LineEdit = $VBoxContainer/InputContainer/WordInput
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var continue_label: Label = $VBoxContainer/ContinueLabel
@onready var typewriter_timer: Timer = $TypewriterTimer

# The Bard instance (created in code since this is text-only)
var bard: Bard

# Intro narrative texts
var intro_texts := [
	"The world... is broken.",
	"Words have lost their meaning...",
	"Reality itself has become... incomplete.",
	"But you have arrived.",
	"Perhaps you can help restore what was lost.",
	"",
	"A figure emerges from the mist..."
]

# State machine
enum State { INTRO_NARRATIVE, BARD_GREETING, COLLECTING_WORDS, SHOWING_RESULT, COMPLETE }
var current_state: State = State.INTRO_NARRATIVE

var current_intro_index: int = 0
var current_text: String = ""
var target_text: String = ""
var char_index: int = 0

# Mad Libs state
var current_prompt: Dictionary = {}
var current_blanks: Array = []
var collected_words: Array = []
var current_blank_index: int = 0


func _ready() -> void:
	# Create the Bard instance
	bard = Bard.new()
	add_child(bard)
	
	# Connect signals
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	word_input.text_submitted.connect(_on_word_submitted)
	
	# Hide input initially
	input_container.visible = false
	continue_label.text = ""
	hint_label.text = ""
	
	# Start the intro sequence
	await get_tree().create_timer(1.0).timeout
	_start_intro_narrative()

func _refocus_input() -> void:
	word_input.release_focus()
	word_input.grab_focus()

func _start_intro_narrative() -> void:
	current_state = State.INTRO_NARRATIVE
	current_intro_index = 0
	_show_next_intro_text()


func _show_next_intro_text() -> void:
	if current_intro_index >= intro_texts.size():
		# Intro complete, move to bard greeting
		await get_tree().create_timer(1.0).timeout
		_start_bard_greeting()
		return
	
	var text = intro_texts[current_intro_index]
	if text == "":
		# Empty line = pause
		current_intro_index += 1
		await get_tree().create_timer(1.5).timeout
		_show_next_intro_text()
		return
	
	_typewrite_to_label(narrative_label, "[center][color=#aaaaaa][i]" + text + "[/i][/color][/center]")
	continue_label.text = "[Press SPACE to continue]"


func _start_bard_greeting() -> void:
	current_state = State.BARD_GREETING
	narrative_label.text = ""
	continue_label.text = ""
	
	# Show bard introduction
	var bard_intro = "[center][color=#d4a574][b]~ The Bard ~[/b][/color][/center]\n\n"
	bard_intro += "[color=#88aa88]\"Ah! At last, someone who can hear me![/color]\n\n"
	bard_intro += "[color=#88aa88]I am the Bard, keeper of stories in this fractured realm.[/color]\n\n"
	bard_intro += "[color=#88aa88]The world has lost its words, friend. Everything is... incomplete.[/color]\n\n"
	bard_intro += "[color=#88aa88]But together, we can restore it. Will you help me fill in the blanks?\"[/color]"
	
	_typewrite_to_label(bard_speech_label, bard_intro)
	continue_label.text = "[Press SPACE to begin]"


func _start_mad_lib() -> void:
	current_state = State.COLLECTING_WORDS
	bard_speech_label.text = ""
	continue_label.text = ""
	
	# Get the intro greeting prompt from the Bard
	current_prompt = bard.start_dialogue("intro_greeting")
	
	if current_prompt.is_empty():
		push_error("Could not load bard dialogue!")
		return
	
	current_blanks = current_prompt.get("blanks", [])
	collected_words.clear()
	current_blank_index = 0
	
	# Show title
	narrative_label.text = "[center][color=#d4a574]~ " + current_prompt.get("title", "Mad Lib") + " ~[/color][/center]"
	
	_show_next_blank_prompt()


func _show_next_blank_prompt() -> void:
	if current_blank_index >= current_blanks.size():
		# All words collected, show the result
		_show_mad_lib_result()
		return
	
	var blank = current_blanks[current_blank_index]
	var word_type: String = blank.get("type", "word")
	var hint: String = blank.get("hint", "")
	
	# Format the word type for display
	var type_display = word_type.replace("_", " ").capitalize()
	
	# Show the prompt
	prompt_label.text = "Enter " + _get_article(type_display) + " " + type_display + ":"
	hint_label.text = "Hint: " + hint if hint else ""
	
	# Show and focus input
	input_container.visible = true
	word_input.text = ""
	_refocus_input()
	
	# Update bard speech
	var remaining = current_blanks.size() - current_blank_index
	bard_speech_label.text = "[color=#88aa88]\"" + str(remaining) + " word(s) remaining...\"[/color]"


func _on_word_submitted(word: String) -> void:
	if word.strip_edges().is_empty():
		return
	
	var cleaned_word := word.strip_edges()
	var blank : Dictionary = current_blanks[current_blank_index]
	var expected_pos: String = blank.get("type", "noun")
	
	# Validate the word using the Bard (which uses WordNet if available)
	var validation := bard.validate_word(cleaned_word, expected_pos)
	
	if not validation.valid:
		# Word doesn't match expected POS - show feedback
		_show_validation_error(validation.feedback, validation.hint)
		word_input.text = ""
		word_input.grab_focus()
		return
	
	# Word is valid! Show positive feedback briefly
	if not validation.feedback.is_empty():
		bard_speech_label.text = "[color=#88dd88]\"" + validation.feedback + "\"[/color]"
	
	# Store the word
	collected_words.append(cleaned_word)
	current_blank_index += 1
	
	# Brief pause to show feedback, then move to next
	await get_tree().create_timer(0.4).timeout
	
	# Clear input and move to next
	word_input.text = ""
	_show_next_blank_prompt()


func _show_validation_error(bard_response: String, hint: String) -> void:
	# Show the Bard's response and the hint
	var error_text := "[color=#dd8888]\"" + bard_response + "\"[/color]"
	if not hint.is_empty():
		error_text += "\n[color=#aaaaaa][i]" + hint + "[/i][/color]"
	
	bard_speech_label.text = error_text
	
	# Shake the input field for feedback
	var original_pos := input_container.position
	var tween := create_tween()
	tween.tween_property(input_container, "position:x", original_pos.x + 5, 0.05)
	tween.tween_property(input_container, "position:x", original_pos.x - 5, 0.05)
	tween.tween_property(input_container, "position:x", original_pos.x + 3, 0.05)
	tween.tween_property(input_container, "position:x", original_pos.x, 0.05)


func _show_mad_lib_result() -> void:
	current_state = State.SHOWING_RESULT
	input_container.visible = false
	hint_label.text = ""
	
	# Get the completed text from the Bard
	var result = bard.complete_mad_lib("intro_greeting", collected_words)
	
	# Show the result with fanfare
	narrative_label.text = "[center][color=#d4a574][b]~ Your Story ~[/b][/color][/center]"
	
	var formatted_result = "\n\n[center][color=#ccddcc]" + result + "[/color][/center]"
	_typewrite_to_label(bard_speech_label, formatted_result)
	
	continue_label.text = "[Press SPACE to continue your adventure]"


func _complete_intro() -> void:
	current_state = State.COMPLETE
	bard_speech_label.text = ""
	narrative_label.text = ""
	
	var final_text = "[center][color=#d4a574][b]And so your journey begins...[/b][/color][/center]\n\n"
	final_text += "[center][color=#88aa88]The Bard smiles and gestures toward the misty path ahead.[/color][/center]\n\n"
	final_text += "[center][color=#aaaaaa][i]The world awaits your words.[/i][/color][/center]"
	
	_typewrite_to_label(narrative_label, final_text)
	continue_label.text = ""
	
	await get_tree().create_timer(4.0).timeout
	intro_completed.emit()
	
	# Transition to the tutorial area
	SceneTransition.change_scene("res://Scenes/LetterSelection.tscn", 1.5)


# Typewriter effect system
func _typewrite_to_label(label: RichTextLabel, text: String) -> void:
	target_text = text
	current_text = ""
	char_index = 0
	label.text = ""
	typewriter_timer.start()


func _on_typewriter_tick() -> void:
	if char_index >= target_text.length():
		typewriter_timer.stop()
		return
	
	# Skip BBCode tags instantly
	if target_text[char_index] == '[':
		var end_bracket = target_text.find(']', char_index)
		if end_bracket != -1:
			current_text += target_text.substr(char_index, end_bracket - char_index + 1)
			char_index = end_bracket + 1
		else:
			current_text += target_text[char_index]
			char_index += 1
	else:
		current_text += target_text[char_index]
		char_index += 1
	
	# Update the appropriate label based on current state
	match current_state:
		State.INTRO_NARRATIVE:
			narrative_label.text = current_text
		State.BARD_GREETING:
			bard_speech_label.text = current_text
		State.SHOWING_RESULT:
			bard_speech_label.text = current_text
		State.COMPLETE:
			narrative_label.text = current_text


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
		match current_state:
			State.INTRO_NARRATIVE:
				if typewriter_timer.is_stopped():
					# Move to next intro text
					current_intro_index += 1
					_show_next_intro_text()
				else:
					# Skip typewriter, show full text
					typewriter_timer.stop()
					narrative_label.text = target_text
			
			State.BARD_GREETING:
				if typewriter_timer.is_stopped():
					_start_mad_lib()
				else:
					typewriter_timer.stop()
					bard_speech_label.text = target_text
			
			State.SHOWING_RESULT:
				if typewriter_timer.is_stopped():
					_complete_intro()
				else:
					typewriter_timer.stop()
					bard_speech_label.text = target_text
			
			State.COLLECTING_WORDS:
				# Input handles this
				pass


# Helper function for grammar
func _get_article(word: String) -> String:
	var first_letter = word.to_lower()[0] if word.length() > 0 else ""
	if first_letter in ["a", "e", "i", "o", "u"]:
		return "an"
	return "a"
