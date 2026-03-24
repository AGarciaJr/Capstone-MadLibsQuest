// Usage (inside WordNetService or elsewhere):
//   var reader = new WordNetSynsetReader();
//   reader.Initialize(dictPathAbsolute);
//   var synsets = reader.GetSynsets("torrent", 'n'); // noun synsets
//   foreach (var s in synsets) GD.Print($"{string.Join(", ", s.Words)} | {s.Gloss}");

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MadLibsQuest.NLP;

public sealed class WordNetSynsetReader : IDisposable
{
	// WordNet dict paths
	private string _dictPath = "";

	// lemma -> list of synset offsets (per POS)
	private readonly Dictionary<string, List<int>> _nounIndex = new(StringComparer.OrdinalIgnoreCase);
	private readonly Dictionary<string, List<int>> _verbIndex = new(StringComparer.OrdinalIgnoreCase);
	private readonly Dictionary<string, List<int>> _adjIndex  = new(StringComparer.OrdinalIgnoreCase);
	private readonly Dictionary<string, List<int>> _advIndex  = new(StringComparer.OrdinalIgnoreCase);

	// Cache parsed synsets: key = (pos, offset)
	private readonly Dictionary<(char pos, int offset), WordNetSynset> _synsetCache = new();

	// Optional: cache file paths for data.* files
	private string _dataNounPath = "";
	private string _dataVerbPath = "";
	private string _dataAdjPath  = "";
	private string _dataAdvPath  = "";

	public bool IsInitialized { get; private set; }

	/// Initialize by loading lemma->offset maps from index.* files and storing data.* paths.
	public bool Initialize(string wordNetDictPath)
	{
		if (string.IsNullOrWhiteSpace(wordNetDictPath) || !Directory.Exists(wordNetDictPath))
			return false;

		_dictPath = wordNetDictPath;

		var indexNoun = Path.Combine(_dictPath, "index.noun");
		var indexVerb = Path.Combine(_dictPath, "index.verb");
		var indexAdj  = Path.Combine(_dictPath, "index.adj");
		var indexAdv  = Path.Combine(_dictPath, "index.adv");

		_dataNounPath = Path.Combine(_dictPath, "data.noun");
		_dataVerbPath = Path.Combine(_dictPath, "data.verb");
		_dataAdjPath  = Path.Combine(_dictPath, "data.adj");
		_dataAdvPath  = Path.Combine(_dictPath, "data.adv");

		// Minimal sanity
		if (!File.Exists(indexNoun) || !File.Exists(indexVerb) || !File.Exists(indexAdj) || !File.Exists(indexAdv))
			return false;
		if (!File.Exists(_dataNounPath) || !File.Exists(_dataVerbPath) || !File.Exists(_dataAdjPath) || !File.Exists(_dataAdvPath))
			return false;

		_nounIndex.Clear(); _verbIndex.Clear(); _adjIndex.Clear(); _advIndex.Clear();
		_synsetCache.Clear();

		LoadIndexOffsets(indexNoun, _nounIndex, expectedPos: 'n');
		LoadIndexOffsets(indexVerb, _verbIndex, expectedPos: 'v');
		LoadIndexOffsets(indexAdj,  _adjIndex,  expectedPos: 'a'); // index.adj uses 'a'
		LoadIndexOffsets(indexAdv,  _advIndex,  expectedPos: 'r'); // index.adv uses 'r'

		IsInitialized = _nounIndex.Count + _verbIndex.Count + _adjIndex.Count + _advIndex.Count > 0;
		return IsInitialized;
	}

	/// Get synsets for a lemma for a specific POS: 'n','v','a','r'
	/// If you want adjective satellites too, note that data.adj can contain ss_type 's' lines,
	/// but their index POS is still 'a'.
	public List<WordNetSynset> GetSynsets(string word, char pos)
	{
		if (!IsInitialized) return new List<WordNetSynset>();
		if (string.IsNullOrWhiteSpace(word)) return new List<WordNetSynset>();

		word = NormalizeLemma(word);

		var index = GetIndex(pos);
		if (index == null) return new List<WordNetSynset>();

		// WordNet index lemma uses underscores for collocations
		// We'll try both spaced and underscored variants.
		var candidates = new[]
		{
			word,
			word.Replace(' ', '_'),
			word.Replace('_', ' ')
		}.Distinct(StringComparer.OrdinalIgnoreCase);

		List<int>? offsets = null;
		foreach (var c in candidates)
		{
			if (index.TryGetValue(c, out offsets))
				break;
		}

		if (offsets == null || offsets.Count == 0)
			return new List<WordNetSynset>();

		// Parse each synset line from data.pos by seeking to byte offset
		var results = new List<WordNetSynset>(offsets.Count);
		foreach (var off in offsets)
		{
			var syn = GetSynsetByOffset(pos, off);
			if (syn != null) results.Add(syn);
		}
		return results;
	}

