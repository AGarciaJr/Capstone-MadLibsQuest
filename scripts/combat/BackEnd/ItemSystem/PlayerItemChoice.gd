extends Control

## Emitted when the player selects one of the items. index is 0, 1, or 2.
signal item_chosen(index: int)

var _reward_items: Array[Dictionary] = []

@onready var container: HBoxContainer = $ItemNodeOriginContainer
@onready var choice_1_name: Label = $ItemNodeOriginContainer/ItemChoice1/ItemName
@onready var choice_1_desc: Label = $ItemNodeOriginContainer/ItemChoice1/ItemDescription
@onready var choice_1_btn: Button = $ItemNodeOriginContainer/ItemChoice1/Button
@onready var choice_2_name: Label = $ItemNodeOriginContainer/ItemChoice2/ItemName
@onready var choice_2_desc: Label = $ItemNodeOriginContainer/ItemChoice2/ItemDescription
@onready var choice_2_btn: Button = $ItemNodeOriginContainer/ItemChoice2/Button
@onready var choice_3_name: Label = $ItemNodeOriginContainer/ItemChoice3/ItemName
@onready var choice_3_desc: Label = $ItemNodeOriginContainer/ItemChoice3/ItemDescription
@onready var choice_3_btn: Button = $ItemNodeOriginContainer/ItemChoice3/Button


func _ready() -> void:
	choice_1_btn.pressed.connect(_on_choice_pressed.bind(0))
	choice_2_btn.pressed.connect(_on_choice_pressed.bind(1))
	choice_3_btn.pressed.connect(_on_choice_pressed.bind(2))

	var items_any: Array = EncounterSceneTransition.consume_pending_reward_items()
	_reward_items.clear()
	for it_any in items_any:
		if typeof(it_any) == TYPE_DICTIONARY:
			_reward_items.append(it_any as Dictionary)
	set_items(_reward_items)
	item_chosen.connect(_on_item_chosen)


func set_items(items: Array) -> void:
	var names: Array[Label] = [choice_1_name, choice_2_name, choice_3_name]
	var descs: Array[Label] = [choice_1_desc, choice_2_desc, choice_3_desc]
	var btns: Array[Button] = [choice_1_btn, choice_2_btn, choice_3_btn]
	for i in range(3):
		if i < items.size():
			var it: Dictionary = items[i] as Dictionary
			names[i].text = String(it.get("name", "Item"))
			descs[i].text = String(it.get("description", ""))
			btns[i].visible = true
		else:
			names[i].text = ""
			descs[i].text = ""
			btns[i].visible = false


func _on_choice_pressed(index: int) -> void:
	item_chosen.emit(index)

func _on_item_chosen(index: int) -> void:
	if _reward_items.is_empty():
		EncounterSceneTransition.return_to_scene()
		return
	if index < 0 or index >= _reward_items.size():
		return
	ItemSystem.apply_item(_reward_items[index])
	EncounterSceneTransition.return_to_scene()
