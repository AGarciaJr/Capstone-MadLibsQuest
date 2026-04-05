extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game():
	show()
	get_tree().paused = true

func resume_game():
	get_tree().paused = false
	hide()

func _on_resume_button_pressed():
	resume_game()

func _on_return_base_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(Scenes.INTRO)

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)


func _on_resume_pressed() -> void:
	resume_game()
