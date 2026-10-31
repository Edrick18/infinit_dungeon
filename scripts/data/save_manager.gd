class_name SaveManager
extends RefCounted
## Rohe Datei-I/O fürs Speichern: JSON nach user://savegame*.json.
## Kennt nichts vom Spielzustand selbst — das übernimmt GameState
## (to_save_dict()/apply_save_dict()), damit sich beides unabhängig testen lässt.
##
## Mehrere Spielstände: Slot 1 = der klassische Pfad (alte Stände laufen
## unverändert weiter), Slot 2+ bekommen eigene Dateien. Welcher Slot aktiv
## ist, merken sich die Einstellungen (Settings.save_slot).
##
## Atomar: save() schreibt erst nach <pfad>.tmp, legt den letzten lesbaren
## Stand als <pfad>.bak ab und benennt dann um. Ist die Hauptdatei unlesbar,
## lädt lesen() die Sicherung; eine unlesbare Hauptdatei ohne Sicherung
## gilt als DEFEKT (nie als leer) und wird vor dem Überschreiben nach
## <pfad>.defekt verschoben.

const SAVE_PATH := "user://savegame.json"
const SLOT_COUNT := 5

## Zustände von lesen().
const LEER := "leer"
const LESBAR := "lesbar"
const SICHERUNG := "sicherung"
const DEFEKT := "defekt"

static var active_slot := 1
## Pfad » Fingerabdruck (Änderungszeit, Größe) der Hauptdatei, als sie
## zuletzt nachweislich lesbar war. Spart das erneute Parsen vor jedem
## Speichern; wurde die Datei inzwischen von außen geändert, wird wieder
## geprüft (sonst landete eine kaputte Datei als .bak über der Sicherung).
static var _lesbar := {}


static func path_for_slot(slot: int) -> String:
	return SAVE_PATH if slot <= 1 else "user://savegame_slot%d.json" % slot


static func active_path() -> String:
	return path_for_slot(active_slot)


## Kurzinfo eines Slots für die Spielstand-Übersicht (leerer Dict = leer).
## Eine vorhandene, aber unlesbare Datei liefert {"defekt": true}; aus der
## Sicherung gelesene Stände tragen "sicherung": true.
static func slot_info(slot: int) -> Dictionary:
	return info_aus_pfad(path_for_slot(slot))


## slot_info für einen beliebigen Pfad (Selbsttests nutzen eigene Pfade).
static func info_aus_pfad(path: String) -> Dictionary:
	var ergebnis := lesen(path)
	if ergebnis["zustand"] == DEFEKT:
		return {"defekt": true}
	var data: Dictionary = ergebnis["daten"]
	if data.is_empty():
		return {}
	var hero_parts: Array[String] = []
	for member_data in data.get("party", []):
		hero_parts.append("%s (Lv %d)" % [member_data.get("name", "?"),
			int(member_data.get("level", 1))])
	return {
		"heroes": ", ".join(hero_parts),
		"reserve_count": data.get("reserve", []).size(),
		"gold": int(data.get("gold", 0)),
		"cards": data.get("cards", []).size(),
		"saved_at": String(data.get("saved_at", "")),
		"playtime_s": float(data.get("playtime_s", 0.0)),
		"sicherung": ergebnis["zustand"] == SICHERUNG,
	}


## path ist überschreibbar, damit Tests einen eigenen Pfad nutzen können
## statt den echten Spielstand des Spielers zu überschreiben.
static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Schreibt atomar: <pfad>.tmp » alte Hauptdatei wird <pfad>.bak (nur wenn
## lesbar; sonst <pfad>.defekt) » .tmp wird zur Hauptdatei.
static func save(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	var fehler := file.get_error()
	file.close()
	if fehler != OK or _lies_datei(tmp) == null:
		DirAccess.remove_absolute(tmp)
		return false
	if has_save(path):
		var ablage := path + ".bak"
		if not _bekannt_lesbar(path) and _lies_datei(path) == null:
			ablage = path + ".defekt"  # unlesbar: aufheben, die Sicherung bleibt
		if FileAccess.file_exists(ablage):
			DirAccess.remove_absolute(ablage)
		if DirAccess.rename_absolute(path, ablage) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		return false
	_lesbar[path] = _fingerabdruck(path)
	return true


## [Änderungszeit, Größe] einer Datei (leer, wenn sie fehlt).
static func _fingerabdruck(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var groesse := file.get_length()
	file.close()
	return [FileAccess.get_modified_time(path), groesse]


## War die Hauptdatei zuletzt lesbar und ist seitdem unverändert?
static func _bekannt_lesbar(path: String) -> bool:
	return _lesbar.has(path) and _lesbar[path] == _fingerabdruck(path)


## Inhalt eines Spielstands; leer, wenn keiner existiert oder weder Datei
## noch Sicherung lesbar sind (Unterscheidung über lesen()).
static func load_data(path: String = SAVE_PATH) -> Dictionary:
	return lesen(path)["daten"]


## {"daten": Dictionary, "zustand": LEER|LESBAR|SICHERUNG|DEFEKT,
##  "sicherung_von": Zeitpunkt der geladenen Sicherung}
static func lesen(path: String = SAVE_PATH) -> Dictionary:
	var haupt: Variant = _lies_datei(path)
	if haupt != null:
		_lesbar[path] = _fingerabdruck(path)
		return {"daten": haupt, "zustand": LESBAR, "sicherung_von": ""}
	_lesbar.erase(path)
	var bak_pfad := path + ".bak"
	if not has_save(path):
		# Abbruch zwischen den beiden Umbenennungen: die .tmp ist dann
		# vollständig (vorher geprüft) und neuer als die .bak.
		bak_pfad = path + ".tmp" if _lies_datei(path + ".tmp") != null else bak_pfad
	var bak: Variant = _lies_datei(bak_pfad)
	if bak != null:
		var zeit := String((bak as Dictionary).get("saved_at", ""))
		if zeit.is_empty():
			zeit = Time.get_datetime_string_from_unix_time(
				FileAccess.get_modified_time(bak_pfad), true)
		return {"daten": bak, "zustand": SICHERUNG, "sicherung_von": zeit}
	if has_save(path) or FileAccess.file_exists(bak_pfad):
		return {"daten": {}, "zustand": DEFEKT, "sicherung_von": ""}
	return {"daten": {}, "zustand": LEER, "sicherung_von": ""}


## Geparstes Dictionary oder null (fehlt, leer, kein gültiges JSON-Objekt).
static func _lies_datei(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	# JSON-Instanz statt parse_string: ein kaputter Stand soll still als
	# unlesbar gelten, nicht als Engine-Fehler in der Konsole landen.
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	return json.data


## Entfernt den Slot ganz: Hauptdatei, Sicherung und Reste.
static func delete_save(path: String = SAVE_PATH) -> void:
	for pfad in [path, path + ".bak", path + ".tmp", path + ".defekt"]:
		if FileAccess.file_exists(pfad):
			DirAccess.remove_absolute(pfad)
	_lesbar.erase(path)
