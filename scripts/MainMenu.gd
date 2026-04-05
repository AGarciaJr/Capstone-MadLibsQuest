extends Control

func _ready():
	Engine.time_scale = 1.0

func _on_settings_button_pressed():
	# Placeholder — scene not built yet
	print("Settings not yet implemented")
	# get_tree().change_scene_to_file(Scenes.SETTINGS))

func _on_credits_button_pressed():
	get_tree().change_scene_to_file(Scenes.CREDITS)

func _on_exit_button_pressed():
	get_tree().quit()

func _on_credit_pressed():
	get_tree().change_scene_to_file(Scenes.CREDITS)

func _on_start_pressed() -> void:
	PlayerState.reset_to_defaults()
	Run.start_run()
	get_tree().change_scene_to_file(Scenes.INTRO)
