using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace MadLibsQuest.NLP;

/// <summary>
/// Lightweight WordNet reader for part-of-speech validation.
/// Reads the WordNet index files directly without external dependencies.
/// Includes lemmatization to handle conjugated/inflected word forms.
/// </summary>
public class WordNetService
{
	// Word lookup sets for each POS (loaded from index files)
	private HashSet<string> _nouns = new(StringComparer.OrdinalIgnoreCase);
	private HashSet<string> _verbs = new(StringComparer.OrdinalIgnoreCase);
	private HashSet<string> _adjectives = new(StringComparer.OrdinalIgnoreCase);
	private HashSet<string> _adverbs = new(StringComparer.OrdinalIgnoreCase);
	
	// Exception dictionaries for irregular forms (e.g., "ran" -> "run")
	private Dictionary<string, string> _nounExceptions = new(StringComparer.OrdinalIgnoreCase);
	private Dictionary<string, string> _verbExceptions = new(StringComparer.OrdinalIgnoreCase);
	private Dictionary<string, string> _adjExceptions = new(StringComparer.OrdinalIgnoreCase);
	private Dictionary<string, string> _advExceptions = new(StringComparer.OrdinalIgnoreCase);

	private WordNetSynsetReader? _synsetReader;
	
	private bool _isInitialized;
	
	/// <summary>
	/// Maps simplified POS types to our internal sets.
	/// </summary>
	private static readonly Dictionary<string, string> PosAliases = new(StringComparer.OrdinalIgnoreCase)
	{
		{ "noun", "noun" },
		{ "verb", "verb" },
		{ "adjective", "adjective" },
		{ "adj", "adjective" },
		{ "adverb", "adverb" },
		{ "adv", "adverb" },
		// Compound types (still validate as base type)
		{ "noun_plural", "noun" },
		{ "verb_past", "verb" },
		{ "verb_ing", "verb" },
	};
	
	public bool IsInitialized => _isInitialized;
	
	/// <summary>
	/// Initializes the service by loading WordNet index files.
	/// </summary>
	/// <param name="wordNetDictPath">Path to the WordNet 'dict' folder.</param>
	/// <returns>True if initialization succeeded.</returns>
	public bool Initialize(string wordNetDictPath)
	{
		try
		{
			if (!Directory.Exists(wordNetDictPath))
			{
				Godot.GD.PrintErr($"[WordNetService] Dictionary path not found: {wordNetDictPath}");
				return false;
			}
			
			// Load each index file
			var nounPath = Path.Combine(wordNetDictPath, "index.noun");
			var verbPath = Path.Combine(wordNetDictPath, "index.verb");
			var adjPath = Path.Combine(wordNetDictPath, "index.adj");
			var advPath = Path.Combine(wordNetDictPath, "index.adv");
			
			_nouns = LoadIndexFile(nounPath);
			_verbs = LoadIndexFile(verbPath);
			_adjectives = LoadIndexFile(adjPath);
			_adverbs = LoadIndexFile(advPath);
			
			// Load exception files for irregular forms
			_nounExceptions = LoadExceptionFile(Path.Combine(wordNetDictPath, "noun.exc"));
			_verbExceptions = LoadExceptionFile(Path.Combine(wordNetDictPath, "verb.exc"));
			_adjExceptions = LoadExceptionFile(Path.Combine(wordNetDictPath, "adj.exc"));
			_advExceptions = LoadExceptionFile(Path.Combine(wordNetDictPath, "adv.exc"));

			_synsetReader = new WordNetSynsetReader();
			var synsetOk = _synsetReader.Initialize(wordNetDictPath);
			if (!synsetOk)
			{
				Godot.GD.PrintErr("[WordNetService] Synset reader failed to initialize. POS validation will still work, but synsets will be unavailable.");
			}
			
			var totalWords = _nouns.Count + _verbs.Count + _adjectives.Count + _adverbs.Count;
			var totalExceptions = _nounExceptions.Count + _verbExceptions.Count + _adjExceptions.Count + _advExceptions.Count;
			Godot.GD.Print($"[WordNetService] Loaded {totalWords} word entries:");
			Godot.GD.Print($"  - Nouns: {_nouns.Count}");
			Godot.GD.Print($"  - Verbs: {_verbs.Count}");
			Godot.GD.Print($"  - Adjectives: {_adjectives.Count}");
			Godot.GD.Print($"  - Adverbs: {_adverbs.Count}");
			Godot.GD.Print($"[WordNetService] Loaded {totalExceptions} irregular form exceptions");
			
			_isInitialized = totalWords > 0;
			return _isInitialized;
		}
		catch (Exception ex)
		{
			Godot.GD.PrintErr($"[WordNetService] Failed to load WordNet: {ex.Message}");
			Godot.GD.PrintErr($"[WordNetService] Stack trace: {ex.StackTrace}");
			_isInitialized = false;
			return false;
		}
	}
	
