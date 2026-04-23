extends Control

@onready var close_button: Button = $NotebookPanel/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var letter_label: Label = $NotebookPanel/MarginContainer/VBoxContainer/PortraitPlaceholder/LetterLabel
@onready var level_label: Label = $NotebookPanel/MarginContainer/VBoxContainer/StatsContainer/LevelLabel
@onready var xp_bar: ProgressBar = $NotebookPanel/MarginContainer/VBoxContainer/StatsContainer/XPBar
@onready var xp_text: Label = $NotebookPanel/MarginContainer/VBoxContainer/StatsContainer/XPText
@onready var used_label: Label = $NotebookPanel/MarginContainer/VBoxContainer/StatsContainer/UsedLabel
@onready var prev_button: Button = $NotebookPanel/MarginContainer/VBoxContainer/NavRow/PrevButton
@onready var next_button: Button = $NotebookPanel/MarginContainer/VBoxContainer/NavRow/NextButton
@onready var page_indicator: Label = $NotebookPanel/MarginContainer/VBoxContainer/NavRow/PageIndicator

var _current_page: int = 1
var _sorted_letters: Array = []

func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_notebook)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)

func _exit_tree() -> void:
	MouseModeStack.pop(self)
	InputBlocker.pop(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()
		
func toggle() -> void:
	if visible:
		hide_notebook()
	else: 
		show_notebook()

func show_notebook() -> void:
	if InputBlocker.is_blocked():
		return
	
	_rebuild_letter_list()
	if _sorted_letters.is_empty():
		return
	
	_current_page = clampi(_current_page, 1, _sorted_letters.size())
	_refresh_page()
	MouseModeStack.push(self, Input.MOUSE_MODE_VISIBLE)
	InputBlocker.push(self)
	visible = true

func hide_notebook() -> void:
	visible = false
	MouseModeStack.pop(self)
	InputBlocker.pop(self)

func _rebuild_letter_list() -> void:
	_sorted_letters = Array(PlayerState.player_letters)
	_sorted_letters.sort()

func _on_prev_pressed() -> void:
	if _current_page > 1:
		_current_page = _current_page - 1
		_refresh_page()

func _on_next_pressed() -> void:
	if _current_page < _sorted_letters.size():
		_current_page = _current_page + 1
		_refresh_page()


func _refresh_page() -> void:
	if _sorted_letters.is_empty():
		letter_label.text = ""
		level_label.text = "No letters"
		xp_bar.value = 0
		xp_text.text = ""
		used_label.text = ""
		page_indicator.text = "0/0"
		prev_button.disabled = true
		next_button.disabled = true
		return
	
	var letter: String = _sorted_letters[_current_page - 1]
	letter_label.text = letter
	
	var level := PlayerState.get_letter_level(letter)
	level_label.text = "Level %d" % level
	
	var data: Dictionary = PlayerState.letters_data.get(letter, {})
	var xp := int(data.get("xp", 0))
	var times_used := int(data.get("times_used", 0))
	
	if level >= PlayerState.MAX_LETTER_LEVEL:
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_text.text = "MAX"
	else:
		xp_bar.max_value = PlayerState.XP_PER_LEVEL
		xp_bar.value = xp
		xp_text.text = "%d / %d XP" % [xp, PlayerState.XP_PER_LEVEL]
	
	used_label.text = "Times used: %d" % times_used
	page_indicator.text = "%d / %d" % [_current_page, _sorted_letters.size()]
	
	prev_button.disabled = _current_page <= 1
	next_button.disabled = _current_page >= _sorted_letters.size()
	
