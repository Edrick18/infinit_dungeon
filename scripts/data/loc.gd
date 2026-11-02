class_name Loc
extends RefCounted
## Winzige Lokalisierungs-Schicht: Deutsch ist die Quellsprache, Englisch
## die erste Übersetzung (weitere später). Die Sprache liegt im GameState
## und wird gespeichert.

static var language := "de"


## Sprache wechseln UND die Definitions-Caches leeren: Anzeigenamen werden
## beim Bibliotheks-Aufbau via pick() gebacken — nach dem Wechsel bauen die
## Bibliotheken frisch in der neuen Sprache. (Bereits erzeugte Inventar-Items
## schlagen ihre Namen über die IDs nach — ItemInstance.get_display_name.)
## Karten- und Skillnamen aus Pools/Vorlagen bauen sich beim Lesen in der
## aktuellen Sprache (DungeonCard.name_teile, Skill.name_key).
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


## Dezimalzahl mit `stellen` Nachkommastellen: Komma im Deutschen, Punkt im
## Englischen (1,5 / 1.5).
static func zahl(wert: float, stellen := 1) -> String:
	var text := ("%." + str(maxi(0, stellen)) + "f") % wert
	return text if language == "en" else text.replace(".", ",")


## Anzahl mit passendem Wort: anzahl(1, "Runde", "Runden", "round", "rounds")
## » „1 Runde“, anzahl(3, …) » „3 Runden“.
static func anzahl(n: int, de1: String, de_n: String, en1: String, en_n: String) -> String:
	var wort := pick(de1, en1) if n == 1 else pick(de_n, en_n)
	return "%d %s" % [n, wort]