	/// <summary>
	/// Loads words from a WordNet index file.
	/// Index file format: word pos synset_cnt p_cnt [ptr_symbol...] sense_cnt tagsense_cnt synset_offset...
	/// Lines starting with spaces are comments.
	/// </summary>
	private HashSet<string> LoadIndexFile(string filePath)
	{
		var words = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
		
		if (!File.Exists(filePath))
		{
			Godot.GD.PrintErr($"[WordNetService] Index file not found: {filePath}");
			return words;
		}
		
		foreach (var line in File.ReadLines(filePath))
		{
			// Skip comment lines (start with space or are empty)
			if (string.IsNullOrEmpty(line) || line.StartsWith(' '))
				continue;
			
			// First field is the word (may contain underscores for multi-word)
			var firstSpace = line.IndexOf(' ');
			if (firstSpace > 0)
			{
				var word = line.Substring(0, firstSpace);
				// Convert underscores to spaces for multi-word entries, but also keep original
				words.Add(word.Replace('_', ' '));
				if (word.Contains('_'))
				{
					words.Add(word); // Also add with underscores
				}
			}
		}
		
		return words;
	}
	
	/// <summary>
	/// Loads an exception file that maps irregular forms to base forms.
	/// Format: "irregular_form base_form" (space-separated)
	/// </summary>
	private Dictionary<string, string> LoadExceptionFile(string filePath)
	{
		var exceptions = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
		
		if (!File.Exists(filePath))
		{
			Godot.GD.Print($"[WordNetService] Exception file not found (optional): {filePath}");
			return exceptions;
		}
		
		foreach (var line in File.ReadLines(filePath))
		{
			if (string.IsNullOrWhiteSpace(line)) continue;
			
			var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			if (parts.Length >= 2)
			{
				// Map irregular form -> base form
				exceptions[parts[0]] = parts[1];
			}
		}
		
		return exceptions;
	}
	
