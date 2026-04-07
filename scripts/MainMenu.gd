extends Control

@onready var mode_modal: Control = $ModeModal

func _ready():
	Engine.time_scale = 1.0
	mode_modal.visible = false

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
	mode_modal.visible = true

func _on_tutorial_pressed() -> void:
	mode_modal.visible = false
	PlayerState.reset_to_defaults()
	Run.run_mode = RunManager.RunMode.TUTORIAL
	Run.start_run()
	get_tree().change_scene_to_file(Scenes.INTRO)

func _on_new_run_pressed() -> void:
	mode_modal.visible = false
	PlayerState.reset_to_defaults()
	Run.run_mode = RunManager.RunMode.GENERATED
	Run.start_run()
	get_tree().change_scene_to_file(Scenes.LETTER_SELECT)

func _on_modal_back_pressed() -> void:
	mode_modal.visible = false
