extends CanvasLayer
## Global scene transition handler with fade effects.
## Autoloaded as "SceneTransition"

signal transition_started
signal transition_midpoint  # Emitted when screen is fully black
signal transition_finished

@onready var color_rect: ColorRect = $ColorRect
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var is_transitioning: bool = false


func _ready() -> void:
	# Start fully transparent
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Transition to a new scene with a fade effect
func change_scene(scene_path: String, fade_duration: float = 1.0) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	# Block input during transition
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Fade to black
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, fade_duration)
	await tween.finished
	
	transition_midpoint.emit()
	
	# Change the scene
	get_tree().change_scene_to_file(scene_path)
	
	# Wait a frame for the new scene to load
	await get_tree().process_frame
	
	# Fade back in
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	
	# Re-enable input
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_finished.emit()


## Fade out only (useful for intro sequences)
func fade_out(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished


## Fade in only (useful when starting a new scene already faded)
func fade_in(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished


## Start with screen black (call at scene _ready if needed)
func start_black() -> void:
	color_rect.color.a = 1.0
