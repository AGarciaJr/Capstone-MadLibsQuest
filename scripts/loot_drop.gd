extends Control
class_name LootDrop

@onready var drop0: Button = $"HBoxContainer/0"
@onready var drop1: Button = $"HBoxContainer/1"
@onready var drop2: Button = $"HBoxContainer/2"

var letters: Array[Letter] = []
# var drops: Array[Button] = [drop_1, drop_2, drop_3]

func _ready() -> void:
	# Receive
	Signals.enemy_defeated.connect(generate_loot_drop)
	# For testing
	generate_loot_drop(Enemy.new())
	
	# Emit
	drop0.pressed.connect(loot0_chosen)
	drop1.pressed.connect(loot1_chosen)
	drop2.pressed.connect(loot2_chosen)

func _process(_delta: float) -> void:
	# print(RunState.inventory.letters)
	pass

func generate_loot_drop(_enemy: Enemy) -> void:
	# For testing just offer the same three letters
	var letter1 = Letter.new('z', Letter.Element.ICE)
	var letter2 = Letter.new('u', Letter.Element.FIRE)
	var letter3 = Letter.new('f')
	letters.append_array([letter1, letter2, letter3])
	
	# Update buttons
	drop0.text = letters[0].character
	drop0.tooltip_text = str(letters[0].element)
	drop1.text = letters[1].character
	drop1.tooltip_text = str(letters[1].element)
	drop2.text = letters[2].character
	drop2.tooltip_text = str(letters[2].element)

func loot0_chosen() -> void:
	Signals.emit_letter_chosen(letters[0])
	next_room()

func loot1_chosen() -> void:
	Signals.emit_letter_chosen(letters[1])
	next_room()

func loot2_chosen() -> void:
	Signals.emit_letter_chosen(letters[2])
	next_room()

func next_room() -> void:
	get_tree().change_scene_to_file("res://scenes/combat_encounter.tscn")
	queue_free()