	/// <summary>
	/// Attempts to convert a word to its base/lemma form for a given POS.
	/// Handles both irregular exceptions and regular inflection patterns.
	/// </summary>
	private List<string> GetLemmas(string word, string pos)
	{
		var lemmas = new List<string> { word };
		
		// Get the exception dictionary for this POS
		var exceptions = pos switch
		{
			"noun" => _nounExceptions,
			"verb" => _verbExceptions,
			"adjective" => _adjExceptions,
			"adverb" => _advExceptions,
			_ => null
		};
		
		// Check exceptions first (irregular forms like "ran" -> "run")
		if (exceptions != null && exceptions.TryGetValue(word, out var baseForm))
		{
			lemmas.Add(baseForm);
		}
		
		// Apply regular inflection rules based on POS
		if (pos == "verb")
		{
			// Handle verb conjugations
			if (word.EndsWith("ing"))
			{
				// running -> run, jumping -> jump
				lemmas.Add(word[..^3]); // remove "ing"
				lemmas.Add(word[..^3] + "e"); // hoping -> hope
				if (word.Length > 4 && word[^4] == word[^5])
				{
					lemmas.Add(word[..^4]); // running -> run (double consonant)
				}
			}
			else if (word.EndsWith("ed"))
			{
				// jumped -> jump, hoped -> hope
				lemmas.Add(word[..^2]); // remove "ed"
				lemmas.Add(word[..^1]); // remove just "d" (hoped -> hope)
				if (word.Length > 3 && word.EndsWith("ied"))
				{
					lemmas.Add(word[..^3] + "y"); // carried -> carry
				}
			}
			else if (word.EndsWith("es"))
			{
				lemmas.Add(word[..^2]); // goes -> go
				lemmas.Add(word[..^1]); // takes -> take (wrong but catches some)
			}
			else if (word.EndsWith("s") && !word.EndsWith("ss"))
			{
				lemmas.Add(word[..^1]); // runs -> run
			}
		}
		else if (pos == "noun")
		{
			// Handle noun plurals
			if (word.EndsWith("ies"))
			{
				lemmas.Add(word[..^3] + "y"); // cities -> city
			}
			else if (word.EndsWith("es"))
			{
				lemmas.Add(word[..^2]); // boxes -> box
				lemmas.Add(word[..^1]); // caves -> cave
			}
			else if (word.EndsWith("s") && !word.EndsWith("ss"))
			{
				lemmas.Add(word[..^1]); // dogs -> dog
			}
		}
		else if (pos == "adjective")
		{
			// Handle comparative/superlative
			if (word.EndsWith("er"))
			{
				lemmas.Add(word[..^2]); // bigger -> big
				lemmas.Add(word[..^1]); // nicer -> nice
			}
			else if (word.EndsWith("est"))
			{
				lemmas.Add(word[..^3]); // biggest -> big
				lemmas.Add(word[..^2]); // nicest -> nice
			}
		}
		
		return lemmas.Distinct().ToList();
	}
	
	/// <summary>
	/// Validates whether a word can be used as the specified part of speech.
	/// Handles conjugated/inflected forms via lemmatization.
	/// </summary>
	public bool ValidatePartOfSpeech(string word, string expectedPos)
	{
		if (!_isInitialized)
		{
			Godot.GD.Print("[WordNetService] Cannot validate - not initialized.");
			return true; // Fail open
		}
		
		if (string.IsNullOrWhiteSpace(word))
			return false;
			
		word = word.Trim().ToLowerInvariant();
		
		// Resolve POS alias
		if (!PosAliases.TryGetValue(expectedPos.ToLowerInvariant(), out var resolvedPos))
		{
			Godot.GD.Print($"[WordNetService] Unknown POS type: {expectedPos}");
			return true; // Unknown POS, allow it
		}
		
		// Get the appropriate word set
		var wordSet = resolvedPos switch
		{
			"noun" => _nouns,
			"verb" => _verbs,
			"adjective" => _adjectives,
			"adverb" => _adverbs,
			_ => null
		};
		
		if (wordSet == null) return true;
		
		// Try the word directly first
		if (wordSet.Contains(word))
			return true;
		
		// Try lemmatized forms
		var lemmas = GetLemmas(word, resolvedPos);
		foreach (var lemma in lemmas)
		{
			if (wordSet.Contains(lemma))
			{
				Godot.GD.Print($"[WordNetService] '{word}' matched via lemma '{lemma}' as {resolvedPos}");
				return true;
			}
		}
		
		return false;
	}
	
