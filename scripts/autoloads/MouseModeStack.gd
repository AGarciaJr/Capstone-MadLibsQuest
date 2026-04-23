extends Node

var _stack: Array = []
var _default_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func set_default_mouse_mode(mode: Input.MouseMode) -> void:
	_default_mouse_mode = mode
	_apply()

func push(owner: Object, mode: Input.MouseMode) -> void:
	_stack.append({"owner": owner, "mode": mode})
	_apply()

func pop(owner: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i]["owner"] == owner:
			_stack.remove_at(i)
			break
	_apply()

func _apply() -> void:
	if _stack.is_empty():
		Input.set_mouse_mode(_default_mouse_mode)
	else:
		Input.set_mouse_mode(_stack[-1]["mode"])
