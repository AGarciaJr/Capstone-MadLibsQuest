extends Node

func _ready():
	# Wait 1 frame to avoid initialization order weirdness
	print("WordNet Synsets Function Working")
	await get_tree().process_frame

	print("WordNet IsReady:", WordNet.is_ready)
	print("WordNet SynsetsReady:", WordNet.synsets_ready())

	# If not ready, stop early (otherwise you’ll just get empty arrays)
	if not WordNet.is_ready or not WordNet.synsets_ready():
		print("WordNet not ready; check Autoload setup and dict path.")
		return

	var w := "torrent"
	print("Synset words:", WordNet.get_synset_words(w, "noun"))
	print("Glosses:", WordNet.get_synset_glosses(w, "noun"))

	# This prints the detailed synsets to the Godot output console
	WordNet.debug_print_synsets(w, "noun")