	/// <summary>
	/// Gets all parts of speech that a word can be used as.
	/// Uses lemmatization to handle conjugated forms.
	/// </summary>
	public List<string> GetPartsOfSpeech(string word)
	{
		var result = new List<string>();
		
		if (!_isInitialized || string.IsNullOrWhiteSpace(word))
			return result;
			
		word = word.Trim().ToLowerInvariant();
		
		// Check each POS with lemmatization
		if (CheckWithLemmas(word, "noun", _nouns)) result.Add("noun");
		if (CheckWithLemmas(word, "verb", _verbs)) result.Add("verb");
		if (CheckWithLemmas(word, "adjective", _adjectives)) result.Add("adjective");
		if (CheckWithLemmas(word, "adverb", _adverbs)) result.Add("adverb");
			
		return result;
	}
	
	/// <summary>
	/// Checks if a word (or its lemmas) exists in a word set.
	/// </summary>
	private bool CheckWithLemmas(string word, string pos, HashSet<string> wordSet)
	{
		if (wordSet.Contains(word)) return true;
		
		var lemmas = GetLemmas(word, pos);
		return lemmas.Any(lemma => wordSet.Contains(lemma));
	}
	
	/// <summary>
	/// Checks if a word exists in WordNet at all.
	/// Uses lemmatization to handle conjugated forms.
	/// </summary>
	public bool WordExists(string word)
	{
		if (!_isInitialized || string.IsNullOrWhiteSpace(word))
			return false;
			
		word = word.Trim().ToLowerInvariant();
		
		// Check directly first
		if (_nouns.Contains(word) || _verbs.Contains(word) || 
			_adjectives.Contains(word) || _adverbs.Contains(word))
			return true;
		
		// Try lemmatized forms for each POS
		return CheckWithLemmas(word, "noun", _nouns) ||
			   CheckWithLemmas(word, "verb", _verbs) ||
			   CheckWithLemmas(word, "adjective", _adjectives) ||
			   CheckWithLemmas(word, "adverb", _adverbs);
	}

	/// <summary>
	/// True if synset lookup is available.
	/// </summary>
	public bool SynsetsReady => _synsetReader?.IsInitialized ?? false;

	/// <summary>
	/// Get synsets (synonyms + gloss + pointers) for a word and POS.
	/// pos should be: 'n' (noun), 'v' (verb), 'a' (adj), 'r' (adv).
	/// </summary>
	public List<WordNetSynset> GetSynsets(string word, char pos)
	{
		if (_synsetReader == null || !_synsetReader.IsInitialized) return new List<WordNetSynset>();
		if (string.IsNullOrWhiteSpace(word)) return new List<WordNetSynset>();

		// Use lemmas to increase hit rate, since WordNet index is lemma-based
		var posName = pos switch { 'n' => "noun", 'v' => "verb", 'a' => "adjective", 'r' => "adverb", _ => "" };
		if (posName.Length == 0)
			return new List<WordNetSynset>();

		var wordNorm = word.Trim().ToLowerInvariant();
		var lemmas = GetLemmas(wordNorm, posName);

		foreach (var lemma in lemmas)
		{
			var syns = _synsetReader.GetSynsets(lemma, pos);
			if (syns.Count > 0) return syns;
		}

		// Fall back to raw word
		return _synsetReader.GetSynsets(wordNorm, pos);
	}

	/// <summary>
	/// Convenience: get a semantic bag (synonyms + gloss tokens) for scoring against your element keywords.
	/// </summary>
	public List<string> GetSemanticBag(string word, char pos)
	{
		if (_synsetReader == null || !_synsetReader.IsInitialized) return new List<string>();
		if (string.IsNullOrWhiteSpace(word)) return new List<string>();

		var posName = pos switch { 'n' => "noun", 'v' => "verb", 'a' => "adjective", 'r' => "adverb", _ => "" };
		if (posName.Length == 0) return new List<string>();

		var wordNorm = word.Trim().ToLowerInvariant();
		var lemmas = GetLemmas(wordNorm, posName);

		foreach (var lemma in lemmas)
		{
			var bag = _synsetReader.GetSemanticBag(lemma, pos);
			if (bag.Count > 0) return bag;
		}

		return _synsetReader.GetSemanticBag(wordNorm, pos);
	}
}
