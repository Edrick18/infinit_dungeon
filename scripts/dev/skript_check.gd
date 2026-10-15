extends Node
## Skript-Check: lädt JEDES .gd des Projekts (mit Autoloads, darum als Szene
## statt -s) und meldet Parse-/Kompilierfehler. Die Selbsttests laden UI- und
## Dungeon-Szenen nicht — am 2026-10-16 rutschte so ein Parse-Fehler in der
## Dungeon-Szene einen Tag lang bis in die EXE.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . res://scripts/dev/skript_check.tscn

var _fehler: Array[String] = []
var _geprueft := 0


func _ready() -> void:
	_ordner("res://scripts")
	_ordner("res://autoload")
	if _fehler.is_empty():
		print("SELFTEST OK — %d Skripte fehlerfrei geladen" % _geprueft)
		get_tree().quit(0)
	else:
		for pfad in _fehler:
			printerr("  FEHLER: lädt nicht: " + pfad)
		print("SELFTEST FEHLGESCHLAGEN — %d von %d Skripten mit Fehlern" % [_fehler.size(), _geprueft])
		get_tree().quit(1)


func _ordner(pfad: String) -> void:
	var dir := DirAccess.open(pfad)
	if dir == null:
		return
	for unter in dir.get_directories():
		_ordner(pfad.path_join(unter))
	for datei in dir.get_files():
		if not datei.ends_with(".gd"):
			continue
		var voll := pfad.path_join(datei)
		_geprueft += 1
		var skript := ResourceLoader.load(voll, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if skript == null or not skript.can_instantiate():
			_fehler.append(voll)
