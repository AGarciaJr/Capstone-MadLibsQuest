using Godot;
using System;
using MadLibsQuest.NLP;

namespace MadLibsQuest;

/// <summary>
/// Godot Node that bridges GDScript to the WordNet NLP service.
/// Add this as an autoload singleton to make it globally accessible.
/// </summary>
public partial class WordNetBridge : Node
{
	private WordNetService? _wordNetService;
	
	/// <summary>
	/// Path to the WordNet dictionary folder, relative to res://
	/// </summary>
	[Export]
	public string WordNetDictPath { get; set; } = "res://assets/wordnet/dict";
	
	/// <summary>
	/// Whether the WordNet service is ready to use.
	/// </summary>
	public bool IsReady => _wordNetService?.IsInitialized ?? false;
	
	public override void _Ready()
	{
		GD.Print("===========================================");
		GD.Print("[WordNetBridge] C# AUTOLOAD STARTING...");
		GD.Print("===========================================");

		_wordNetService = new WordNetService();

		var absolutePath = ProjectSettings.GlobalizePath(WordNetDictPath);

		if (_wordNetService.Initialize(absolutePath))
		{
			GD.Print("[WordNetBridge] WordNet initialized successfully!");
			GD.Print($"[WordNetBridge] IsReady = {IsReady}");
			GD.Print($"[WordNetBridge] SynsetsReady = {SynsetsReady()}");

			// ---- TEMP TEST BLOCK ----
			if (SynsetsReady())
			{
				//GD.Print("---- TESTING SYNSETS ----");
//
				//var synsets = _wordNetService.GetSynsets("torrent", 'n');
//
				//GD.Print($"Synset count: {synsets.Count}");
//
				//foreach (var s in synsets)
				//{
					//GD.Print($"Words: {string.Join(", ", s.Words)}");
					//GD.Print($"Gloss: {s.Gloss}");
				//}
//
				//GD.Print("---- END TEST ----");
			}
		}
		else
		{
			GD.PrintErr("[WordNetBridge] Failed to initialize WordNet.");
		}

		GD.Print("===========================================");
	}

	
	/// <summary>
	/// Validates if a word matches the expected part of speech.
	/// Call from GDScript: WordNet.validate_pos("happy", "adjective")
	/// </summary>
	/// <param name="word">The word to validate.</param>
	/// <param name="expectedPos">Expected POS: noun, verb, adjective, adverb (or aliases: adj, adv)</param>
	/// <returns>True if valid, false if the word is not that part of speech.</returns>
	public bool ValidatePos(string word, string expectedPos)
	{
		GD.Print($"[WordNetBridge] ValidatePos called: word='{word}', expectedPos='{expectedPos}'");
		
		if (_wordNetService == null || !_wordNetService.IsInitialized)
		{
			GD.PrintErr("[WordNetBridge] WordNet not initialized, allowing word by default.");
			return true;
		}
		
		var result = _wordNetService.ValidatePartOfSpeech(word, expectedPos);
		GD.Print($"[WordNetBridge] Validation result: {result}");
		return result;
	}
	
