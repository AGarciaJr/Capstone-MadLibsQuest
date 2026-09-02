extends Node
class_name Enemy

@onready var health_bar := $ProgressBar
@onready var health_label := $ProgressBar/Label
@onready var attack_timer := $AttackTimer
@onready var sprite := $Sprite2D

@export var enemy_data: EnemyData

var enemy_name : String
var max_health : float
var health : float
var attack_speed_seconds : float
var damage : float
var weakness : Array[Letter.Element]
var resistance : Array[Letter.Element]

func _ready() -> void:
	# Incoming
	Signals.damage_to_enemy_dealt.connect(take_damage)

func _process(_delta) -> void:
	check_for_death()

func _on_attack_timer_timeout() -> void:
	Signals.emit_damage_to_player_dealt(damage)

func set_data(data: EnemyData) -> void:
	enemy_data = data
	# Set vars
	enemy_name = enemy_data.enemy_name
	max_health = enemy_data.max_health
	health = enemy_data.health
	attack_speed_seconds = enemy_data.attack_speed
	damage = enemy_data.damage
	weakness = enemy_data.weakness
	resistance = enemy_data.resistance
	
	# Set health bar
	health_bar.max_value = max_health
	health_bar.value = health
	
	# Set attack timer
	attack_timer.start(attack_speed_seconds)
	
	# Set sprite
	sprite.texture = enemy_data.sprite
	sprite.scale = enemy_data.sprite_scale

func take_damage(incoming_damage: float, element: Letter.Element) -> void:
	var damage_mult := 1.0
	if element in weakness:
		damage_mult = 20.0
	if element in resistance:
		damage_mult = 0.5
	health -= incoming_damage * damage_mult
	check_for_death()

func _update_health_bar() -> void:
	# Update health bar
	health = max(0, health)
	health_bar.value = health
	health_label.text = str(int(ceil(health))) + "/" + str(int(ceil(max_health)))

func check_for_death() -> void:
	_update_health_bar()
	# Check for death
	if health <= 0:
		Signals.emit_enemy_defeated(self)
		queue_free()
