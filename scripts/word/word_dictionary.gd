extends Node
class_name WordDictionary

enum SpeechPart {
	Noun,
	Verb,
	Adverb,
	Adjective,
	Preposition,
	Interjection
}

var dictionary := {
	"fire": SpeechPart.Verb,
	"burn": SpeechPart.Verb,
	"freeze": SpeechPart.Verb,
	"sword": SpeechPart.Noun
}
