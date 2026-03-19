extends RefCounted
class_name StatusEffects

## Central registry for status effect handlers. Modifiers apply effects by id + params;
## this script executes them. Add new effects by registering handlers.
##
## Context dict passed to handlers: { enemy_hp, enemy_max_hp, death_message, status_damage_entries }
## Handlers mutate context in place. Set death_message when effect kills the enemy.
## status_damage_entries: Array of { amount, source } for display.

var _effect_handlers: Dictionary = {}

func _init() -> void:
	_register_builtin_effects()

func _register_builtin_effects() -> void:
	register_effect("self_damage", _handle_self_damage)

## Register a handler. Handler receives (params: Dictionary, context: Dictionary) -> void.
## Context has: enemy_hp, enemy_max_hp, death_message (optional).
func register_effect(effect_id: String, handler: Callable) -> void:
	_effect_handlers[effect_id] = handler

## Apply all turn-start effects. Mutates context in place.
## effects: Array of { "id": String, "params": Dictionary }
## context: { enemy_hp, enemy_max_hp, death_message } - pass refs, will be mutated
func apply_turn_start_effects(effects: Array, context: Dictionary) -> void:
	if not context.has("status_damage_entries"):
		context["status_damage_entries"] = []
	for eff in effects:
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = eff as Dictionary
		var eid: String = str(d.get("id", ""))
		if eid.is_empty():
			continue
		var params: Dictionary = d.get("params", {}) as Dictionary
		var handler: Variant = _effect_handlers.get(eid)
		if handler is Callable:
			handler.call(params, context)

func _handle_self_damage(params: Dictionary, context: Dictionary) -> void:
	## Deals percent of enemy max HP as damage each turn.
	## params: { "percent": float, "source": String } e.g. 0.10 = 10%, source = "curse"
	var percent: float = float(params.get("percent", 0.10))
	percent = clampf(percent, 0.0, 1.0)
	var source: String = str(params.get("source", "curse"))

	var max_hp: int = int(context.get("enemy_max_hp", 1))
	var dmg: int = max(1, int(floor(float(max_hp) * percent)))

	var current: int = int(context.get("enemy_hp", 0))
	current = max(0, current - dmg)
	context["enemy_hp"] = current

	var entries: Array = context.get("status_damage_entries", [])
	entries.append({"amount": dmg, "source": source})
	context["status_damage_entries"] = entries

	if current <= 0:
		context["death_message"] = str(context.get("death_message", "The curse consumed the foe!"))
