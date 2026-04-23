extends Node


var _stack: Array = []

func push(owner: Object) -> void:
	if not _stack.has(owner):
		_stack.append(owner)

func pop(owner: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i] == owner:
			_stack.remove_at(i)
			break

func is_blocked() -> bool:
	return not _stack.is_empty()
