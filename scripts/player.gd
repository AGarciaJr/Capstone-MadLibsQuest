extends Node2D
class_name Player

var max_health := 100.0
var health := max_health

func _ready() -> void:
	# Incoming signals
	Signals.damage_to_player_dealt.connect(damage_recieved)
	Signals.word_validated.connect(deal_damage)

func _process(_delta) -> void:
	if health <= 0:
		Signals.emit_player_defeated()
		queue_free()

func damage_recieved(damage: float) -> void:
	health = max(0, health-damage)

func deal_damage(word: Word) -> void:
	Signals.emit_damage_to_enemy_dealt(word.get_final_damage(), word.dominant_element)
