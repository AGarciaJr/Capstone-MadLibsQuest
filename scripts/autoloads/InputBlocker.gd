extends Node


var _stack: Array = []


func push(stack_owner: Object) -> void:
	_prune_dead()
	if not _stack.has(stack_owner):
		_stack.append(stack_owner)


func pop(stack_owner: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i] == stack_owner:
			_stack.remove_at(i)
			break


func is_blocked() -> bool:
	_prune_dead()
	return not _stack.is_empty()


func _prune_dead() -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if not is_instance_valid(_stack[i]):
			_stack.remove_at(i)