	/// <summary>
	/// Convenience: get synsets for all POS buckets.
	/// </summary>
	public Dictionary<char, List<WordNetSynset>> GetSynsetsAllPos(string word)
	{
		var outMap = new Dictionary<char, List<WordNetSynset>>();
		foreach (var p in new[] { 'n', 'v', 'a', 'r' })
			outMap[p] = GetSynsets(word, p);
		return outMap;
	}

	/// <summary>
	/// Returns a "semantic bag" you can score against your element keywords:
	/// synonyms + gloss tokens (simple whitespace split).
	/// </summary>
	public List<string> GetSemanticBag(string word, char pos)
	{
		var synsets = GetSynsets(word, pos);
		var bag = new List<string>();

		foreach (var s in synsets)
		{
			bag.AddRange(s.Words.Select(NormalizeToken));
			if (!string.IsNullOrWhiteSpace(s.Gloss))
			{
				var glossTokens = s.Gloss
					.Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
					.Select(t => NormalizeToken(t));
				bag.AddRange(glossTokens);
			}
		}

		return bag.Where(t => t.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
	}

	// -------------------- Internal: index parsing --------------------

	private static void LoadIndexOffsets(string indexFilePath, Dictionary<string, List<int>> dest, char expectedPos)
	{
		foreach (var line in File.ReadLines(indexFilePath))
		{
			// Comments / header lines begin with space in WordNet files
			if (string.IsNullOrEmpty(line) || line[0] == ' ')
				continue;

			// Tokenize by spaces
			var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			if (parts.Length < 8) continue;

			// index format:
			// lemma pos synset_cnt p_cnt [ptr_symbol...] sense_cnt tagsense_cnt synset_offset [synset_offset...]
			// pos is one char: n,v,a,r
			var lemma = parts[0];
			var posStr = parts[1];
			if (posStr.Length != 1) continue;

			var pos = posStr[0];
			if (pos != expectedPos) continue;

			if (!int.TryParse(parts[2], out var synsetCnt)) continue;
			if (!int.TryParse(parts[3], out var pCnt)) continue;

			// After p_cnt come p_cnt pointer symbols (optional if p_cnt=0)
			// Then sense_cnt, tagsense_cnt
			var idx = 4 + pCnt;
			if (idx + 1 >= parts.Length) continue; // need sense_cnt and tagsense_cnt at least

			// sense_cnt, tagsense_cnt
			idx += 2;

			// Remaining should be synset offsets: count = synset_cnt
			if (synsetCnt <= 0) continue;
			if (idx + synsetCnt > parts.Length) continue;

			var offsets = new List<int>(synsetCnt);
			for (var i = 0; i < synsetCnt; i++)
			{
				if (int.TryParse(parts[idx + i], out var off))
					offsets.Add(off);
			}

			if (offsets.Count == 0) continue;

			// Store lemma as-is (underscored collocations) AND a spaced version for convenience
			AddOrMerge(dest, lemma, offsets);

			var spaced = lemma.Replace('_', ' ');
			if (!spaced.Equals(lemma, StringComparison.OrdinalIgnoreCase))
				AddOrMerge(dest, spaced, offsets);
		}
	}

	private static void AddOrMerge(Dictionary<string, List<int>> dest, string key, List<int> offsets)
	{
		if (dest.TryGetValue(key, out var existing))
		{
			// Keep unique offsets, preserve original ordering as much as possible
			var set = new HashSet<int>(existing);
			foreach (var o in offsets)
				if (set.Add(o)) existing.Add(o);
		}
		else
		{
			dest[key] = offsets;
		}
	}

	// -------------------- Internal: synset reading/parsing --------------------

	private WordNetSynset? GetSynsetByOffset(char pos, int offset)
	{
		var cacheKey = (pos, offset);
		if (_synsetCache.TryGetValue(cacheKey, out var cached))
			return cached;

		var dataPath = GetDataPath(pos);
		if (dataPath == null) return null;

		var line = ReadLineAtByteOffset(dataPath, offset);
		if (line == null) return null;

		var synset = ParseDataLine(line);
		if (synset == null) return null;

		// Note: the ss_type in data.adj can be 'a' or 's'; we keep that in SsType.
		_synsetCache[cacheKey] = synset;
		return synset;
	}

	private static string? ReadLineAtByteOffset(string filePath, int byteOffset)
	{
		// WordNet defines synset_offset as a byte offset usable with fseek into data.pos. :contentReference[oaicite:1]{index=1}
		// To avoid StreamReader buffering/encoding issues, we seek with FileStream and read bytes until '\n'.
		using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
		if (byteOffset < 0 || byteOffset >= fs.Length) return null;

		fs.Seek(byteOffset, SeekOrigin.Begin);

		var bytes = new List<byte>(512);
		int b;
		while ((b = fs.ReadByte()) != -1)
		{
			if (b == '\n') break;
			bytes.Add((byte)b);
		}

		if (bytes.Count == 0) return null;
		return Encoding.ASCII.GetString(bytes.ToArray());
	}

	private static WordNetSynset? ParseDataLine(string line)
	{
		// data format:
		// synset_offset lex_filenum ss_type w_cnt word lex_id [word lex_id...] p_cnt [ptr...] [frames...] | gloss
		// w_cnt is 2-digit hex; p_cnt is 3-digit decimal. :contentReference[oaicite:2]{index=2}

		var barIndex = line.IndexOf('|');
		var left = barIndex >= 0 ? line.Substring(0, barIndex).TrimEnd() : line.TrimEnd();
		var gloss = barIndex >= 0 ? line.Substring(barIndex + 1).Trim() : "";

		var parts = left.Split(' ', StringSplitOptions.RemoveEmptyEntries);
		if (parts.Length < 5) return null;

		if (!int.TryParse(parts[0], out var synsetOffset)) return null;
		// parts[1] lex_filenum ignored
		var ssTypeStr = parts[2];
		if (ssTypeStr.Length != 1) return null;
		var ssType = ssTypeStr[0];

		// w_cnt is hex
		if (!int.TryParse(parts[3], System.Globalization.NumberStyles.HexNumber, null, out var wCnt)) return null;
		if (wCnt <= 0) return null;

		var idx = 4;
		var words = new List<string>(wCnt);

		// Read w_cnt pairs: (word, lex_id)
		for (var i = 0; i < wCnt; i++)
		{
			if (idx + 1 >= parts.Length) return null;

			var w = parts[idx];
			// parts[idx+1] is lex_id (hex) - ignore for now
			idx += 2;

			// Normalize underscores to spaces for game-friendly output, but keep meaning
			words.Add(w.Replace('_', ' '));
		}

		if (idx >= parts.Length) return null;

		// p_cnt
		if (!int.TryParse(parts[idx], out var pCnt)) return null;
		idx += 1;

		var pointers = new List<WordNetPointer>(pCnt);

		// Each pointer is 4 tokens: symbol, target_offset, pos, source/target
		for (var i = 0; i < pCnt; i++)
		{
			if (idx + 3 >= parts.Length) break;

			var symbol = parts[idx];
			if (!int.TryParse(parts[idx + 1], out var targetOff)) break;
			var targetPosStr = parts[idx + 2];
			var sourceTarget = parts[idx + 3];

			var targetPos = targetPosStr.Length == 1 ? targetPosStr[0] : '?';

			pointers.Add(new WordNetPointer(symbol, targetOff, targetPos, sourceTarget));
			idx += 4;
		}

		// Frames exist only for verbs and appear after pointers; we ignore frames for now.

		return new WordNetSynset(
			Offset: synsetOffset,
			SsType: ssType,
			Words: words,
			Gloss: gloss,
			Pointers: pointers
		);
	}

	private Dictionary<string, List<int>>? GetIndex(char pos) => pos switch
	{
		'n' => _nounIndex,
		'v' => _verbIndex,
		'a' => _adjIndex,
		'r' => _advIndex,
		_ => null
	};

	private string? GetDataPath(char pos) => pos switch
	{
		'n' => _dataNounPath,
		'v' => _dataVerbPath,
		'a' => _dataAdjPath,
		'r' => _dataAdvPath,
		_ => null
	};

	private static string NormalizeLemma(string s) => s.Trim().ToLowerInvariant();

	private static string NormalizeToken(string s)
	{
		// crude token normalization for scoring (strip punctuation ends)
		s = s.Trim().ToLowerInvariant();
		while (s.Length > 0 && char.IsPunctuation(s[0])) s = s[1..];
		while (s.Length > 0 && char.IsPunctuation(s[^1])) s = s[..^1];
		return s;
	}

	public void Dispose()
	{
		// nothing to dispose currently because we open data files per read
		// (If you later optimize to persistent FileStreams, dispose them here.)
	}
}

public sealed record WordNetSynset(
	int Offset,
	char SsType,
	List<string> Words,
	string Gloss,
	List<WordNetPointer> Pointers
);

public sealed record WordNetPointer(
	string Symbol,
	int TargetOffset,
	char TargetPos,
	string SourceTarget
);
