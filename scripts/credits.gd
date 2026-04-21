extends Control

const MAIN_MENU_SCENE = "res://Scenes/MainMenu.tscn" 

func _on_back_to_menu_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
