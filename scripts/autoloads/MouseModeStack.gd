extends Node

var _stack: Array = []
var _default_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func set_default_mouse_mode(mode: Input.MouseMode) -> void:
	_default_mouse_mode = mode
	_apply()


func push(stack_owner: Object, mode: Input.MouseMode) -> void:
	_prune_dead_owners()
	_stack.append({"owner": stack_owner, "mode": mode})
	_apply()


func pop(stack_owner: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i]["owner"] == stack_owner:
			_stack.remove_at(i)
			break
	_apply()


func _prune_dead_owners() -> void:
	for i in range(_stack.size() - 1, -1, -1):
		var o: Object = _stack[i]["owner"]
		if not is_instance_valid(o):
			_stack.remove_at(i)


func _apply() -> void:
	_prune_dead_owners()
	if _stack.is_empty():
		Input.set_mouse_mode(_default_mouse_mode)
	else:
		Input.set_mouse_mode(_stack[-1]["mode"])
