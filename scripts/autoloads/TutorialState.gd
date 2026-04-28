extends Node


var current_step: int = 0
var tutorial_completed: bool = false

var steps: Array = [
		# First Room
		{"scene": "room", "text": "Welcome to Wordwoven! You are a hero in a world full of monsters. Look around by moving your mouse.", "wait_for": "click"},
		{"scene": "room", "text": "See the door ahead? Click on it to enter your first battle.", "wait_for": "click"},
		# Pre-battle before first fight
		{"scene": "prebattle", "text": "Before each fight, you describe the enemy with an adjective. This changes how tough they are.", "wait_for": "click"},
		{"scene": "prebattle", "text": "Type an adjective and press Submit. Try something like 'weak' or 'small' for an easier fight!", "wait_for": "click"},
		# Battle scene first fight
		{"scene": "battle", "text": "Time to fight! The story has blanks you fill in with words. The prompt tells you what type of word to use.", "wait_for": "click"},
		{"scene": "battle", "text": "Your letters are shown on the left. The more letters you use, the more damage!", "wait_for": "click"},
		{"scene": "battle", "text": "Type a word and press Enter or click Submit. Try it now!", "wait_for": "click"},
		{"scene": "battle", "text": "", "wait_for": "word_submit"},
		{"scene": "battle", "text": "Nice! Watch the letter portraits — they highlight when your word uses those letters.", "wait_for": "click"},
		{"scene": "battle", "text": "Keep going! Fill in all the blanks to complete the sentence and damage the enemy.", "wait_for": "click"},
		# rewards
		{"scene": "postbattle", "text": "You won! After each battle you choose a reward. Pick one!", "wait_for": "click"},
		# after first fight
		{"scene": "room", "text": "Press M to open your map. It shows your path through the dungeon.", "wait_for": "key_m"},
		{"scene": "room", "text": "Your HP and score are shown in the corners. Click a door to continue!", "wait_for": "click"},
	]

func is_active() -> bool:
	return Run.run_mode == RunManager.RunMode.TUTORIAL and not tutorial_completed
	
func get_current_step() -> Dictionary:
	if current_step < 0 or current_step >= steps.size():
		return {}
	return steps[current_step]

func has_step_for_scene(scene_name: String) -> bool:
	if not is_active():
		return false
	var step := get_current_step()
	return step.get("scene", "") == scene_name

func advance() -> void:
	current_step += 1
	if current_step >= steps.size():
		complete()

func complete() -> void:
	tutorial_completed = true
	current_step = -1
