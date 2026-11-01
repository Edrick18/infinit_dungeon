extends SceneTree
## Headless-Selbsttest der Dungeon-Grafik (STIL-3D.md 5b/7b):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/grafik_selftest.gd
## Prüft Datensätze und reine Funktionen — Biom-Stil, Wandhöhe, Licht-Pool,
## Lauf-Hopser, Fasen-Box, Fackel ohne Eigenlicht, Screen-Door-Shader.

var failures := 0


func _init() -> void:
	_test_biom_stil()
	_test_wand_hoehe()
	_test_licht_pool()
	_test_hopser()
	_test_fasen_box()
	_test_fackel()
	_test_shader_code()
	if failures == 0:
		print("SELFTEST OK — alle Grafik-Tests bestanden")
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


func _test_biom_stil() -> void:
	print("BiomStil:")
	var pflicht := ["floor_tint", "wall_tint", "deco", "boden", "wand", "deckel", "moos", "muster",
		"stein", "moos_wand", "moos_deckel", "fuge", "ambient", "ambient_energie", "licht",
		"licht_energie", "laterne", "tief", "nebel", "partikel", "funke"]
	for biom in Enums.Biome.values():
		_check(BiomStil.DATEN.has(biom), "Datensatz für Biom %d vorhanden" % biom)
		var roh: Dictionary = BiomStil.DATEN.get(biom, {})
		var fehlt := pflicht.filter(func(k: String) -> bool: return not roh.has(k))
		_check(fehlt.is_empty(), "Biom %d hat alle Schlüssel (fehlt: %s)" % [biom, fehlt])
		for k in BiomStil.PAL_SCHLUESSEL:
			_check(Stil3D.PAL.has(roh.get(k, "")), "Biom %d: %s ist eine PAL-Farbe" % [biom, k])
		_check(roh.get("partikel", "") in BiomStil.PARTIKEL_ARTEN, "Biom %d: Partikel-Art bekannt" % biom)
		var stil := BiomStil.fuer(biom)
		_check(stil["boden"] is Color and int(stil["biom"]) == biom, "Biom %d: fuer() löst Farben auf" % biom)
		# Der Deckel ist nie die hellste Fläche: dunkler als der Boden.
		var deckel: Color = stil["deckel"]
		var boden: Color = stil["boden"]
		_check(deckel.get_luminance() < boden.get_luminance(), "Biom %d: Deckel dunkler als Boden" % biom)
	_check(int(BiomStil.fuer(99)["biom"]) == Enums.Biome.FOREST, "Unbekanntes Biom fällt auf Wald zurück")
	var kampf := BiomStil.fuer(Enums.Biome.CAVE)
	_check(kampf["floor_tint"] is Color and kampf["deco"] is Array, "Datensatz liefert weiter Tönung + Deko (Kampfbühne)")


func _test_wand_hoehe() -> void:
	print("Wandhöhe:")
	var alle_im_rahmen := true
	var verschieden := {}
	for y in 40:
		for x in 40:
			var h := WeltBau.wand_hoehe(Vector2i(x, y))
			alle_im_rahmen = alle_im_rahmen and h >= 0.86 and h <= 1.26
			verschieden[snappedf(h, 0.001)] = true
	_check(alle_im_rahmen, "Höhe immer zwischen 0.86 und 1.26")
	_check(verschieden.size() >= 5, "Höhen-Jitter erzeugt mehrere Stufen (%d)" % verschieden.size())
	_check(is_equal_approx(WeltBau.wand_hoehe(Vector2i(7, 3)), WeltBau.wand_hoehe(Vector2i(7, 3))),
		"Höhe deterministisch je Zelle")


func _test_licht_pool() -> void:
	print("Licht-Pool:")
	_check(WeltBau.POOL_GROESSE + 1 <= 8, "Laterne + Pool unter 8 Lichtern pro Objekt")
	var orte: Array[Vector3] = [Vector3(10, 0, 0), Vector3(1, 0, 0), Vector3(30, 0, 0), Vector3(0, 0, 2),
		Vector3(3, 0, 3), Vector3(-5, 0, 0), Vector3(0, 0, -7), Vector3(8, 0, 8)]
	var wahl := WeltBau.pool_auswahl(orte, Vector3.ZERO, 3, 13.0)
	_check(wahl == [1, 3, 4], "die drei nächsten aufsteigend (%s)" % [wahl])
	var weit := WeltBau.pool_auswahl(orte, Vector3.ZERO, 20, 13.0)
	_check(weit.size() == 7 and not weit.has(2), "nur innerhalb der Reichweite (%d)" % weit.size())
	var leer: Array[Vector3] = []
	_check(WeltBau.pool_auswahl(leer, Vector3.ZERO, 6, 13.0).is_empty(), "keine Fackeln » kein Licht")


