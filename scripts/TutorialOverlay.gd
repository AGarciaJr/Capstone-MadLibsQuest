extends Control

@onready var popup_panel: Control = $PopupPanel
@onready var message_label: RichTextLabel = $PopupPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var continue_button: Button = $PopupPanel/MarginContainer/VBoxContainer/ContinueButton

@export var scene_name: String = ""
var _waiting_for_word: bool = false


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)

	if not TutorialState.is_active():
		return
		
	if scene_name == "battle":
		var battle_root = get_tree().current_scene
		if battle_root and battle_root.has_signal("word_submitted"):
			battle_root.word_submitted.connect(func(_w): on_word_submitted())
	
	call_deferred("_try_show_step")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var step := TutorialState.get_current_step()
			var wait_for: String = step.get("wait_for", "click")
			if wait_for == "click" and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
				_on_continue_pressed()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not TutorialState.is_active():
		return
	
	var step := TutorialState.get_current_step()
	if step.is_empty():
		return
	
	var wait_for: String = step.get("wait_for", "click")
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Weird workaround I know, maybe someone can come up with a better solution/system
		if wait_for == "key_m" and event.keycode == KEY_M:
			get_viewport().set_input_as_handled()
			# Pop ourselves from blocker so map can open
			InputBlocker.pop(self)
			MouseModeStack.pop(self)
			
			# Trigger the map open manually
			var room = get_tree().current_scene
			if room and room.has_method("_toggle_map_overlay"):
				room._toggle_map_overlay()
			_dismiss_and_advance_no_pop()



func _try_show_step() -> void:
	if not TutorialState.has_step_for_scene(scene_name):
		return
	_show_current_step()


func _show_current_step() -> void:
	var step := TutorialState.get_current_step()
	if step.is_empty():
		return

	var wait_for: String = step.get("wait_for", "click")
	
	if wait_for == "word_submit":
		_waiting_for_word = true
		visible = false
		return
	
	message_label.text = step["text"]

	if wait_for == "click":
		continue_button.visible = true
		continue_button.text = "Continue"
		InputBlocker.push(self)
		MouseModeStack.push(self, Input.MOUSE_MODE_VISIBLE)
	elif wait_for == "key_m":
		continue_button.visible = false
		InputBlocker.push(self)
		MouseModeStack.push(self, Input.MOUSE_MODE_VISIBLE)
	else:
		continue_button.visible = false

	visible = true
	if continue_button.visible:
		continue_button.grab_focus()


func _on_continue_pressed() -> void:
	_dismiss_and_advance()


func _dismiss_and_advance() -> void:
	visible = false
	_waiting_for_word = false
	InputBlocker.pop(self)
	MouseModeStack.pop(self)
	TutorialState.advance()

	if TutorialState.has_step_for_scene(scene_name):
		_show_current_step()


func _dismiss_and_advance_no_pop() -> void:
	visible = false
	_waiting_for_word = false
	TutorialState.advance()
	
	if TutorialState.has_step_for_scene(scene_name):
		_show_current_step()


func _exit_tree() -> void:
	MouseModeStack.pop(self)
	InputBlocker.pop(self)


func on_word_submitted() -> void:
	if not _waiting_for_word:
		return
	if not TutorialState.is_active():
		return
	
	await get_tree().create_timer(1.5).timeout
	_dismiss_and_advance()
