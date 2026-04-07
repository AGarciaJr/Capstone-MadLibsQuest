extends CanvasLayer

var current_level: String = ""

func _ready():
	hide()

func show_death_screen():
	current_level = get_tree().current_scene.scene_file_path
	show()

func _on_restart_button_pressed():
	hide()
	get_tree().change_scene_to_file("res://Scenes/PreBattle/PreBattleModifier.tscn")

func _on_base_button_pressed():
	hide()
	get_tree().change_scene_to_file(Scenes.INTRO)

func _on_menu_button_pressed():
	hide()
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)


func _on_restart_pressed() -> void:
	hide()
	get_tree().change_scene_to_file("res://Scenes/PreBattle/PreBattleModifier.tscn")


func _on_main_menu_pressed() -> void:
	hide()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
