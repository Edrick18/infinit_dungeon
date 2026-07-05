class_name SaveManager
extends RefCounted
## Rohe Datei-I/O fürs Speichern: JSON nach user://savegame*.json.
## Kennt nichts vom Spielzustand selbst — das übernimmt GameState
## (to_save_dict()/apply_save_dict()), damit sich beides unabhängig testen lässt.
##
## Mehrere Spielstände: Slot 1 = der klassische Pfad (alte Stände laufen
## unverändert weiter), Slot 2+ bekommen eigene Dateien. Welcher Slot aktiv
## ist, merken sich die Einstellungen (Settings.save_slot).

const SAVE_PATH := "user://savegame.json"
const SLOT_COUNT := 5

static var active_slot := 1


static func path_for_slot(slot: int) -> String:
	return SAVE_PATH if slot <= 1 else "user://savegame_slot%d.json" % slot


static func active_path() -> String:
	return path_for_slot(active_slot)


## Kurzinfo eines Slots für die Spielstand-Übersicht (leerer Dict = leer).
static func slot_info(slot: int) -> Dictionary:
	var data := load_data(path_for_slot(slot))
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
	}


## path ist überschreibbar, damit Tests einen eigenen Pfad nutzen können
## statt den echten Spielstand des Spielers zu überschreiben.
static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


static func save(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


## Leeres Dictionary, wenn kein Spielstand existiert oder er beschädigt ist.
static func load_data(path: String = SAVE_PATH) -> Dictionary:
	if not has_save(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func delete_save(path: String = SAVE_PATH) -> void:
	if has_save(path):
		DirAccess.remove_absolute(path)
