extends Control

signal overlay_closed

@onready var _body: RichTextLabel = $MarginRoot/VBox/Body

var _overlay_mode: bool = false


func _ready() -> void:
	_body.text = _tips_bbcode()


func set_overlay_mode(enabled: bool) -> void:
	_overlay_mode = enabled
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _overlay_mode:
		$MarginRoot/VBox/BackButton.text = "Back"


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _on_back_pressed() -> void:
	_go_back()


func _go_back() -> void:
	if _overlay_mode:
		overlay_closed.emit()
		queue_free()
	else:
		get_tree().change_scene_to_file(Scenes.MAIN_MENU)


func _tips_bbcode() -> String:
	return """[b][font_size=20]Run & dungeon[/font_size][/b]
First-person rooms use [b]captured mouse[/b]: move the mouse to look around. [b]Left-click[/b] when your crosshair is on a door to travel to the next node on your run.
Press [b]M[/b] to open the run map overlay; press [b]M[/b] again (or use the UI) to close it. The map shows how rooms connect and where you are.
[b]Continue[/b] on the main menu loads your saved run if a save exists. [b]Start[/b] begins a new run (you can choose tutorial or a generated run from there).

[b][font_size=20]Starting letters[/font_size][/b]
After you begin a new run, the Bard asks for your name and for [b]five[/b] starting letters. Those letters become your [b]player letters[/b] roster for the run. In battle, building words that include more of them (ideally all of them) strongly boosts damage (see below). Some rewards can add letters or improve letter damage later.

[b][font_size=20]Pre-battle: describe the enemy[/font_size][/b]
Before many fights you are asked for [b]one word[/b]: an [b]adjective[/b] that describes the foe (no spaces). If WordNet is available, the game checks that the word looks like an adjective; otherwise it accepts your word.
That word is matched to an [b]encounter modifier[/b] (bigger, stronger, cursed, plain, and many others). The modifier can change enemy [b]HP, attack, defense, armor, accuracy, crit chance[/b], and can add special rules (for example, some foes hurt themselves each turn or favor an element).
[b]Harder modifiers use a higher difficulty number.[/b] After you win, that difficulty is fed into item rolls: [b]higher difficulty tilts random rewards toward higher rarity[/b] (rarer picks are more likely). Easier or plain descriptions tilt the other way.
After you submit, read the [b]effect description[/b], then press [b]Continue[/b] (or equivalent) to start the fight with that modifier locked in.

[b][font_size=20]Mad-lib battle flow[/font_size][/b]
You see a story line with blanks (noun, verb, adjective, etc.). The prompt tells you which part of speech to type next. Fill blanks [b]in order[/b]: one word per blank, then Submit or press [b]Enter[/b].
The line preview updates as words are accepted. When the template has more than one sentence, the game advances to the next sentence after a full line is finished.

[b][font_size=20]When the enemy attacks[/font_size][/b]
In the usual rules, the enemy [b]does not deal damage[/b] until you have filled [b]every blank in the current sentence[/b]. Then their turn runs (they can hit once or more, depending on the encounter).
If you submit a word that [b]fails the part-of-speech check[/b], that counts as a mistake: [b]the enemy attacks right away[/b], and you stay on the [b]same blank[/b] to try again (your bad word is not locked in).
The same idea applies to [b]bonus strikes[/b] on fights that give you extra hits before the enemy acts: each bonus word must match the requested part of speech, or the enemy punishes you like a bad blank.

[b][font_size=20]Your letters and damage[/font_size][/b]
Damage uses your stats (attack, crit, etc.) and a [b]letter bonus multiplier[/b] from your current word:
• Each [b]distinct[/b] roster letter that appears anywhere in the word adds to the multiplier (the panel shows [b]Letter bonus per match[/b] and a live [b]Current letter multiplier[/b] while you type).
• If your word includes [b]every[/b] roster letter at least once, you get a large extra bonus on top (then the multiplier is capped by a run-wide cap you can raise with some items).
• If the word uses [b]none[/b] of your roster letters, that strike [b]misses[/b] for damage purposes (0 damage from you on that swing) — always try to include at least one featured letter.

[b][font_size=20]Repeat words[/font_size][/b]
Using the [b]same word again[/b] in the same battle (after it already dealt damage once) applies a stacking damage penalty so you cannot spam one answer.

[b][font_size=20]Word rarity (frequency)[/font_size][/b]
Rarer or less common dictionary words can apply a [b]frequency scaling[/b] factor to the strike. Creative vocabulary can pay off.

[b][font_size=20]Elements[/font_size][/b]
When the element system is on, your word is classified for elemental flavor. Confident matches feed into how that strike resolves alongside stats and letters.

[b][font_size=20]Defense, armor, and crits[/font_size][/b]
Enemy attacks use their move (base damage, scaling, accuracy) against your [b]defense[/b] and [b]armor[/b]. Your attacks can [b]crit[/b]; crits are called out in the result text.

[b][font_size=20]Enemy-only effects[/font_size][/b]
Some modifiers apply [b]status[/b] rules at the start of the enemy turn (for example, a percent of their max HP as self-damage). Those resolve after your sentence is complete and their hit phase is handled, where applicable.

[b][font_size=20]After the fight: rewards[/font_size][/b]
When you win, you typically get [b]three[/b] item choices. They are drawn from [b]three separate pools[/b]: [b]base stats[/b] (healing, stat boosts), [b]letter power[/b] (stronger letter bonuses, crit gear, etc.), and [b]letter acquisition[/b] (new letters or random letter bundles). The three offers are [b]shuffled[/b] on screen, so positions are not tied to pool order.
Each pick is weighted by [b]item rarity[/b] and the encounter [b]difficulty[/b] from your pre-battle adjective (harder fight → better odds on high-rarity items). If you are already at full HP, [b]healing items are removed[/b] from the stat pool so you are not offered unusable heals.

[b][font_size=20]Battle UI[/font_size][/b]
Use [b]Battle log[/b] to reread the fight. [b]Esc[/b] (cancel) closes overlays where the game assigns it; on this tips screen, Esc or [b]Back[/b] closes the screen (pause menu when opened from the game, main menu if you run this scene alone from the editor).

[b][font_size=20]If you are defeated[/font_size][/b]
Losing a battle clears the current [b]save[/b] for that run — treat each fight seriously, especially on harder modifiers.
""".strip_edges()
