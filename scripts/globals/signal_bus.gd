extends Node

# Combat and word signals
signal text_sent(text: String)
signal word_validated(word: Word)
signal text_invalidated(text: String)
signal damage_to_enemy_dealt(damage: float, element: Letter.Element)
signal damage_to_player_dealt(damage: float)
signal enemy_defeated(enemy: Enemy)
signal player_defeated()
signal letters_dropped()
signal letter_chosen(letter: Letter)
signal inventory_updated(letters: Array[Letter])
signal enemy_spawned()

# UI and meta


# API
func emit_text_sent(text: String) -> void:
	emit_signal("text_sent", text)

func emit_word_validated(word: Word) -> void:
	emit_signal("word_validated", word)

func emit_text_invalidated(text: String) -> void:
	emit_signal("text_invalidated", text)

func emit_damage_to_enemy_dealt(damage: float, element: Letter.Element) -> void:
	emit_signal("damage_to_enemy_dealt", damage, element)

func emit_damage_to_player_dealt(damage: float) -> void:
	emit_signal("damage_to_player_dealt", damage)
	
func emit_enemy_defeated(enemy: Enemy) -> void:
	emit_signal("enemy_defeated", enemy)

func emit_player_defeated() -> void:
	emit_signal("player_defeated")

func emit_letters_dropped() -> void:
	emit_signal("letters_dropped")

func emit_letter_chosen(letter: Letter) -> void:
	emit_signal("letter_chosen", letter)

func emit_inventory_updated(letters: Array[Letter]) -> void:
	emit_signal("inventory_updated", letters)

func emit_enemy_spawned() -> void:
	emit_signal("enemy_spawned")
