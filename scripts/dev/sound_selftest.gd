extends SceneTree
## Headless-Selbsttest für die prozedurale Sound-Synthese:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/sound_selftest.gd

var failures := 0


func _init() -> void:
	_test_generation()
	_test_playback()
	_test_kampf_klaenge()
	_test_musik()
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
		&"schrein", &"opferstein", &"mimic", &"schmiede", &"kaufen", &"flucht",
		&"tod", &"gegner_besiegt", &"wiederbelebung", &"pfeil", &"ausruesten"]
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
	sfx.bus_anlegen()
	_check(AudioServer.get_bus_index(&"Effekte") >= 0, "Effekte-Bus existiert")
	# Drosselung: derselbe Klang zweimal sofort hintereinander = einmal.
	_check(sfx._drossel_frei(&"block") and not sfx._drossel_frei(&"block"),
		"derselbe Klang innerhalb von %d ms wird nur einmal gespielt" % sfx.MIN_ABSTAND_MS)
	_check(sfx._drossel_frei(&"krit"), "ein anderer Klang darf gleichzeitig spielen")
	sfx.enabled = false
	sfx.play(&"treffer")
	_check(true, "deaktiviert: play() bleibt still statt zu crashen")
	root.remove_child(sfx)
	sfx.free()


func _test_kampf_klaenge() -> void:
	print("Kampf-Ereignisse » Klänge:")
	var sfx_skript: GDScript = load("res://autoload/sfx.gd")
	var sfx: Node = sfx_skript.new()
	var sounds: Dictionary = sfx.generate_all()
	sfx.free()
	var ereignisse: Array[Dictionary] = [
		{"art": &"waffe"}, {"art": &"waffe", "fern": true}, {"art": &"magie"},
		{"art": &"heilung"}, {"art": &"krit"}, {"art": &"krit", "vernichtend": true},
		{"art": &"block"}, {"art": &"dot"}, {"art": &"beschwoerung"},
		{"art": &"aufladung"}, {"art": &"entfesselt"}, {"art": &"bannwelle"},
		{"art": &"status", "status": Enums.Status.PROTECT},
		{"art": &"status", "status": Enums.Status.ATK_UP},
		{"art": &"status", "status": Enums.Status.WEAKEN},
		{"art": &"element", "element": Enums.Element.HOLY, "heilt": true},
	]
	for element in Enums.Element.values():
		ereignisse.append({"art": &"element", "element": element})
	var alle_da := true
	for e in ereignisse:
		var klang: StringName = sfx_skript.klang_fuer(e)
		if klang == &"" or not sounds.has(klang):
			alle_da = false
			printerr("    kein Klang für %s (%s)" % [e, klang])
	_check(alle_da, "jedes Kampf-Ereignis (%d Arten) hat einen existierenden Klang" % ereignisse.size())
	_check(sfx_skript.klang_fuer({"art": &"status", "status": Enums.Status.ATK_UP}) == &"buff"
		and sfx_skript.klang_fuer({"art": &"status", "status": Enums.Status.WEAKEN}) == &"debuff",
		"Stärkung klingt als Buff, Schwächung als Debuff")
	_check(sfx_skript.klang_fuer({"art": &"element", "element": Enums.Element.FIRE}) == &"feuer"
		and sfx_skript.klang_fuer({"art": &"element", "element": Enums.Element.ICE}) == &"eis",
		"jedes Element hat seinen eigenen Klang")
	_check(sfx_skript.klang_fuer({"art": &"unbekannt"}) == &"", "unbekannte Ereignisse bleiben still")


func _test_musik() -> void:
	print("Musik (Partituren und Rendern):")
	var musik: Node = load("res://autoload/music.gd").new()
	var vollstaendig := true
	for name in musik.RENDER_REIHENFOLGE:
		if name != &"sieg" and name != &"niederlage" and not musik.PARTITUREN.has(name):
			vollstaendig = false
	_check(vollstaendig, "jeder Track in der Render-Reihenfolge hat eine Partitur")
	for biom in Enums.Biome.values():
		var track: StringName = musik.biom_track(biom)
		_check(musik.PARTITUREN.has(track), "Biom %d hat einen eigenen Track (%s)" % [biom, track])
	var stadt: AudioStreamWAV = musik.render_partitur(musik.PARTITUREN[&"stadt"])
	_check(stadt.stereo and stadt.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Track ist ein Stereo-Loop")
	_check(stadt.get_length() >= 40.0, "Stadt-Track ist lang genug (%.0f s ≥ 40 s)" % stadt.get_length())
	var stille := true
	for i in range(0, stadt.data.size() - 1, 4001 * 2):
		if absi(stadt.data.decode_s16(i)) > 200:
			stille = false
			break
	_check(not stille, "Track enthält hörbare Samples")
	var sieg: AudioStreamWAV = musik.render_sieg()
	_check(sieg.loop_begin > 0 and sieg.loop_begin < sieg.loop_end,
		"Sieg: Fanfare einmal, danach Schleife (loop_begin %d)" % sieg.loop_begin)
	musik.free()
