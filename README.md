# Lexical Rogue

Scrabble meets Balatro: a roguelike deckbuilder where you spell
words from a deck of letter characters, and damage flows from the
semantic similarity between your word and the enemy's nature.
Built with Godot 4.7 (standard build, pure GDScript).

Full design document: [docs/GDD.md](docs/GDD.md).
Code style: [docs/gdscript-style.md](docs/gdscript-style.md).

## The loop

Fight → draw a hand of letters → read the enemy's word tags →
spell a word that resonates against them → the enemy retaliates →
earn gold → shop and hear the bard retell your journey at the
tavern → choose the next encounter → reach and defeat the boss.

## Setup

1. Install [Godot 4.7+](https://godotengine.org/) (standard
   build; .NET is not needed).
2. Download the WordNet 3.1 database and place its `dict` folder
   at `assets/wordnet/dict` — see `assets/wordnet/SETUP.txt`.
   The database is not committed to the repository.
3. Open the project in Godot and run.

The first launch parses WordNet (~1 s) and caches a binary index
in `user://`; later launches load in well under a second.

## Architecture

- `scripts/nlp/` — WordNet reader (index/data file parsing,
  lemmatization), semantic scorer (Wu-Palmer over hypernyms,
  cross-POS derivation hops, gloss-noun association), storyteller.
- `scripts/autoloads/` — `WordNet` (the single game-facing NLP
  interface), `RunState` (run data), `EventBus` (signals).
- `scripts/word/` — letter stats, deck manager, word validator.
- `scripts/combat/` — damage calculator, enemy factory, enemy,
  combat controller (turn state machine).
- `scripts/tavern/` — economy system, tavern controller.
- `data/` — enemy and relic definitions (JSON).
- `tools/` — headless test scenes (see below).

## Tests

Headless checks run from the project root:

```
godot --headless --path . -s res://tools/wordnet_smoke_test.gd
godot --headless --path . res://tools/combat_sim_test.tscn
godot --headless --path . res://tools/tavern_sim_test.tscn
```

## Debug tools

F12 toggles the developer overlay in-game: full damage-math
breakdown of the last word, a live similarity tester, gold and
healing cheats, skip-to-tavern, and forcing enemy tags or drawn
letters.
