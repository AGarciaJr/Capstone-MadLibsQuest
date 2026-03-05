class_name ElementClassifier

static func classify(input_word: String, expected_pos: String = "") -> Dictionary:
	# Returns:
	# {
	#   "element": String,
	#   "confidence": float,          # 0..1
	#   "score": float,               # best raw score
	#   "matched": PackedStringArray, # matched hints/forced words (strings)
	#   "tokens": PackedStringArray,  # semantic bag (strings)
	#   "raw_scores": Dictionary      # elem_id -> float
	# }

	var settings: Dictionary = _get_settings()
	var fallback_element: String = String(settings.get("fallback_element", "physical"))
	var conf_threshold: float = float(settings.get("confidence_threshold", 0.15))
	var normalize_input: bool = bool(settings.get("normalize_input", true))
	var allow_overrides: bool = bool(settings.get("allow_manual_overrides", true))

	var w: String = input_word.strip_edges()
	if normalize_input:
		w = w.to_lower()

	if w == "":
		return {
			"element": "unknown",
			"confidence": 0.0,
			"score": 0.0,
			"matched": PackedStringArray(),
			"tokens": PackedStringArray(),
			"raw_scores": {}
		}

	if not _has_elements() or not Elements.is_loaded():
		return {
			"element": "unknown",
			"confidence": 0.0,
			"score": 0.0,
			"matched": PackedStringArray(),
			"tokens": PackedStringArray([w]),
			"raw_scores": {}
		}

	# Manual overrides aka forced words 
	if allow_overrides:
		var forced_hit: Dictionary = _check_forced_override(w)
		if bool(forced_hit.get("hit", false)):
			var hit_elem: String = String(forced_hit.get("element", "unknown"))
			return {
				"element": hit_elem,
				"confidence": 1.0,
				"score": 999.0,
				"matched": PackedStringArray([String(forced_hit.get("forced_word", ""))]),
				"tokens": PackedStringArray([w]),
				"raw_scores": { hit_elem: 999.0 }
			}

	# Build semantic bag tokens
	var tokens: PackedStringArray = _build_tokens(w, expected_pos, normalize_input)

	# Score each element by overlap with semantic_hints
	var raw_scores: Dictionary = {}
	var best_elem: String = "unknown"
	var best_score: float = -1.0
	var best_matched: PackedStringArray = PackedStringArray()

	var denom: float = max(1.0, sqrt(float(tokens.size())))

	for e_any: Variant in _iter_elements():
		var e: Dictionary = e_any as Dictionary
		var elem_id: String = String(e.get("id", "unknown"))
		var hints: PackedStringArray = _to_psa(e.get("semantic_hints", PackedStringArray()))
		var weight: float = float(e.get("weight", 1.0))

		var matched: PackedStringArray = PackedStringArray()
		var hits: int = 0

		for h0: String in hints:
			var hh: String = h0
			if normalize_input:
				hh = hh.to_lower()

			if tokens.has(hh) or _any_token_contains(tokens, hh) or hh.contains(w):
				hits += 1
				if not matched.has(hh):
					matched.append(hh)

		var score: float = (float(hits) / denom) * weight
		raw_scores[elem_id] = score


		if score > best_score:
			best_score = score
			best_elem = elem_id
			best_matched = matched

	# Convert to confidence and apply threshold
	var sum_scores: float = 0.0
	for k_any: Variant in raw_scores.keys():
		var k: String = String(k_any)
		sum_scores += float(raw_scores[k])

	var confidence: float = 0.0
	if sum_scores > 0.0 and best_score > 0.0:
		confidence = best_score / (sum_scores + 1e-9)

	if confidence < conf_threshold:
		return {
			"element": fallback_element,
			"confidence": confidence,
			"score": best_score,
			"matched": best_matched,
			"tokens": tokens,
			"raw_scores": raw_scores
		}

	return {
		"element": best_elem,
		"confidence": confidence,
		"score": best_score,
		"matched": best_matched,
		"tokens": tokens,
		"raw_scores": raw_scores
	}


# Helpers
static func _build_tokens(w: String, expected_pos: String, normalize_input: bool) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	tokens.append(w)

	var base_tokens: PackedStringArray = _simple_tokenize(w)
	for t: String in base_tokens:
		if t != "" and not tokens.has(t):
			tokens.append(t)

	var grams: PackedStringArray = _ngrams(base_tokens, 2, 3)
	for g: String in grams:
		if g != "" and not tokens.has(g):
			tokens.append(g)

	if _has_wordnet() and WordNet.IsReady and WordNet.SynsetsReady():
		if WordNet.has_method("GetSemanticBag"):
			var bag: Array = WordNet.GetSemanticBag(w, expected_pos)
			for t_any: Variant in bag:
				var s: String = String(t_any).strip_edges()
				if normalize_input:
					s = s.to_lower()
				if s != "" and not tokens.has(s):
					tokens.append(s)

	return tokens


