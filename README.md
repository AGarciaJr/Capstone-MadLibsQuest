# Mad Libs Quest

A whimsical RPG adventure where **words have power**. Help the Bard restore a broken world by filling in the blanks of reality itself through creative Mad Libs storytelling.

## Features

- **Story-driven Mad Libs gameplay** - Your word choices shape the narrative
- **NLP-powered validation** - WordNet integration validates parts of speech
- **Pixel art aesthetic** - Charming top-down exploration
- **The Bard** - Your mystical guide who weaves your words into tales

## Setup

### Prerequisites

- [Godot 4.6+](https://godotengine.org/) with .NET support
- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

### WordNet Database Setup

The game uses [WordNet](https://wordnet.princeton.edu/) for natural language processing. You need to download the WordNet database files:

1. **Download WordNet 3.1**:
   - Go to: https://wordnet.princeton.edu/download/current-version
   - Download the database files (not the full installer)
   - Or use direct link: http://wordnetcode.princeton.edu/wn3.1.dict.tar.gz

2. **Extract and place the files**:
   ```
   assets/
   └── wordnet/
	   └── dict/
		   ├── data.adj
		   ├── data.adv
		   ├── data.noun
		   ├── data.verb
		   ├── index.adj
		   ├── index.adv
		   ├── index.noun
		   ├── index.verb
		   └── (other .exc and auxiliary files)
   ```

3. **Alternative: macOS Homebrew**:
   ```bash
   brew install wordnet
   # Apple Silicon (M1/M2/M3):
   cp -r /opt/homebrew/opt/wordnet/dict assets/wordnet/
   # Intel Mac:
   cp -r /usr/local/opt/wordnet/dict assets/wordnet/
   ```

### Building

1. Clone the repository
2. Open the project in Godot 4.6+
3. Build the C# solution:
   ```bash
   dotnet restore
   dotnet build
   ```
4. Run the game from the Godot editor

## Project Structure

```
├── assets/
│   ├── wordnet/dict/        # WordNet database (download separately)
│   └── Pixel Art Top Down/  # Sprite assets
├── scenes/
│   ├── intro_scene.gd/tscn  # Opening narrative + first Mad Lib
│   └── tutorial_area.gd/tscn # First explorable area
├── scripts/
│   ├── autoloads/           # Global singletons
│   ├── entities/
│   │   ├── player.gd        # Player character
│   │   └── bard.gd          # The Bard NPC
│   ├── nlp/
│   │   ├── WordNetService.cs    # Core WordNet logic
│   │   └── WordNetBridge.cs     # Godot<->C# bridge
│   └── GameData.gd          # Persistent game state
└── project.godot
```

## How Word Validation Works

When you enter a word for a Mad Lib blank:

1. The **Bard** asks for a specific part of speech (noun, verb, adjective, adverb)
2. **WordNet** checks if your word can be used as that part of speech
3. If valid: The word is accepted with positive feedback
4. If invalid: The Bard explains what type of word you actually entered

Example:
- Prompt: "Enter an adjective"
- You type: "run"
- Bard: "Woah there! That's not quite right! 'run' is actually a noun or verb!"

## License

Educational project - [Your License Here]

## Credits

- **WordNet** - Princeton University
- **Pixel Art Assets** - [Pixel Art Top Down - Basic](link)
- **Godot Engine** - https://godotengine.org/
