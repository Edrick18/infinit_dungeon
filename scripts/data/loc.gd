class_name Loc
extends RefCounted
## Winzige Lokalisierungs-Schicht: Deutsch ist die Quellsprache, Englisch
## die erste Übersetzung (weitere später). Die Sprache liegt im GameState
## und wird gespeichert.

static var language := "de"


## Sprache wechseln UND die Definitions-Caches leeren: Anzeigenamen werden
## beim Bibliotheks-Aufbau via pick() gebacken — nach dem Wechsel bauen die
## Bibliotheken frisch in der neuen Sprache. (Bereits erzeugte Instanzen wie
## Inventar-Items aktualisieren sich beim naechsten Speichern/Laden.)
static func set_language(lang: String) -> void:
	language = lang
	BlockLibrary.reset_cache()
	ItemLibrary.reset_cache()
	EnemyLibrary.reset_cache()
	ConsumableLibrary.reset_cache()


static func pick(de: String, en: String) -> String:
	return en if language == "en" else de


static func language_name() -> String:
	return "English" if language == "en" else "Deutsch"
