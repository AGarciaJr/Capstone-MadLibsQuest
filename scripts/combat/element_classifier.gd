class_name ElementClassifier

#TODO: needs some work the logic isnt as sound as it needs to be
static func classify(word: String, expected_pos: String = "") -> Dictionary:
	# Returns:
	# { "element": String, "score": float, "matched": PackedStringArray, "tokens": PackedStringArray }

	var w: String = word.strip_edges().to_lower()
	if w == "":
		return {"element": "unknown", "score": 0.0, "matched": PackedStringArray(), "tokens": PackedStringArray()}

	# Build tokens = semantic bag from WordNet if available, else fallback to the word itself.
	var tokens: PackedStringArray = PackedStringArray()
	tokens.append(w)

	if _has_wordnet() and WordNet.IsReady and WordNet.SynsetsReady():
		# You need these bridge methods exposed:
		# - WordNet.GetSemanticBag(word, pos) -> string[]
		# If you named it differently, change here.
		if WordNet.has_method("GetSemanticBag"):
			var bag: Array = WordNet.GetSemanticBag(w, expected_pos)
			for t in bag:
				var s := String(t).strip_edges().to_lower()
				if s != "" and not tokens.has(s):
					tokens.append(s)

	# Score each element by overlap with its keywords
	if not _has_elements() or not Elements.is_loaded():
		return {"element": "unknown", "score": 0.0, "matched": PackedStringArray(), "tokens": tokens}

	var best_elem: String = "unknown"
	var best_score: float = 0.0
	var best_matched: PackedStringArray = PackedStringArray()

	for elem_id in Elements.elements.keys():
		var entry: Dictionary = Elements.elements[elem_id]
		var kws: PackedStringArray = entry.get("keywords", PackedStringArray())
		var weight: float = float(entry.get("weight", 1.0))

		var matched: PackedStringArray = PackedStringArray()
		var hits: int = 0

		for kw in kws:
			if tokens.has(String(kw)):
				hits += 1
				matched.append(String(kw))

		# simple score = weighted hit count
		var score: float = float(hits) * weight

		if score > best_score:
			best_score = score
			best_elem = String(elem_id)
			best_matched = matched

	return {"element": best_elem, "score": best_score, "matched": best_matched, "tokens": tokens}

static func _has_wordnet() -> bool:
	return Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("WordNet")

static func _has_elements() -> bool:
	return Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("Elements")
