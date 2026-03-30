extends Control

# Assign these in the Inspector by connecting Button signals
# Scene paths — update as needed
const GAME_SCENE = "res://scenes/intro_scene.tscn"  
const SETTINGS_SCENE = "res://scenes/Settings.tscn" # Blank for now
const CREDITS_SCENE = "res://scenes/Credits.tscn"

func _ready():
	Engine.time_scale = 1.0

func _on_settings_button_pressed():
	# Placeholder — scene not built yet
	print("Settings not yet implemented")
	# get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_credits_button_pressed():
	get_tree().change_scene_to_file(CREDITS_SCENE)

func _on_exit_button_pressed():
	get_tree().quit()

func _on_credit_pressed():
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
