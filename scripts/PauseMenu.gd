extends CanvasLayer

const _BATTLE_INFORMATION := preload("res://Scenes/BattleInformation.tscn")

var _tips_overlay: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if _tips_overlay != null and is_instance_valid(_tips_overlay):
			_tips_overlay._go_back()
			get_viewport().set_input_as_handled()
			return
		if visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game():
	show()
	get_tree().paused = true
	MouseModeStack.push(self, Input.MOUSE_MODE_VISIBLE)
	InputBlocker.push(self)

func resume_game():
	if _tips_overlay != null and is_instance_valid(_tips_overlay):
		_tips_overlay.queue_free()
	_tips_overlay = null
	$PanelContainer.show()
	get_tree().paused = false
	hide()
	MouseModeStack.pop(self)
	InputBlocker.pop(self)

func _on_resume_button_pressed():
	resume_game()

func _on_return_base_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(Scenes.INTRO)

func _on_main_menu_pressed():
	if _tips_overlay != null and is_instance_valid(_tips_overlay):
		_tips_overlay.queue_free()
	_tips_overlay = null
	$PanelContainer.show()
	get_tree().paused = false
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)


func _on_resume_pressed() -> void:
	resume_game()


func _on_battle_tips_pressed() -> void:
	if _tips_overlay != null:
		return
	var tips: Control = _BATTLE_INFORMATION.instantiate()
	$PanelContainer.hide()
	add_child(tips)
	tips.set_overlay_mode(true)
	tips.overlay_closed.connect(_on_tips_overlay_closed, CONNECT_ONE_SHOT)
	_tips_overlay = tips


func _on_tips_overlay_closed() -> void:
	$PanelContainer.show()
	_tips_overlay = null