func _test_hopser() -> void:
	print("Lauf-Hopser:")
	var p := 0.0
	for i in 10:
		p = WeltBau.naechster_hopser(p, true, 0.05)
	_check(p > 1.0, "beim Laufen läuft die Phase weiter (%.2f)" % p)
	for i in 30:
		p = WeltBau.naechster_hopser(p, false, 0.05)
	_check(is_equal_approx(p, ceilf(p)), "im Stand landet der Held (Phase ganzzahlig: %.3f)" % p)
	var fest := p
	p = WeltBau.naechster_hopser(p, false, 0.05)
	_check(is_equal_approx(p, fest), "im Stand bleibt er am Boden")


func _test_fasen_box() -> void:
	print("Fasen-Box:")
	var mesh := WeltMaterial.fasen_box(Vector3(1.0, 0.12, 1.0), 0.035)
	var aabb := mesh.get_aabb()
	_check(aabb.size.is_equal_approx(Vector3(1.0, 0.12, 1.0)), "Maße wie angegeben (%s)" % aabb.size)
	var arrays := mesh.surface_get_arrays(0)
	var ecken: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normalen: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# 6 Flächen + 12 Fasen (je 2 Dreiecke) + 8 Ecken = 44 Dreiecke.
	_check(ecken.size() == 44 * 3, "44 Dreiecke (%d Ecken)" % ecken.size())
	var aussen := true
	for i in range(0, ecken.size(), 3):
		var mitte := (ecken[i] + ecken[i + 1] + ecken[i + 2]) / 3.0
		aussen = aussen and normalen[i].dot(mitte) > 0.0 and is_equal_approx(normalen[i].length(), 1.0)
	_check(aussen, "alle Normalen zeigen nach außen")


func _test_fackel() -> void:
	print("Fackel:")
	var mit := FigurenBau.fackel()
	_check(mit.has_meta("licht") and not mit.find_children("*", "OmniLight3D", true, false).is_empty(),
		"Menü/Kampf-Fackel trägt ihr Licht")
	# Weiches Toon-Licht: Menü/Kampf-Fackeln brauchen flacheren Abfall und
	# Energie-Ausgleich, sonst verschwinden ihre warmen Flecken.
	var licht: OmniLight3D = mit.get_meta("licht")
	_check(licht.omni_attenuation < 1.0 and Stil3D.PUNKTLICHT_AUSGLEICH > 1.0,
		"Menü/Kampf-Fackel mit flachem Abfall und Energie-Ausgleich")
	var dungeon := FigurenBau.fackel(false, true)
	_check(not dungeon.has_meta("licht") and dungeon.find_children("*", "OmniLight3D", true, false).is_empty(),
		"Dungeon-Fackel ohne Eigenlicht (Licht-Pool)")
	_check(dungeon.get_child_count() > mit.get_child_count() - 1, "Dungeon-Fackel hat einen Wandhalter")
	mit.free()
	dungeon.free()


func _test_shader_code() -> void:
	print("Screen-Door-Shader:")
	_check("INSTANCE_CUSTOM.a" in Stil3D.kontur_code(true) and "discard" in Stil3D.kontur_code(true),
		"Kontur dithert mit (liest INSTANCE_CUSTOM.a)")
	_check(not "INSTANCE_CUSTOM" in Stil3D.kontur_code(false), "normale Kontur ohne Instanzdaten")
	_check("discard" in WeltMaterial.WAND_CODE and "bayer4" in WeltMaterial.WAND_CODE
		and not "ALPHA" in WeltMaterial.WAND_CODE, "Wand bleibt opak (Screen-Door statt ALPHA)")
	_check("ATTENUATION" in Stil3D.TOON_LICHT and "stufe * ATTENUATION" in Stil3D.TOON_LICHT,
		"Toon-Stufen nur auf N·L, Abschwächung weich")
