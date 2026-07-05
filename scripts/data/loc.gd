class_name Loc
extends RefCounted
## Winzige Lokalisierungs-Schicht: Deutsch ist die Quellsprache, Englisch
## die erste Übersetzung (weitere später). Die Sprache liegt im GameState
## und wird gespeichert.

static var language := "de"


static func pick(de: String, en: String) -> String:
	return en if language == "en" else de


static func language_name() -> String:
	return "English" if language == "en" else "Deutsch"