static func _check_forced_override(w: String) -> Dictionary:
	for e_any: Variant in _iter_elements():
		var e: Dictionary = e_any as Dictionary
		var elem_id: String = String(e.get("id", "unknown"))
		var forced: PackedStringArray = _to_psa(e.get("forced_words", PackedStringArray()))

		for fw0: String in forced:
			var fw: String = fw0.strip_edges()
			if fw == "":
				continue
			var fw_l: String = fw.to_lower()

			if w == fw_l or w.contains(fw_l) or fw_l.contains(w):
				return { "hit": true, "element": elem_id, "forced_word": fw_l }

	return { "hit": false, "element": "unknown", "forced_word": "" }


static func _iter_elements() -> Array:
	var out: Array = []
	var data: Variant = Elements.elements  # explicit Variant to silence inference warning-as-error

	if typeof(data) == TYPE_DICTIONARY:
		var ddata: Dictionary = data as Dictionary
		for k_any: Variant in ddata.keys():
			var k: String = String(k_any)
			var entry_any: Variant = ddata[k_any]
			if typeof(entry_any) == TYPE_DICTIONARY:
				var entry: Dictionary = entry_any as Dictionary
				if not entry.has("id"):
					var entry2: Dictionary = entry.duplicate(true)
					entry2["id"] = k
					out.append(entry2)
				else:
					out.append(entry)

	elif typeof(data) == TYPE_ARRAY:
		var adata: Array = data as Array
		for entry_any: Variant in adata:
			if typeof(entry_any) == TYPE_DICTIONARY:
				var entry: Dictionary = entry_any as Dictionary
				out.append(entry)

	return out


static func _get_settings() -> Dictionary:
	if _has_elements():
		if Elements.has_method("get_settings"):
			return Elements.get_settings()
		if "settings" in Elements:
			return Elements.settings
		if "classification_settings" in Elements:
			return Elements.classification_settings

	return {
		"fallback_element": "physical",
		"confidence_threshold": 0.15,
		"normalize_input": true,
		"allow_manual_overrides": true
	}


static func _simple_tokenize(s: String) -> PackedStringArray:
	var cleaned: String = ""
	for i: int in s.length():
		var ch: String = s.substr(i, 1)
		if _is_ascii_alnum_or_underscore(ch):
			cleaned += ch
		else:
			cleaned += " "

	cleaned = cleaned.strip_edges()
	if cleaned == "":
		return PackedStringArray()

	# allow_empty = false (exclude empty tokens)
	var parts: PackedStringArray = cleaned.split(" ", false)
	var out: PackedStringArray = PackedStringArray()

	for p0: String in parts:
		var t: String = p0.strip_edges().to_lower()
		if t != "" and not out.has(t):
			out.append(t)

	return out


static func _is_ascii_alnum_or_underscore(ch: String) -> bool:
	# Godot doesn't have String.is_ascii_alphanumeric().
	# Use unicode_at() + ASCII range checks.
	if ch == "_" :
		return true
	if ch.length() == 0:
		return false
	var code: int = ch.unicode_at(0)
	# '0'..'9'
	if code >= 48 and code <= 57:
		return true
	# 'A'..'Z'
	if code >= 65 and code <= 90:
		return true
	# 'a'..'z'
	if code >= 97 and code <= 122:
		return true
	return false


static func _ngrams(tokens: PackedStringArray, min_n: int, max_n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var n_tokens: int = tokens.size()

	for n: int in range(min_n, max_n + 1):
		if n <= 0 or n > n_tokens:
			continue
		for i: int in range(0, n_tokens - n + 1):
			var phrase: String = ""
			for j: int in range(n):
				if j > 0:
					phrase += " "
				phrase += String(tokens[i + j])
			if phrase != "" and not out.has(phrase):
				out.append(phrase)

	return out


static func _any_token_contains(tokens: PackedStringArray, needle: String) -> bool:
	if needle == "":
		return false
	for t0: String in tokens:
		if t0.contains(needle):
			return true
	return false


static func _to_psa(v: Variant) -> PackedStringArray:
	if typeof(v) == TYPE_PACKED_STRING_ARRAY:
		return v as PackedStringArray
	if typeof(v) == TYPE_ARRAY:
		var out: PackedStringArray = PackedStringArray()
		for x_any: Variant in (v as Array):
			out.append(String(x_any))
		return out
	return PackedStringArray()


static func _has_wordnet() -> bool:
	return Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("WordNet")


static func _has_elements() -> bool:
	return Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("Elements")
