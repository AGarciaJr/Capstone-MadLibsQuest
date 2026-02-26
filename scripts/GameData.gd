extends Node

# Player data that persists between scenes
var player_name: String = ""
var player_letters: Array[String] = []

func reset() -> void:
	player_name = ""
	player_letters = []
