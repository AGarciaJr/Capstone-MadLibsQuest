# res://scripts/data/enemy_db.gd
extends Node
class_name EnemyDB

var enemies: Dictionary = {}

func load_db(path: String = "res://data/combat/enemies.json") -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("EnemyDB: Failed to open " + path)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("EnemyDB: JSON parse error in " + path)
		return false

	if not (json.data is Dictionary):
		push_error("EnemyDB: Expected Dictionary at root of " + path)
		return false

	enemies = json.data
	return true

func get_enemy(id: String) -> Dictionary:
	if enemies.has(id):
		return enemies[id]
	return {}