	/// <summary>
	/// Gets all possible parts of speech for a word.
	/// Call from GDScript: WordNet.get_word_pos("run") -> ["noun", "verb"]
	/// </summary>
	/// <param name="word">The word to check.</param>
	/// <returns>Array of POS strings this word can be.</returns>
	public string[] GetWordPos(string word)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized)
		{
			return Array.Empty<string>();
		}
		
		return _wordNetService.GetPartsOfSpeech(word).ToArray();
	}
	
	/// <summary>
	/// Checks if a word exists in the WordNet dictionary.
	/// Call from GDScript: WordNet.word_exists("xyzzy") -> false
	/// </summary>
	/// <param name="word">The word to check.</param>
	/// <returns>True if the word exists in WordNet.</returns>
	public bool WordExists(string word)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized)
		{
			return true; // Fail open
		}
		
		return _wordNetService.WordExists(word);
	}
	
	/// <summary>
	/// Provides a helpful message about what parts of speech a word CAN be used as.
	/// Useful for player feedback when they enter the wrong type.
	/// </summary>
	/// <param name="word">The word the player entered.</param>
	/// <param name="expectedPos">What we asked for.</param>
	/// <returns>A feedback message, or empty string if the word is valid.</returns>
	public string GetPosHint(string word, string expectedPos)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized)
		{
			return "";
		}
		
		// If it's valid, no hint needed
		if (_wordNetService.ValidatePartOfSpeech(word, expectedPos))
		{
			return "";
		}
		
		// Check if the word exists at all
		if (!_wordNetService.WordExists(word))
		{
			return $"I don't recognize '{word}' - try a different word!";
		}
		
		// Word exists but wrong POS - tell them what it IS
		var actualPos = _wordNetService.GetPartsOfSpeech(word);
		if (actualPos.Count > 0)
		{
			var posString = string.Join(" or ", actualPos);
			return $"'{word}' is actually {GetArticle(actualPos[0])} {posString}!";
		}
		
		return $"'{word}' doesn't seem to be {GetArticle(expectedPos)} {expectedPos}.";
	}
	
	/// <summary>
	/// True if synset lookup is available.
	/// Call from GDScript: WordNet.synsets_ready()
	/// </summary>
	public bool SynsetsReady()
	{
		return _wordNetService?.SynsetsReady ?? false;
	}

	/// <summary>
	/// Returns all unique synset words (synonyms/collocations) for a word+POS.
	/// POS can be "noun"/"verb"/"adjective"/"adverb" OR "n"/"v"/"a"/"r".
	/// Call from GDScript: WordNet.get_synset_words("torrent","noun")
	/// </summary>
	public string[] GetSynsetWords(string word, string pos)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized || !_wordNetService.SynsetsReady)
			return Array.Empty<string>();

		var p = ResolvePosChar(pos);
		if (p == '\0') return Array.Empty<string>();

		var synsets = _wordNetService.GetSynsets(word, p);
		return synsets
			.SelectMany(s => s.Words)
			.Where(w => !string.IsNullOrWhiteSpace(w))
			.Distinct(StringComparer.OrdinalIgnoreCase)
			.ToArray();
	}

	/// <summary>
	/// Returns all synset glosses (definitions) for a word+POS.
	/// Call from GDScript: WordNet.get_synset_glosses("torrent","noun")
	/// </summary>
	public string[] GetSynsetGlosses(string word, string pos)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized || !_wordNetService.SynsetsReady)
			return Array.Empty<string>();

		var p = ResolvePosChar(pos);
		if (p == '\0') return Array.Empty<string>();

		var synsets = _wordNetService.GetSynsets(word, p);
		return synsets
			.Select(s => s.Gloss ?? "")
			.Where(g => !string.IsNullOrWhiteSpace(g))
			.Distinct(StringComparer.OrdinalIgnoreCase)
			.ToArray();
	}

	/// <summary>
	/// Returns a semantic bag (synonyms + gloss tokens) for element scoring.
	/// Call from GDScript: WordNet.get_semantic_bag("torrent","noun")
	/// </summary>
	public string[] GetSemanticBag(string word, string pos)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized || !_wordNetService.SynsetsReady)
			return Array.Empty<string>();

		var p = ResolvePosChar(pos);
		if (p == '\0') return Array.Empty<string>();

		var bag = _wordNetService.GetSemanticBag(word, p);
		return bag
			.Where(t => !string.IsNullOrWhiteSpace(t))
			.Distinct(StringComparer.OrdinalIgnoreCase)
			.ToArray();
	}

	/// <summary>
	/// Debug helper: prints synset details to the Godot console.
	/// Call from GDScript: WordNet.debug_print_synsets("torrent","noun")
	/// </summary>
	public void DebugPrintSynsets(string word, string pos)
	{
		if (_wordNetService == null || !_wordNetService.IsInitialized || !_wordNetService.SynsetsReady)
		{
			GD.PrintErr("[WordNetBridge] Synsets not ready.");
			return;
		}

		var p = ResolvePosChar(pos);
		if (p == '\0')
		{
			GD.PrintErr($"[WordNetBridge] Unknown POS for synsets: '{pos}'");
			return;
		}

		var synsets = _wordNetService.GetSynsets(word, p);
		GD.Print($"[WordNetBridge] Synsets for '{word}' ({p}) -> {synsets.Count}");

		for (var i = 0; i < synsets.Count; i++)
		{
			var s = synsets[i];
			GD.Print($"  [{i}] Offset={s.Offset} SsType={s.SsType}");
			GD.Print($"      Words: {string.Join(", ", s.Words)}");
			GD.Print($"      Gloss: {s.Gloss}");
			if (s.Pointers != null && s.Pointers.Count > 0)
			{
				// Keep it short; pointers can be numerous
				var sample = s.Pointers.Take(6)
					.Select(pt => $"{pt.Symbol}->{pt.TargetOffset}({pt.TargetPos})");
				GD.Print($"      Pointers(sample): {string.Join(", ", sample)}");
			}
		}
	}

	// -------------------------
	// Helpers
	// -------------------------

	private static string GetArticle(string word)
	{
		if (string.IsNullOrEmpty(word)) return "a";
		char first = char.ToLower(word[0]);
		return first is 'a' or 'e' or 'i' or 'o' or 'u' ? "an" : "a";
	}

	/// <summary>
	/// Accepts "noun"/"verb"/"adjective"/"adverb" or "n"/"v"/"a"/"r".
	/// Returns '\0' if unknown.
	/// </summary>
	private static char ResolvePosChar(string pos)
	{
		if (string.IsNullOrWhiteSpace(pos)) return '\0';
		pos = pos.Trim().ToLowerInvariant();

		return pos switch
		{
			"n" or "noun" => 'n',
			"v" or "verb" => 'v',
			"a" or "adj" or "adjective" => 'a',
			"r" or "adv" or "adverb" => 'r',
			_ => '\0'
		};
	}
}
