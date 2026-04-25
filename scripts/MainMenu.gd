extends Control

@onready var mode_modal: Control = $ModeModal
@onready var continue_button: Button = $VBoxContainer/Continue

func _ready():
	MouseModeStack.set_default_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioPlayer.play_music_title()
	Engine.time_scale = 1.0
	mode_modal.visible = false
	continue_button.visible = SaveManager.has_save()

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
	PlayerState.player_name = "Hero"
	PlayerState.set_initial_player_letters(PackedStringArray(["A", "E", "S", "T", "X"]))
	Run.run_mode = RunManager.RunMode.TUTORIAL
	Run.start_run()
	get_tree().change_scene_to_file(Scenes.ROOM)

func _on_new_run_pressed() -> void:
	mode_modal.visible = false
	PlayerState.reset_to_defaults()
	Run.run_mode = RunManager.RunMode.GENERATED
	Run.start_run()
	get_tree().change_scene_to_file(Scenes.INTRO)

func _on_modal_back_pressed() -> void:
	mode_modal.visible = false

func _on_continue_pressed() -> void:
	if SaveManager.load_save():
		get_tree().change_scene_to_file(Scenes.ROOM)
	else:
		continue_button.visible = false
