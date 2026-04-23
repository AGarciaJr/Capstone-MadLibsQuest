extends Control

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var player_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/PlayerLabel
@onready var score_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var stats_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsLabel
@onready var play_again_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/MainMenuButton

func _ready() -> void:
	SaveManager.delete_save()
	title_label.text = "Run Complete!"
	player_label.text = "Well done, %s!" % PlayerState.player_name
	score_label.text = "Final Score: %d" % PlayerState.current_run_score
	
	var sorted_letters := Array(PlayerState.player_letters)
	sorted_letters.sort()
	var stat_parts: Array[String] = []
	stat_parts.append("HP Remaining: %d / %d" % [PlayerState.current_hp, PlayerState.max_hp])
	stat_parts.append("Letters collected: %s" % PlayerState.format_player_letters_with_levels())
	stats_label.text = "\n".join(stat_parts)
	
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
func _on_play_again_pressed() -> void:
	var saved_name := PlayerState.player_name
	var saved_letters := PlayerState.initial_player_letters.duplicate()
	PlayerState.reset_to_defaults()
	PlayerState.player_name = saved_name
	PlayerState.set_initial_player_letters(saved_letters)
	Run.run_mode = RunManager.RunMode.GENERATED
	Run.start_run()
	Progress.reset_progress()
	EncounterSceneTransition.clear()
	get_tree().change_scene_to_file(Scenes.ROOM)

func _on_main_menu_pressed() -> void:
	PlayerState.reset_to_defaults()
	Run.new_generated_run()
	Progress.reset_progress()
	EncounterSceneTransition.clear()
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)
