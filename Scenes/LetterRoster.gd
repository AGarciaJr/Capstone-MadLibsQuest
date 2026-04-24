extends GridContainer


const PORTRAIT_SIZE := Vector2(40, 40)
const CARD_WIDTH := 50


func _ready() -> void:
	columns = 5
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)

	if not PlayerState.player_letters_changed.is_connected(rebuild):
		PlayerState.player_letters_changed.connect(rebuild)
	if not PlayerState.letter_leveled_up.is_connected(_on_level_up):
		PlayerState.letter_leveled_up.connect(_on_level_up)

	rebuild()
	

func _exit_tree() -> void:
	if PlayerState.player_letters_changed.is_connected(rebuild):
		PlayerState.player_letters_changed.disconnect(rebuild)
	if PlayerState.letter_leveled_up.is_connected(_on_level_up):
		PlayerState.letter_leveled_up.disconnect(_on_level_up)


func _on_level_up(_letter: String, _new_level: int) -> void:
	rebuild()

func rebuild(_letters: PackedStringArray = PackedStringArray()) -> void:
	for child in get_children():
		child.queue_free()

	var sorted := Array(PlayerState.player_letters)
	sorted.sort()

	for letter in sorted:
		add_child(_build_card(letter))

func _build_card(letter: String) -> VBoxContainer:
	var data: Dictionary = PlayerState.letters_data.get(letter, {})
	var level := PlayerState.get_letter_level(letter)
	var xp := int(data.get("xp", 0))
	
	var card := VBoxContainer.new()
	card.set_meta("letter", letter)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_constant_override("separation", 1)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Letter portrait and background
	var portrait_bg := ColorRect.new()
	portrait_bg.custom_minimum_size = PORTRAIT_SIZE
	portrait_bg.color = Color(0, 0, 0, 0)
	portrait_bg.set_meta("highlight_bg", true)
	
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	var art_path := "res://assets/Art/LetterArt/Letter_%s.png" % letter.to_upper()
	var texture := load(art_path)
	if texture:
		portrait.texture = texture
		
	portrait_bg.add_child(portrait)
	card.add_child(portrait_bg)
	
	# Letter level
	var level_label := Label.new()
	if level >= PlayerState.MAX_LETTER_LEVEL:
		level_label.text = "Lv.MAX"
	else:
		level_label.text = "Lv.%d" % level
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.58))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(level_label)
	
	# Letter XP bar
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(CARD_WIDTH - 4, 4)
	xp_bar.show_percentage = false
	
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.12, 0.08)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("background", bar_bg)
	
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.72, 0.52, 0.18)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", bar_fill)
	if level >= PlayerState.MAX_LETTER_LEVEL:
		xp_bar.max_value = 1
		xp_bar.value = 1
	else:
		xp_bar.max_value = PlayerState.XP_PER_LEVEL
		xp_bar.value = xp
	
	card.add_child(xp_bar)
	
	return card

func update_highlights(word: String) -> void:
	var upper := word.to_upper()
	for card in get_children():
		if not card is VBoxContainer:
			continue
		
		var letter : String = card.get_meta("letter", "")
		var bg: ColorRect = null
		for child in card.get_children():
			if child.has_meta("highlight_bg"):
				bg = child
				break
		if bg == null:
			continue
		if letter != "" and letter in upper:
			bg.color = Color(0.3, 0.5, 1.0, 0.25)
		else:
			bg.color = Color(0, 0, 0, 0)
