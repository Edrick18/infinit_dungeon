extends SceneTree
## Headless-Selbsttest für die prozedurale Sound-Synthese:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/sound_selftest.gd

var failures := 0


func _init() -> void:
	_test_generation()
	_test_playback()
	if failures == 0:
		print("SELFTEST OK — alle Sound-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _test_generation() -> void:
	print("Klang-Synthese:")
	var sfx: Node = load("res://autoload/sfx.gd").new()
	var sounds: Dictionary = sfx.generate_all()
	_check(sounds.size() >= 16, "mindestens 16 Klänge im Katalog (%d)" % sounds.size())

	# Alle im Spiel verdrahteten Namen müssen existieren (Tippfehler-Schutz).
	var wired: Array[StringName] = [&"ui_klick", &"bestaetigen", &"fehler",
		&"kampf_start", &"treffer", &"zauber", &"heilung", &"sieg", &"niederlage",
		&"level_up", &"gold", &"truhe", &"trank", &"treppe",
		&"schrein", &"opferstein", &"mimic"]
	var all_known := true
	for name in wired:
		if not sounds.has(name):
			all_known = false
			printerr("    fehlt: %s" % name)
	_check(all_known, "alle verdrahteten Sound-Namen existieren im Katalog")

	var all_valid := true
	for name in sounds:
		var stream: AudioStreamWAV = sounds[name]
		if stream == null or stream.data.size() < 100 or stream.get_length() <= 0.0:
			all_valid = false
			printerr("    kaputt: %s" % name)
	_check(all_valid, "jeder Klang hat echte Samples und eine Länge > 0")

	var victory: AudioStreamWAV = sounds[&"sieg"]
	var click: AudioStreamWAV = sounds[&"ui_klick"]
	_check(victory.get_length() > click.get_length(),
		"Fanfare ist länger als ein UI-Klick (%.2fs > %.2fs)"
		% [victory.get_length(), click.get_length()])
	sfx.free()


func _test_playback() -> void:
	print("Abspielen (Headless-Dummy-Treiber):")
	var sfx: Node = load("res://autoload/sfx.gd").new()
	root.add_child(sfx)
	# Darf headless weder crashen noch Fehler werfen — auch bei unbekannten Namen.
	sfx.play(&"treffer")
	sfx.play(&"gibt_es_nicht")
	_check(true, "play() läuft headless durch (bekannte und unbekannte Namen)")
	sfx.enabled = false
	sfx.play(&"treffer")
	_check(true, "deaktiviert: play() bleibt still statt zu crashen")
	root.remove_child(sfx)
	sfx.free()
