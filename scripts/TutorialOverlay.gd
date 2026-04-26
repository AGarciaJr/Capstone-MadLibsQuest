extends Control

@onready var backdrop: ColorRect = $Backdrop
@onready var popup_panel: PanelContainer = $PopupPanel
@onready var message_label: Label = $PopupPanel/MarginContainer/VBoxContainer/MessageLabel
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


func _try_show_step() -> void:
	if not TutorialState.has_step_for_scene(scene_name):
		return
	_show_current_step()


func _show_current_step() -> void:
	var step := TutorialState.get_current_step()
	if step.is_empty():
		return

	message_label.text = step["text"]
	var wait_for: String = step.get("wait_for", "click")

	if wait_for == "click":
		continue_button.visible = true
		continue_button.text = "Continue"
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		InputBlocker.push(self)
		MouseModeStack.push(self, Input.MOUSE_MODE_VISIBLE)
	else:
		continue_button.visible = false
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if wait_for == "word_submit":
			_waiting_for_word = true

	visible = true


func _on_continue_pressed() -> void:
	_dismiss_and_advance()


func _dismiss_and_advance() -> void:
	visible = false
	_waiting_for_word = false
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputBlocker.pop(self)
	MouseModeStack.pop(self)
	TutorialState.advance()

	if TutorialState.has_step_for_scene(scene_name):
		_show_current_step()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not TutorialState.is_active():
		return

	var step := TutorialState.get_current_step()
	if step.is_empty():
		return

	var wait_for: String = step.get("wait_for", "click")

	if event is InputEventKey and event.pressed and not event.echo:
		if wait_for == "key_m" and event.keycode == KEY_M:
			get_viewport().set_input_as_handled()
			_dismiss_and_advance()


func _exit_tree() -> void:
	MouseModeStack.pop(self)
	InputBlocker.pop(self)


func on_word_submitted() -> void:
	if not _waiting_for_word:
		return
	if not visible or not TutorialState.is_active():
		return
	
	await get_tree().create_timer(1.5).timeout
	_dismiss_and_advance()
