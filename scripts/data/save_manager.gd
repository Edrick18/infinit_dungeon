class_name SaveManager
extends RefCounted
## Rohe Datei-I/O fürs Speichern: JSON nach user://savegame.json.
## Kennt nichts vom Spielzustand selbst — das übernimmt GameState
## (to_save_dict()/apply_save_dict()), damit sich beides unabhängig testen lässt.

const SAVE_PATH := "user://savegame.json"


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
