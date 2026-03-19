extends Node

## id -> EncounterModifier (loaded from Customizer.json)
var modifiers: Dictionary = {}

## Fallback modifier when no semantic match is confident enough (e.g. "plain" = no effect).
@export var fallback_modifier_id: String = "plain"
## Minimum confidence (0..1) to accept a semantic match; else use fallback.
@export var confidence_threshold: float = 0.15
## If true, expand input word with WordNet synonyms when scoring (like element system).
@export var use_wordnet_for_tokens: bool = true

@export var customizer_json_path: String = "res://data/Encounter/Customizer.json"

func _ready() -> void:
	_load_modifiers(customizer_json_path)

func _load_modifiers(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed as Dictionary
	if not root.has("modifiers"):
		return
	modifiers.clear()
	for m_any in root["modifiers"]:
		if typeof(m_any) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m_any as Dictionary
		var mod: EncounterModifier = EncounterModifier.from_dict(m)
		if mod.id == "":
			continue
		modifiers[mod.id] = mod

func get_modifier(id: String) -> EncounterModifier:
	var v: Variant = modifiers.get(id, null)
	return v as EncounterModifier if v is EncounterModifier else null

## Returns the fallback modifier (e.g. "plain"). Never null if fallback exists.
func get_fallback_modifier() -> EncounterModifier:
	var fb: EncounterModifier = get_modifier(fallback_modifier_id)
	if fb != null:
		return fb
	for id in modifiers.keys():
		return modifiers[id] as EncounterModifier
	return null

## Exact match on forced_words only. Returns null if no match.
func pick_by_adjective(adj: String) -> EncounterModifier:
	var w: String = adj.to_lower().strip_edges()
	if w == "":
		return null
	for id in modifiers.keys():
		var mod: EncounterModifier = modifiers[id] as EncounterModifier
		if mod == null:
			continue
		for fw in mod.forced_words:
			if fw.to_lower() == w:
				return mod
	return null

## Semantic classification (synonym/anchor words + optional WordNet). Always returns a modifier;
## uses fallback (e.g. "plain") when input is empty or no confident match.
func classify_adjective(adj: String) -> EncounterModifier:
	var w: String = adj.to_lower().strip_edges()
	if w == "":
		return get_fallback_modifier()

	# 1) Forced-word exact match (like element overrides)
	var exact: EncounterModifier = pick_by_adjective(adj)
	if exact != null:
		return exact

	# 2) Build token bag from input (word + tokenize + ngrams + optional WordNet)
	var tokens: PackedStringArray = _build_tokens(w)

	# 3) Score each modifier by overlap of semantic_hints and forced_words with tokens
	var raw_scores: Dictionary = {}
	var best_id: String = ""
	var best_score: float = -1.0
	var denom: float = max(1.0, sqrt(float(tokens.size())))

	for id in modifiers.keys():
		var mod: EncounterModifier = modifiers[id] as EncounterModifier
		if mod == null:
			continue
		var hints: PackedStringArray = _merge_hints_and_forced(mod)
		var hits: int = 0
		for h in hints:
			var hh: String = h.to_lower()
			if tokens.has(hh) or _any_token_contains(tokens, hh) or hh.contains(w) or w.contains(hh):
				hits += 1
		var weight: float = float(max(1, mod.rarity_weight))
		var score: float = (float(hits) / denom) * weight
		raw_scores[id] = score
		if score > best_score:
			best_score = score
			best_id = id

	# 4) Confidence = best / (sum of scores); if below threshold, use fallback
	var sum_scores: float = 0.0
	for k in raw_scores.keys():
		sum_scores += float(raw_scores[k])
	var confidence: float = 0.0
	if sum_scores > 0.0 and best_score > 0.0:
		confidence = best_score / (sum_scores + 1e-9)

	if confidence < confidence_threshold or best_id == "":
		return get_fallback_modifier()
	return get_modifier(best_id) if get_modifier(best_id) != null else get_fallback_modifier()


static func _merge_hints_and_forced(mod: EncounterModifier) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for h in mod.semantic_hints:
		var s: String = str(h).strip_edges().to_lower()
		if s != "" and not out.has(s):
			out.append(s)
	for f in mod.forced_words:
		var t: String = str(f).strip_edges().to_lower()
		if t != "" and not out.has(t):
			out.append(t)
	return out


func _build_tokens(w: String) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	tokens.append(w)
	var base: PackedStringArray = _simple_tokenize(w)
	for t in base:
		if t != "" and not tokens.has(t):
			tokens.append(t)
	var grams: PackedStringArray = _ngrams(base, 2, 3)
	for g in grams:
		if g != "" and not tokens.has(g):
			tokens.append(g)
	if use_wordnet_for_tokens and _has_wordnet() and WordNet.IsReady and WordNet.SynsetsReady():
		if WordNet.has_method("GetSemanticBag"):
			var bag: Array = WordNet.GetSemanticBag(w, "a")
			for t_any in bag:
				var s: String = str(t_any).strip_edges().to_lower()
				if s != "" and not tokens.has(s):
					tokens.append(s)
	return tokens


func _has_wordnet() -> bool:
	return Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("WordNet")


static func _any_token_contains(tokens: PackedStringArray, needle: String) -> bool:
	if needle == "":
		return false
	for t in tokens:
		if t.contains(needle):
			return true
	return false


static func _simple_tokenize(s: String) -> PackedStringArray:
	var cleaned: String = ""
	for i in s.length():
		var ch: String = s.substr(i, 1)
		if _is_alnum(ch):
			cleaned += ch
		else:
			cleaned += " "
	cleaned = cleaned.strip_edges()
	if cleaned == "":
		return PackedStringArray()
	var parts: PackedStringArray = cleaned.split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for p in parts:
		var t: String = p.strip_edges().to_lower()
		if t != "" and not out.has(t):
			out.append(t)
	return out


static func _is_alnum(ch: String) -> bool:
	if ch.length() == 0:
		return false
	var code: int = ch.unicode_at(0)
	if code >= 48 and code <= 57:
		return true
	if code >= 65 and code <= 90:
		return true
	if code >= 97 and code <= 122:
		return true
	return false


static func _ngrams(tokens: PackedStringArray, min_n: int, max_n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var n_tokens: int = tokens.size()
	for n in range(min_n, max_n + 1):
		if n <= 0 or n > n_tokens:
			continue
		for i in range(0, n_tokens - n + 1):
			var phrase: String = ""
			for j in range(n):
				if j > 0:
					phrase += " "
				phrase += str(tokens[i + j])
			if phrase != "" and not out.has(phrase):
				out.append(phrase)
	return out
