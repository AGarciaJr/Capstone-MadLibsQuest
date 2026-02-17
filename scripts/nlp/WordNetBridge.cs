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
		
		// Convert Godot path to absolute system path
		var absolutePath = ProjectSettings.GlobalizePath(WordNetDictPath);
		
		GD.Print($"[WordNetBridge] Godot path: {WordNetDictPath}");
		GD.Print($"[WordNetBridge] Absolute path: {absolutePath}");
		GD.Print($"[WordNetBridge] Directory exists: {System.IO.Directory.Exists(absolutePath)}");
		
		if (_wordNetService.Initialize(absolutePath))
		{
			GD.Print("[WordNetBridge] WordNet initialized successfully!");
			GD.Print($"[WordNetBridge] IsReady = {IsReady}");
		}
		else
		{
			GD.PrintErr($"[WordNetBridge] Failed to initialize WordNet. Make sure the dictionary exists at: {WordNetDictPath}");
			GD.PrintErr("[WordNetBridge] Download WordNet from: https://wordnet.princeton.edu/download");
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
	/// Helper to get "a" or "an" for a word.
	/// </summary>
	private static string GetArticle(string word)
	{
		if (string.IsNullOrEmpty(word)) return "a";
		char first = char.ToLower(word[0]);
		return first is 'a' or 'e' or 'i' or 'o' or 'u' ? "an" : "a";
	}
}
