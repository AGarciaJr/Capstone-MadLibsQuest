# Lexical Rogue: Godot Prototype Game Design Document

## 1. Game Idea & High-Level Concept
The purpose of this barebones prototype is to validate the core fantasy: Scrabble meets Balatro, where players use a deck of modified letters to spell words that deal damage based on semantic similarity to enemy tags.

*   **Genre:** Roguelike deckbuilder / Word puzzle RPG.
*   **Perspective & Tone:** 2D card-game layout heavily inspired by Balatro, set within a fantasy tavern aesthetic.
*   **Players:** Single-player.
*   **Core Design Thesis:** Combat effectiveness is driven not just by word length, but by linguistic creativity, utilizing Princeton's WordNet package for semantic similarity, character classes, and parts of speech.
*   **Progression:** Roguelike run structure where players earn gold from fights to buy new characters, level up current characters, drop characters, buy items, and buy passive relics in a tavern. 

## 2. Core Features & Gameplay Loop
The prototype must prioritize the following core systems to build a functional loop.

*   **Core Game Loop:** Enter fight -> draw hand of letters -> read enemy modifiers -> enter word effective against that enemy -> enemy retaliates -> win and earn gold -> buy things at tavern -> listen to story so far -> choose next encounter -> try to make it to the final boss.
*   **Win/Loss Conditions:** The win state is making it to and defeating the final boss. The loss state is the player's health reaching zero during combat.
*   **The World/Map:** A run-based progression system where players choose their next encounter after visiting the tavern.
*   **Base/Hub:** The Tavern serves as the shop and deck management hub. Additionally, it features an NLP storyteller that recounts the player's journey so far using the specific words used by both the player and enemies during encounters.
*   **Architecture:** Standalone single-player client utilizing local Python/WordNet integration for NLP processing.

## 3. Detailed Specifications

### Core Entities & AI
*   **Enemies:** Enemies are entities with health pools and attack values that spawn with random word tags (e.g., "big" or "fiery"). 
*   **Letter Characters:** The "deck" consists of letter characters. These are not static tiles; they are entities that can take on different modifiers, classes, and levels.
*   **The NLP Storyteller:** A dynamic system in the tavern that parses the history of words played in combat to generate a recounted narrative of the journey.

### Player Movement & Controls
*   Required player states: Navigating UI, Deck Management, Combat Drafting.
*   **Word Drafting:** Players draw a hand of letters and attempt to make a word using as many drawn letters as possible. Players can use letters not in their hand to complete words, but are mechanically encouraged to rely on their drawn hand.

### Core Interactions & Systems
*   **Damage Calculation:** Damage is calculated by considering the length of the word, the number of drawn characters used, character modifiers and classes, the word's part of speech, and the individual character levels.
*   **Semantic Combat (WordNet Integration):** The game uses the WordNet package from Princeton to implement NLP. This system determines how effective a played word is against an enemy based on the semantic similarity between the player's word and the enemy's word tags.
*   **Economy:** Players earn gold by winning encounters, which is spent in the tavern to modify the letter deck and purchase passive relics.

## 4. Technical Implementation Scope
The AI agent can take whatever development path it likes to build the prototype, but it must keep strictly to this list of features to implement—and absolutely no more.

1.  Balatro-style 2D UI layout for combat and tavern screens.
2.  Deck structure and letter drawing logic.
3.  Basic word input and dictionary validation.
4.  Implementation of the WordNet package for semantic similarity scoring and part-of-speech tagging.
5.  Enemy spawning with assigned random word tags.
6.  Complex damage math factoring in letter classes, modifiers, levels, and NLP semantic similarity.
7.  Turn-based combat state machine (Player drafts word -> Enemy takes damage -> Enemy retaliates).
8.  Tavern economy interface (buy/upgrade/drop letters, buy items/relics).
9.  Encounter selection menu.
10. NLP storytelling text generation in the tavern.

**Non-Goals:** Do not implement real-time combat, 3D graphics, multiplayer, grid-based movement, or complex visual attack animations.

## 5. Architectural & Code Design Guidelines
To ensure the prototype is maintainable and easily expandable in the future, adhere to the following code design disciplines:
*   **No God Objects:** Do not design monolithic "Core", "Game", or "GameManager" objects that handle everything.
*   **Separation of Concerns:** Split functionality into distinct, focused objects and node components for clarity (e.g., separate `WordValidator`, `SemanticScorer`, `DeckManager`, `EconomySystem`).
*   **Loose Coupling:** Ensure objects are not tightly coupled. Use Godot's signal system to communicate between disconnected systems rather than hardcoding node paths or direct script references. The WordNet Python integration should be cleanly abstracted behind a single Godot interface class.

## 6. Debugging & Developer Tools
Implement dedicated debug capabilities to accelerate testing and iteration. Specific implementations are game-dependent, but should generally include:
*   **Debug Menu/Shortcuts:** Include a simple way to toggle debug features (e.g., a hidden UI overlay or specific F-keys).
*   **Game-Specific Testing Tools:** Add debug buttons to instantly draw specific letters, force-spawn an enemy with a specific semantic tag (e.g., force "fiery"), skip to the tavern, and grant infinite gold.
*   **NLP Debugging:** Display a visual breakdown of the damage calculation on screen during debug mode, explicitly showing the WordNet semantic similarity score, part-of-speech multiplier, and letter modifier bonuses.
