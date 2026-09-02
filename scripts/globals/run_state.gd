extends Node

var inventory: Inventory
var word_dict: WordDictionary
var letter_dict: LetterDictionary
var word_validator: WordValidator
var player: Player
var enemies: Array[EnemyData]
var current_enemy := 0

func _ready():
	start_new_run()

func start_new_run():
	current_enemy = 0
	enemies = [
		preload("res://scripts/enemies/rat.tres"),
		preload("res://scripts/enemies/red_dragon.tres")
	]
	
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)
	
	word_dict = WordDictionary.new()
	word_dict.name = 'WordDictionary'
	add_child(word_dict)
	
	letter_dict = LetterDictionary.new()
	letter_dict.name = 'LetterDictionary'
	add_child(letter_dict)
	
	word_validator = WordValidator.new()
	word_validator.name = 'WordValidator'
	add_child(word_validator)
	
	player = Player.new()
	player.name = 'Player'
	add_child(player)

func get_word_dict() -> Dictionary:
	return word_dict.dictionary

func get_letter_dict() -> Dictionary:
	return letter_dict.dictionary
