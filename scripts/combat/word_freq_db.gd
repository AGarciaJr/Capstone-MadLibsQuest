extends Node
class_name WordFrequencyDB

@export var csv_path: String = "res://data/SUBTLEX US/word_frequency.csv"
@export var has_header: bool = true

# Missing Word Behavior
@export var default_zipf_if_missing: float = 2.8

# Zipf normalization range
@export var zipf_min: float = 1.0
@export var zipf_max: float = 7.0

# Scaling range for S in D_raw = (B + S*A)*C
@export var s_min: float = 0.30
@export var s_max: float = 1.10

var _word_to_zipf: Dictionary = {} # String -> float
var _loaded: bool = false

func _ready() -> void:
	load_db(csv_path)

func is_loaded() -> bool:
	return _loaded

func load_db(path: String) -> bool:
	_word_to_zipf.clear()
	_loaded = false

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("WordFrequencyDB: Failed to open CSV: %s (err=%s)" % [path, error_string(FileAccess.get_open_error())])
		return false

	var header: PackedStringArray = PackedStringArray()
	if has_header and not f.eof_reached():
		header = f.get_csv_line()
		print("WordFrequencyDB: Header=", header)

	# Default columns
	var word_col: int = 0
	var lg10wf_col: int = 1

	# If header exists, try to locate columns by name robustly
	if has_header and header.size() > 1:
		var i: int = 0
		while i < header.size():
			var col_name: String = String(header[i]).strip_edges().to_lower()
			if col_name == "word":
				word_col = i
			elif col_name == "lg10wf":
				lg10wf_col = i
			i += 1

	var row_count: int = 0
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.is_empty():
			continue

		var needed: int = max(word_col, lg10wf_col)
		if row.size() <= needed:
			continue

		var w: String = String(row[word_col]).strip_edges().to_lower()
		if w == "":
			continue

		var lg10wf_str: String = String(row[lg10wf_col]).strip_edges()
		if lg10wf_str == "":
			continue

		# Convert to float (if parse fails, float(...) returns 0.0; you can choose to skip 0.0 rows)
		var lg10wf: float = float(lg10wf_str)
		var zipf: float = lg10wf + 3.0

		_word_to_zipf[w] = zipf
		row_count += 1

	f.close()

	_loaded = row_count > 0
	print("WordFrequencyDB: Loaded rows=", row_count, " loaded=", _loaded)
	return _loaded

func get_zipf(word: String) -> float:
	var w: String = word.strip_edges().to_lower()
	if w == "":
		return default_zipf_if_missing

	if _word_to_zipf.has(w):
		return float(_word_to_zipf[w])

	return default_zipf_if_missing

func get_complexity01(word: String) -> float:
	var zipf: float = get_zipf(word)
	var denom: float = max(0.000001, (zipf_max - zipf_min))
	var c: float = (zipf_max - zipf) / denom
	return clamp(c, 0.0, 1.0)

func get_scaling_S(word: String) -> float:
	var c: float = get_complexity01(word)
	return lerp(s_min, s_max, c)

func debug_print(word: String) -> void:
	var z: float = get_zipf(word)
	var c: float = get_complexity01(word)
	var s: float = get_scaling_S(word)
	print("WordFrequencyDB: word=", word, " zipf=", z, " complexity01=", c, " S=", s)
