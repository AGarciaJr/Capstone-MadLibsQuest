extends Node

@onready var background := $Background
@onready var word_enter := $WordEnter
@onready var bard := $BardLabel
@onready var inv_label := $InventoryLabel
@onready var player_health_bar := $PlayerHealthBar
@onready var player_health_label := $PlayerHealthBar/PlayerHealthLabel
@onready var enemy := $Enemy
@onready var inv: Inventory = RunState.inventory

# @onready var next_scene: PackedScene = preload("res://scenes/loot_drop.tscn")

func _ready() -> void:
	# Connect signals
	# Incoming
	Signals.word_validated.connect(bard_validated)
	Signals.text_invalidated.connect(bard_invalidated)
	Signals.inventory_updated.connect(update_inventory)
	Signals.enemy_defeated.connect(enemy_defeated)
	Signals.player_defeated.connect(lose_game)
	
	# Emitting
	word_enter.text_submitted.connect(text_entered)
	
	# Frame one inventory fix
	update_inventory(RunState.inventory.letters)
	
	# Set up enemy, background, increment run state
	enemy.set_data(RunState.enemies[RunState.current_enemy])
	background.texture = enemy.enemy_data.background
	RunState.current_enemy += 1

func _input(event: InputEvent) -> void:
	# Test add letters to inventory
	if event.is_action_pressed("ui_text_backspace"):
		var new_letter : Letter
		inv.letters.clear()
		for letter in RunState.get_letter_dict().keys():
			new_letter = Letter.new(letter)
			inv.add_letter(new_letter)
		# print(inv.letters)

func _process(_delta: float) -> void:
	player_health_bar.value = RunState.player.health
	player_health_label.text = str(int(ceil(RunState.player.health))) \
		+ '/' + str(int(ceil(RunState.player.max_health)))

# When the player enters text
func text_entered(text: String):
	Signals.emit_text_sent(text)
	word_enter.text = ""

# When the word is valid and works
func bard_validated(word: Word):
	var text = word.text
	bard.text = "Attacked with: " + text + "!"

# When word is invalid
func bard_invalidated(text: String):
	bard.text = text.to_upper() + " is an invalid word."

func update_inventory(letters: Array[Letter]):
	var inv_text : String
	var characters : Array[String] = []
	for letter in letters:
		characters.append(letter.character)
	inv_text = ' '.join(characters)
	inv_label.text = 'Inventory: ' + inv_text

func enemy_defeated(e: Enemy) -> void:
	print(str(e.enemy_name) + " defeated!")
	if RunState.current_enemy < len(RunState.enemies):
		get_tree().change_scene_to_file("res://scenes/loot_drop.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/win.tscn")
	queue_free()

func lose_game() -> void:
	get_tree().change_scene_to_file("res://scenes/lose.tscn")
	queue_free()
