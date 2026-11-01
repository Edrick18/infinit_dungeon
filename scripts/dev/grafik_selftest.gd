extends SceneTree
## Headless-Selbsttest der Dungeon-Grafik (STIL-3D.md 5b/7b):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/grafik_selftest.gd
## Prüft Datensätze und reine Funktionen — Biom-Stil, Wandhöhe, Licht-Pool,
## Lauf-Hopser, Fasen-Box, Fackel ohne Eigenlicht, Screen-Door-Shader;
## Paket 2: Bausatz (gebackene Grundkörper), Biom-Kulisse (Kronen, Deko,
## Hallen-Säule), Kronen-Auswahl, Boss-Arena aus dem Grundriss, Ziel-Modelle;
## Paket 3: Kampfhalle (Stellen, Licht-Budget, Boss-Stimmung, Kulisse),
## Projektil-Schweif (Band-Geometrie), echtes Gold;
## Paket 4 (Gerüst): Gliederpuppe (Pivots, Budget, Mesh-Cache, Ruhepose,
## Gold), Maßstab im Mesh (Kontur gleich dick), Rang- und Boss-Schmuck;
## Paket 4 (Zweibeiner): alle Zweibeiner-Gegner und Helden (Rollen, Farbwahl,
## Sonderfarben) als Gliederpuppen — Glieder, Budget, Gold, Ruhepose.

var failures := 0


func _init() -> void:
	_test_biom_stil()
	_test_wand_hoehe()
	_test_licht_pool()
	_test_hopser()
	_test_fasen_box()
	_test_fackel()
	_test_shader_code()
	_test_bausatz()
	_test_kulisse()
	_test_kronen_wahl()
	_test_boss_raum()
	_test_ziel_modelle()
	_test_kampfhalle()
	_test_schweif()
	_test_gold()
	_test_gliederpuppe()
	_test_massstab()
	_test_schmuck()
	_test_zweibeiner()
	_test_helden()
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


func _test_bausatz() -> void:
	print("Bausatz:")
	var box := Stil3D.box(0.4, 0.2, 0.3)
	var dick: BoxMesh = Bausatz.aufgeblaeht(box, 0.02)
	_check(dick.size.is_equal_approx(Vector3(0.44, 0.24, 0.34)) and box.size.is_equal_approx(Vector3(0.4, 0.2, 0.3)),
		"Hülle: Box um 2·Dicke größer, Original unverändert")
	var spitze: CylinderMesh = Bausatz.aufgeblaeht(Stil3D.kegel(0.2, 0.5), 0.02)
	_check(is_zero_approx(spitze.top_radius) and is_equal_approx(spitze.bottom_radius, 0.22),
		"Hülle: Kegelspitze bleibt spitz")
	var b := Bausatz.new()
	b.teil(Stil3D.box(0.2, 0.2, 0.2), Color("e8b44a"), Vector3(1, 0, 0))
	b.teil(Stil3D.kugel(0.1), Color("ff9a3a"), Vector3(0, 0.5, 0), Vector3.ZERO, false, 1.0)
	var mesh := b.mesh()
	var farben: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var leuchtet := false
	var normal := false
	for f in farben:
		leuchtet = leuchtet or is_zero_approx(f.a)
		normal = normal or is_equal_approx(f.a, 1.0)
	_check(leuchtet and normal, "Vertex-Alpha trägt das Leuchten (0 = volles Leuchten)")
	_check(absf(farben[0].r - Color("e8b44a").r) < 0.01, "Vertexfarbe bleibt sRGB (Godot wandelt COLOR selbst)")
	_check(mesh.get_aabb().position.x < 0.0 and mesh.get_aabb().end.x > 1.09, "Teile an ihrer Position gebacken")
	var huelle := b.huelle()
	_check(huelle != null and huelle.get_aabb().end.x > 1.11, "Hülle nur aus Kontur-Teilen, aufgebläht")
	var knoten := b.knoten("Test")
	_check(knoten.get_child_count() == 2, "ein Objekt = Körper + Hülle (zwei Zeichenaufrufe)")
	knoten.free()


func _test_kulisse() -> void:
	print("Biom-Kulisse:")
	for biom in Enums.Biome.values():
		var stil := BiomStil.fuer(biom)
		var kulisse: Dictionary = stil.get("kulisse", {})
		_check(String(kulisse.get("saeule", "")) in BiomKulisse.SAEULEN, "Biom %d: Hallen-Säule bekannt" % biom)
		var kronen: Array = kulisse.get("kronen", [])
		_check(not kronen.is_empty() and kronen.all(func(k: String) -> bool: return k in BiomKulisse.KRONEN),
			"Biom %d: Kronen bekannt" % biom)
		var anteil := float(kulisse.get("krone_anteil", 0.0))
		_check(anteil > 0.0 and anteil <= 0.5, "Biom %d: nur ein Teil der Wände trägt Kronen (%.2f)" % [biom, anteil])
		var varianten: Dictionary = kulisse.get("deko_varianten", {})
		for art in stil["deco"]:
			var liste: Array = varianten.get(art, [])
			_check(not liste.is_empty() and liste.all(func(v: String) -> bool: return v in BiomKulisse.DEKO),
				"Biom %d: Deko-Art %s hat Biom-Varianten" % [biom, art])
		var saeule := BiomKulisse.saeule(stil)
		var aabb := (saeule.get_child(0) as MeshInstance3D).mesh.get_aabb()
		_check(aabb.end.y > 3.5 and aabb.position.y > -0.05,
			"Biom %d: Hallen-Säule steht und ist hoch (%.1f)" % [biom, aabb.end.y])
		saeule.free()
	var stil := BiomStil.fuer(Enums.Biome.FOREST)
	for art in BiomKulisse.KRONEN:
		var b := BiomKulisse.krone(art, stil)
		var aabb := b.mesh().get_aabb()
		_check(not b.ist_leer() and b.hat_huelle() and b.dreiecke() < 3000,
			"Krone %s gebacken mit Kontur (%d Dreiecke)" % [art, b.dreiecke()])
		_check(aabb.position.x >= -0.62 and aabb.end.x <= 0.62 and aabb.position.z >= -0.62
			and aabb.end.z <= 0.62 and aabb.position.y > -0.05, "Krone %s bleibt auf ihrer Wand" % art)
	for art in BiomKulisse.DEKO:
		var b := BiomKulisse.deko(art, stil)
		var aabb := b.mesh().get_aabb()
		_check(not b.ist_leer() and b.dreiecke() < 3000, "Deko %s gebacken (%d Dreiecke)" % [art, b.dreiecke()])
		_check(aabb.position.x >= -0.5 and aabb.end.x <= 0.5 and aabb.position.z >= -0.5
			and aabb.end.z <= 0.5 and aabb.position.y > -0.05, "Deko %s bleibt im Feld (%s)" % [art, aabb])
		if art in BiomKulisse.FLACH:
			_check(aabb.end.y <= 0.36, "flache Deko %s bleibt niedrig (%.2f)" % [art, aabb.end.y])
	var krypta := BiomStil.fuer(Enums.Biome.CRYPT)
	var schmal_ok := true
	var verschieden := {}
	for i in 60:
		var zelle := Vector2i(i * 3, i * 7)
		var v := BiomKulisse.deko_variante(krypta, "grabstein", zelle, true)
		schmal_ok = schmal_ok and v in BiomKulisse.FLACH
		verschieden[BiomKulisse.deko_variante(krypta, "grabstein", zelle, false)] = true
	_check(schmal_ok, "schmale Gänge bekommen nur flache Deko (Weg bleibt frei)")
	_check(verschieden.size() >= 2, "breite Zellen streuen die Varianten (%d)" % verschieden.size())
	_check(BiomKulisse.deko_variante(krypta, "grabstein", Vector2i(4, 4), false)
		== BiomKulisse.deko_variante(krypta, "grabstein", Vector2i(4, 4), false), "Variante deterministisch je Zelle")
	_check(BiomKulisse.deko_variante(krypta, "unbekannt", Vector2i.ZERO, false) == "",
		"unbekannte Art » Einzelstück (FigurenBau.deko)")


func _test_kronen_wahl() -> void:
	print("Kronen-Auswahl:")
	var mit := 0
	var varianten_ok := true
	for y in 50:
		for x in 50:
			if WeltBau.hat_krone(Vector2i(x, y), 0.3):
				mit += 1
			var v := WeltBau.kronen_variante(Vector2i(x, y), 4)
			varianten_ok = varianten_ok and v >= 0 and v < 4
	var anteil := float(mit) / 2500.0
	_check(absf(anteil - 0.3) < 0.05, "Anteil der Kronen folgt dem Biom-Wert (%.2f)" % anteil)
	_check(varianten_ok, "Varianten-Index im Bereich")
	_check(WeltBau.hat_krone(Vector2i(9, 2), 0.3) == WeltBau.hat_krone(Vector2i(9, 2), 0.3), "deterministisch")


## Boss-Ebene wie der Generator sie baut: Gang (3 breit) mündet mittig in
## einen 9×9-Raum — hier von Hand nachgebaut (ohne Generator/Autoloads).
func _test_boss_raum() -> void:
	print("Boss-Arena:")
	var map := DungeonMap.new()
	map.width = 42
	map.height = 13
	map.cells.resize(map.width * map.height)
	for x in range(3, 31):
		for y in range(5, 8):
			map.set_floor(Vector2i(x, y))
	for x in range(31, 40):
		for y in range(2, 11):
			map.set_floor(Vector2i(x, y))
	map.has_boss = true
	map.boss_cell = Vector2i(37, 6)
	var raum := WeltBau.boss_raum(map)
	_check(raum == Rect2i(31, 2, 9, 9), "Raum aus dem Grundriss gelesen (%s)" % raum)
	var schalen := WeltBau.boss_schalen(map, raum)
	_check(schalen.size() == 6 and Vector2i(31, 2) in schalen and Vector2i(39, 10) in schalen
		and Vector2i(31, 4) in schalen and Vector2i(31, 8) in schalen, "vier Ecken + Eingang flankiert (%s)" % [schalen])
	_check(not map.boss_cell in schalen and not Vector2i(31, 6) in schalen, "nie auf Boss oder in der Mündung")
	_check(WeltBau.boss_eingang(map, raum) == Vector2i(30, 6), "Eingang = Gangzelle vor der Mündung")
	var ohne := DungeonMap.new()
	_check(WeltBau.boss_raum(ohne).size == Vector2i.ZERO, "ohne Boss keine Arena")


func _test_ziel_modelle() -> void:
	print("Ziel-Modelle (gebacken):")
	var modelle := {"Truhe": FigurenBau.truhe(Color.RED), "Tresor": FigurenBau.tresor(),
		"Risikotruhe": FigurenBau.risikotruhe(), "Schrein": FigurenBau.schrein(Color.GREEN),
		"Altar": FigurenBau.altar(), "Feuerschale": FigurenBau.feuerschale(), "Banner": FigurenBau.banner()}
	for name in modelle:
		var n: Node3D = modelle[name]
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() <= 4, "%s: höchstens 4 Zeichenaufrufe (%d)" % [name, meshes.size()])
		n.free()
	var schrein := FigurenBau.schrein(Color.BLUE)
	_check(schrein.has_meta("kristall"), "Schrein trägt einen schwebenden Kristall")
	schrein.free()
	_check("INSTANCE_CUSTOM.a" in WeltMaterial.kulisse_code(true) and "discard" in WeltMaterial.kulisse_code(true),
		"Kronen dithern mit ihrer Wand (Instanz-Deckkraft)")
	_check(not "INSTANCE_CUSTOM" in WeltMaterial.kulisse_code(false), "Einzelobjekte ohne Instanzdaten")
	_check("blend_add" in WeltMaterial.SAEULE_CODE and "rausch" in WeltMaterial.SAEULE_CODE,
		"Lichtsäule additiv mit Dither gegen Banding")


func _test_kampfhalle() -> void:
	print("Kampfhalle:")
	var saeulen := KampfHalle.saeulen_stellen()
	_check(saeulen.size() == KampfHalle.SAEULEN_WINKEL.size(), "eine Stelle je Säulenwinkel")
	_check(saeulen.all(func(p: Vector3) -> bool: return p.z < -4.0),
		"Säulen nur auf dem hinteren Bogen (z < -4, nie hinter dem Befehlsmenü)")
	_check(saeulen.all(func(p: Vector3) -> bool:
		return is_equal_approx(p.distance_to(KampfHalle.MITTE), KampfHalle.SAEULEN_RADIUS)),
		"Säulen stehen auf dem Kreisbogen um die Mitte")
	_check(KampfHalle.FACKEL_SAEULEN.all(func(i: int) -> bool: return i >= 0 and i < saeulen.size()),
		"Fackeln hängen an vorhandenen Säulen")
	_check(KampfHalle.LICHT_BUDGET["fackeln"] == KampfHalle.FACKEL_SAEULEN.size()
		and KampfHalle.LICHT_BUDGET["effekte"] >= 1,
		"Licht-Budget passt zu Fackeln und Effekt-Pool")
	_check(KampfHalle.licht_summe() <= KampfHalle.MAX_LICHTER,
		"höchstens 8 Punkt-/Spotlichter je Objekt (%d)" % KampfHalle.licht_summe())
	# Wendet sich ein Teil zur Mitte, zeigt seine +z-Achse dorthin.
	var stelle := saeulen[1]
	var vorn := Basis(Vector3.UP, KampfHalle.zur_mitte(stelle)) * Vector3.BACK
	_check(vorn.dot((KampfHalle.MITTE - stelle).normalized()) > 0.99, "zur_mitte dreht +z zur Hallenmitte")
	var kulisse := KampfHalle.kulisse_stellen()
	_check(kulisse.size() == KampfHalle.KULISSE_ANZAHL, "Kulissen-Ring vollständig")
	_check(kulisse.all(func(k: Dictionary) -> bool:
		return (k["pos"] as Vector3).distance_to(KampfHalle.MITTE) > KampfHalle.SAEULEN_RADIUS + 1.5),
		"Kulisse steht hinter den Säulen")
	_check(str(kulisse) == str(KampfHalle.kulisse_stellen()), "Kulissen-Stellen sind deterministisch")
	for biom in Enums.Biome.values():
		var stil := BiomStil.fuer(biom)
		var normal := KampfHalle.stimmung(stil, 0)
		var boss := KampfHalle.stimmung(stil, 1)
		var phase3 := KampfHalle.stimmung(stil, 3)
		_check(float(normal["boss_spot"]) == 0.0 and float(boss["boss_spot"]) > 0.0,
			"Biom %d: roter Boss-Spot nur im Bosskampf" % biom)
		_check(float(boss["sonne_energie"]) < float(normal["sonne_energie"])
			and float(boss["spot_energie"]) < float(normal["spot_energie"])
			and float(boss["fackeln"]) < float(normal["fackeln"]), "Biom %d: Boss-Halle dunkelt ab" % biom)
		_check([normal, boss, phase3].all(func(w: Dictionary) -> bool:
			return float(w["ambient_energie"]) >= KampfHalle.MIN_UMGEBUNG),
			"Biom %d: Umgebung bleibt hell genug (nichts versinkt im Dunkeln)" % biom)
		# Roter Spot tönt den Boss, färbt ihn nicht um; das Siegel unter den
		# Gegnerwerten bleibt gedämpft (Review Paket 3: Golem wurde rosa).
		_check(float(phase3["boss_spot"]) <= 3.0 and float(phase3["siegel_staerke"]) <= 0.6,
			"Biom %d: Boss-Spot und Siegel bleiben dezent" % biom)
		var rot := func(c: Color) -> float: return c.r - (c.g + c.b) * 0.5
		_check(rot.call(phase3["ambient"]) > rot.call(boss["ambient"]) and rot.call(boss["ambient"])
			> rot.call(normal["ambient"]), "Biom %d: jede Boss-Stufe färbt die Halle röter" % biom)
		var halle := BiomKulisse.hallen_kulisse(stil, kulisse)
		_check(not halle.ist_leer() and halle.hat_huelle(), "Biom %d: Kulissen-Ring gebacken mit Kontur" % biom)
		# Felsen dürfen leicht einsinken, nichts hängt tief unter dem Boden.
		_check(halle.mesh().get_aabb().position.y > -0.2, "Biom %d: Kulisse steht auf dem Boden" % biom)
		var saeule := BiomKulisse.saeule_bausatz(stil, KampfHalle.SAEULEN_HOEHE)
		_check(saeule.hat_huelle() and BiomKulisse.SAEULE_RADIUS.has(stil["kulisse"]["saeule"]),
			"Biom %d: Hallen-Säule mit Kontur und Fackel-Abstand" % biom)
	_check("ATTENUATION" in WeltMaterial.ARENA_CODE and "mitte" in WeltMaterial.ARENA_CODE,
		"Arena-Boden mit Toon-Licht und Lichtinsel zur Mitte")


func _test_schweif() -> void:
	print("Projektil-Schweif:")
	var punkte := PackedVector3Array([Vector3(0, 1, 0), Vector3(-0.2, 1, 0.1), Vector3(-0.4, 1, 0.2),
		Vector3(-0.6, 1, 0.3)])
	var auge := Vector3(0, 6, 8.5)
	var ecken := Schweif.band(punkte, auge, 0.3)
	_check(ecken.size() == punkte.size() * 2, "zwei Ecken je Stützpunkt")
	_check(is_equal_approx(ecken[0].distance_to(ecken[1]), 0.3), "Kopf in voller Breite")
	_check(ecken[6].distance_to(ecken[7]) < 0.001, "Ende läuft spitz aus")
	var quer := (ecken[0] - ecken[1]).normalized()
	_check(absf(quer.dot((punkte[0] - punkte[1]).normalized())) < 0.01, "Band liegt quer zur Flugrichtung")
	_check(Schweif.band(PackedVector3Array([Vector3.ZERO]), auge, 0.3).is_empty(), "ein Punkt » kein Band")
	_check("blend_mix" in Schweif.SHADER_CODE and not "blend_add" in Schweif.SHADER_CODE,
		"Schweif gemischt (additiv würde auf hellem Boden weiß)")


func _test_gold() -> void:
	print("Güldene (echtes Gold):")
	var toon := Stil3D.material(Stil3D.farbe("fell"), 0)
	var gold := Stil3D.gold(toon)
	_check(gold == Stil3D.gold(toon), "Gold-Material je Ausgangsmaterial gecacht")
	_check(gold.next_pass == toon.next_pass and Stil3D.ist_kontur(gold.next_pass), "Kontur bleibt erhalten")
	_check(gold.get_shader_parameter("farbe") == toon.get_shader_parameter("farbe"), "Grundfarbe übernommen")
	_check("SPECULAR_LIGHT" in Stil3D.GOLD_CODE and "mix(grund, g" in Stil3D.GOLD_CODE
		and not "blend_add" in Stil3D.GOLD_CODE, "Albedo-Lerp zu Gold + Glanzstufe, kein Additiv-Overlay")
	var figur := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"wolf"), "", true)
	var gold_teile := 0
	var overlays := 0
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override is ShaderMaterial and (m.material_override as ShaderMaterial).shader == gold.shader:
			gold_teile += 1
		if m.material_overlay != null:
			overlays += 1
		_check(not Stil3D.ist_toon(m.material_override), "kein Teil bleibt im normalen Toon")
	_check(gold_teile > 3 and overlays == 0, "Güldener Wolf aus Gold-Material, ohne Overlay (%d Teile)" % gold_teile)
	figur.free()


## Unterhalb der Wurzel keine Node-Skalierung (Kontur bliebe sonst ungleich).
func _ohne_skalierung(figur: Node3D) -> bool:
	for kind in figur.find_children("*", "Node3D", true, false):
		if not (kind is CPUParticles3D) and not (kind as Node3D).scale.is_equal_approx(Vector3.ONE):
			return false
	return figur.scale.is_equal_approx(Vector3.ONE)


func _test_gliederpuppe() -> void:
	print("Gliederpuppe (Figuren 2.0, Beispiel Troll):")
	var troll := FigurenBau.fuer_archetyp(&"troll")
	var glieder: Dictionary = troll.get_meta("glieder", {})
	_check(glieder.has("arm_r") and glieder.has("arm_l") and glieder.size() <= Gliederpuppe.MAX_GLIEDER,
		"benannte Pivots arm_r/arm_l, höchstens %d (%d)" % [Gliederpuppe.MAX_GLIEDER, glieder.size()])
	var teile := troll.find_children("*", "MeshInstance3D", true, false)
	_check(teile.size() <= 2 * (1 + glieder.size()),
		"je Teil Körper + Hülle: %d MeshInstances bei %d Pivots" % [teile.size(), glieder.size()])
	_check(_ohne_skalierung(troll), "keine Node-Skalierung (Größe 1.4 steckt im Mesh)")
	var daten := Gliederpuppe.cache_daten("troll|1.400|false|-")
	_check(not daten.is_empty() and int(daten["dreiecke"]) <= 6000,
		"Dreiecks-Budget Gegner höchstens 6000 (%d)" % int(daten.get("dreiecke", -1)))
	var zweiter := FigurenBau.fuer_archetyp(&"troll")
	_check((zweiter.get_child(0) as MeshInstance3D).mesh == (troll.get_child(0) as MeshInstance3D).mesh,
		"Mesh-Cache: gleiche Gegner teilen dieselben Meshes")
	var arm: Node3D = glieder["arm_r"]
	_check(arm.position.y > 0.8 and arm.position.y < 1.0, "Schultergelenk auf Figurhöhe x 1.4")
	# Animation: Angriff weicht ab, am Ende exakt Ruhe; Wurzel-Versatz zurück auf 0.
	var mitte := Gliederpuppe.beleben(troll, -1.0, 0.3)
	var aus_ruhe := not arm.rotation.is_equal_approx(arm.get_meta("ruhe"))
	_check(aus_ruhe and not mitte.is_zero_approx(), "Angriff hebt die Keule und neigt die Wurzel")
	var ende := Gliederpuppe.beleben(troll, -1.0, Gliederpuppe.dauer("troll"),
		Gliederpuppe.dauer("troll", "treffer"), false, Gliederpuppe.dauer("troll", "phase"))
	var alle_ruhe := ende.is_zero_approx()
	for glied_name in glieder:
		var g: Node3D = glieder[glied_name]
		alle_ruhe = alle_ruhe and g.rotation.is_equal_approx(g.get_meta("ruhe"))
	_check(alle_ruhe, "nach Angriff/Treffer/Phase exakt Ruhepose")
	_check(Gliederpuppe.dauer("troll") > 0.4 and Gliederpuppe.dauer("troll", "phase") > 1.0,
		"Animationstabelle: Angriff und Phasen-Pose je Profil")
	Gliederpuppe.beleben(troll, 1.3, -1.0, -1.0, true)
	_check(not arm.rotation.is_equal_approx(arm.get_meta("ruhe")), "Gehen schwingt die Arme")
	Gliederpuppe.ruhe(troll)
	_check(arm.rotation.is_equal_approx(arm.get_meta("ruhe")), "ruhe() setzt die Ruhepose")
	# Kampfbühne: Angriff startet an der steigenden Puls-Flanke.
	var e := {"puls_alt": 1.0, "aktion": -1.0, "treffer_t": -1.0, "phase_t": -1.0}
	Gliederpuppe.kampf_takt(e, troll, 0.0, 1.0, 0.016)
	_check(float(e["aktion"]) < 0.0, "Kampfbühne: ohne Puls kein Angriff")
	for i in 16:
		Gliederpuppe.kampf_takt(e, troll, 0.0, 1.05, 0.016)
	_check(float(e["aktion"]) > 0.2 and not arm.rotation.is_equal_approx(arm.get_meta("ruhe")),
		"Kampfbühne: Puls-Flanke startet die Angriffs-Pose")
	# Gesichts-Bausteine: Auge mit Pupille und Glanz (leuchtend), ohne Hülle.
	var b := Bausatz.new()
	Gliederpuppe.auge(b, Vector3(0, 1, 0.2), 0.05, {"iris": Stil3D.farbe("glut"), "iris_leuchten": 0.8})
	Gliederpuppe.braue(b, Vector3(0, 1.07, 0.2), 0.07, 1.0)
	Gliederpuppe.mund(b, Vector3(0, 0.9, 0.2), 0.08, "fies")
	var farben: PackedColorArray = b.mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var leuchtet := false
	for f in farben:
		leuchtet = leuchtet or f.a < 0.6
	_check(b.huelle() == null and leuchtet, "Gesicht ohne Hülle, Iris/Glanz leuchten über Vertex-Alpha")
	# Gold: alle Körperteile echtes Gold, Hüllen bleiben Kontur.
	var gold := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll"), "", true)
	var gold_ok := true
	var huellen := 0
	for mi in gold.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override
		if Stil3D.ist_kontur(mat):
			huellen += 1
		else:
			gold_ok = gold_ok and mat is ShaderMaterial and (mat as ShaderMaterial).shader.code == Stil3D.GOLD_CODE
	_check(gold_ok and huellen >= 3, "Güldener Troll: Körper aus Gold, %d Hüllen unverändert" % huellen)
	for f in [troll, zweiter, gold]:
		f.free()


func _test_massstab() -> void:
	print("Maßstab im Mesh (Kontur gleich dick):")
	var b := Bausatz.new()
	b.massstab = 2.0
	b.teil(Stil3D.box(0.2, 0.2, 0.2), Color.WHITE, Vector3(0.5, 0, 0))
	var koerper := b.mesh().get_aabb()
	var huelle := b.huelle().get_aabb()
	_check(is_equal_approx(koerper.size.x, 0.4) and is_equal_approx(koerper.get_center().x, 1.0),
		"Bausatz.massstab skaliert Maße und Lage")
	_check(is_equal_approx(huelle.size.x - koerper.size.x, 2.0 * Stil3D.KONTUR_DICKE),
		"Hülle nach dem Skalieren aufgebläht: Kontur bleibt %.3f" % Stil3D.KONTUR_DICKE)
	var klein := FigurenBau.fuer_archetyp(&"wolf")
	var gross := FigurenBau.fuer_archetyp(&"wolf", {"massstab": 1.5})
	var h_klein := FigurenBau.umriss_lokal(klein).size.y
	var h_gross := FigurenBau.umriss_lokal(gross).size.y
	_check(absf(h_gross / h_klein - 1.5) < 0.03 and _ohne_skalierung(gross),
		"Grundkörper-Figur x1.5 ohne Node-Skalierung (%.2f > %.2f)" % [h_klein, h_gross])
	_check(is_equal_approx(float(gross.get_meta("groesse")), 1.5), "Meta groesse merkt den Faktor")
	var troll := FigurenBau.fuer_archetyp(&"troll")
	var boss := FigurenBau.fuer_archetyp(&"troll", {"boss": true, "massstab": 1.5})
	var r := FigurenBau.umriss_lokal(boss).size.y / FigurenBau.umriss_lokal(troll).size.y
	_check(r > 1.4 and _ohne_skalierung(boss), "Boss-Troll x1.5 im Mesh (Faktor %.2f)" % r)
	var daten := Gliederpuppe.cache_daten("troll|2.100|true|-")
	_check(not daten.is_empty() and int(daten["dreiecke"]) <= 12000,
		"Boss-Budget höchstens 12000 Dreiecke (%d)" % int(daten.get("dreiecke", -1)))
	for f in [klein, gross, troll, boss]:
		f.free()


func _test_schmuck() -> void:
	print("Rang- und Boss-Schmuck:")
	var elite := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"fledermaus"), "elite", false)
	var boden: Array = elite.get_meta("boden_teile", [])
	_check(boden.size() == 1, "Elite: ein gebackener Leuchtring am Boden")
	FigurenBau.boden_halten(elite, 0.2)
	_check(not boden.is_empty() and is_equal_approx((boden[0] as Node3D).position.y, 0.015 - 0.2),
		"Ring bleibt am Boden, auch wenn die Figur schwebt")
	var ring_mi := (boden[0] as Node3D).get_child(0) as MeshInstance3D
	_check(ring_mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and ring_mi.get_aabb().size.y < 0.3, "Ring flach (keine Pfütze) und ohne Schattenwurf")
	var strahl := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"wolf"), "", false, "strahlend")
	var kontur_overlay := false
	var koerper_overlay := false
	for mi in strahl.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if Stil3D.ist_kontur(m.material_override):
			kontur_overlay = kontur_overlay or m.material_overlay != null
		else:
			koerper_overlay = koerper_overlay or m.material_overlay != null
	_check(koerper_overlay and not kontur_overlay, "Strahlend: Glanz nur auf Körpern, nie auf Konturen")
	var karte := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"golem"), "", false, "karte")
	var rolle_hoch := false
	for teil in karte.get_meta("schmuck", []):
		if String((teil as Node).name).contains("karte_rolle"):
			rolle_hoch = (teil as Node3D).position.y > 1.1
	_check(not rolle_hoch, "Kartenhüter: Rolle auf dem Rücken, nicht über dem Kopf")
	var boss_wolf := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"wolf", {"boss": true, "massstab": 1.1}),
		"", false, "", true)
	_check(boss_wolf.has_meta("boss_krone") and boss_wolf.find_child("Schmuck_boss_siegel", true, false) != null,
		"Boss: Krone und Bodensiegel")
	var koenig := FigurenBau.fuer_archetyp(&"koenigschleim", {"boss": true})
	_check(koenig.find_child("Krone", true, false) == null
		and String((koenig.get_meta("boss_krone") as Node).name).contains("grosskrone"),
		"vorhandene Krone wird zur Großkrone")
	var troll_boss := FigurenBau.fuer_archetyp(&"troll", {"boss": true, "massstab": 1.1})
	var krone: Node3D = troll_boss.get_meta("boss_krone")
	_check(krone != null and krone.is_inside_tree() == false and krone.get_parent() != null,
		"Gliederpuppe trägt die Boss-Krone am Kopf-Anker")
	var champ := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll"), "champion", false)
	_check(champ.find_child("Schmuck_champion_hoerner", true, false) != null,
		"Champion: Hörnerstummel aus Segmentketten")
	for f in [elite, strahl, karte, boss_wolf, koenig, troll_boss, champ]:
		f.free()


## Gliederpuppe gültig: höchstens 5 Glieder, je Teil Körper + Hülle, keine
## Node-Skalierung, nach Angriff/Treffer/Phase exakt Ruhepose.
func _puppe_ok(f: Node3D) -> bool:
	var glieder: Dictionary = f.get_meta("glieder", {})
	if glieder.is_empty() or glieder.size() > Gliederpuppe.MAX_GLIEDER:
		return false
	var teile := 0
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		if not String((mi as Node).get_parent().name).begins_with("Schmuck"):
			teile += 1
	if teile > 2 * (1 + glieder.size()) or not _ohne_skalierung(f):
		return false
	var anim := String(f.get_meta("anim", ""))
	if not Gliederpuppe.PROFILE.has(anim):
		return false
	Gliederpuppe.beleben(f, 1.7, 0.2, 0.1, true, 0.4)
	var ende := Gliederpuppe.beleben(f, -1.0, Gliederpuppe.dauer(anim), Gliederpuppe.dauer(anim, "treffer"),
		false, Gliederpuppe.dauer(anim, "phase"))
	var ruhe := ende.is_zero_approx()
	for glied_name in glieder:
		var g: Node3D = glieder[glied_name]
		ruhe = ruhe and g.rotation.is_equal_approx(g.get_meta("ruhe"))
	return ruhe


func _test_zweibeiner() -> void:
	print("Zweibeiner 2.0 (Gliederpuppen, ZweibeinerBau):")
	var fehler: Array[String] = []
	var budget_fehler: Array[String] = []
	var dreh_fehler: Array[String] = []
	for id in ZweibeinerBau.ARTEN:
		var f := FigurenBau.fuer_archetyp(id)
		if not _puppe_ok(f):
			fehler.append(String(id))
		if not is_equal_approx(float(f.get_meta("drehung", 0.0)), 12.0):
			dreh_fehler.append(String(id))
		var key := "zb|%s|%.3f|false|-" % [id, float(ZweibeinerBau.GROESSE.get(id, 1.0))]
		var grenze := 12000 if id in [&"todesmeister", &"demonenkonig"] else 6000
		var dreiecke := int(Gliederpuppe.cache_daten(key).get("dreiecke", 99999))
		if dreiecke > grenze:
			budget_fehler.append("%s %d" % [id, dreiecke])
		f.free()
	_check(fehler.is_empty(), "alle %d Zweibeiner: Glieder, Hüllen, keine Skalierung, Ruhepose %s"
		% [ZweibeinerBau.ARTEN.size(), fehler])
	_check(budget_fehler.is_empty(), "Dreiecks-Budget Gegner 6000 / Boss 12000 %s" % [budget_fehler])
	_check(dreh_fehler.is_empty(), "Zweibeiner stehen im Kampf in 3/4-Ansicht (drehung 12) %s" % [dreh_fehler])
	# Mesh-Cache, Boss-Varianten, Anker am Kopf-Glied
	var a := FigurenBau.fuer_archetyp(&"skelett")
	var b := FigurenBau.fuer_archetyp(&"skelett")
	_check((a.get_child(0) as MeshInstance3D).mesh == (b.get_child(0) as MeshInstance3D).mesh,
		"Mesh-Cache: zwei Skelette teilen dieselben Meshes")
	_check((a.get_meta("glieder") as Dictionary).has("kiefer"), "Skelett hat einen beweglichen Kiefer")
	var tod := FigurenBau.fuer_archetyp(&"todesmeister", {"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB})
	var tg: Dictionary = tod.get_meta("glieder")
	_check(tg.has("orbit") and tg.has("kopf") and tod.get_meta("hat_krone", false) and not tod.has_meta("boss_krone"),
		"Todesmeister: Orbit, Kopf-Glied, eigene Großkrone statt Zusatzkrone")
	var orbit: Node3D = tg["orbit"]
	Gliederpuppe.beleben(tod, 1.0)
	var w1 := orbit.rotation.y
	Gliederpuppe.beleben(tod, 2.0)
	_check(not is_equal_approx(w1, orbit.rotation.y), "Orbit dreht sich dauerhaft (Form 2)")
	var bandit := FigurenBau.fuer_archetyp(&"bandit", {"boss": true, "massstab": 1.5})
	_check(bandit.has_meta("boss_krone") and _ohne_skalierung(bandit), "Boss-Bandit: Boss-Krone, Größe im Mesh")
	var diener := FigurenBau.fuer_archetyp(&"toddiener", {"boss": true})
	var krone: Node3D = diener.get_meta("boss_krone")
	_check(krone.get_parent() == (diener.get_meta("glieder") as Dictionary)["kopf"],
		"Boss-Krone hängt am Kopf-Glied (nickt mit)")
	var hexe := FigurenBau.fuer_archetyp(&"hexenmeisterin")
	var kristall: Node3D = (hexe.get_meta("glieder") as Dictionary)["kristall"]
	_check(kristall.get_parent().name == "arm_r", "Hexen-Kristall ist Kind des Stab-Arms (folgt dem Angriff)")
	var gold := FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"nekromant"), "", true)
	var gold_ok := true
	var huellen := 0
	for mi in gold.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override
		if Stil3D.ist_kontur(mat):
			huellen += 1
		else:
			gold_ok = gold_ok and (mat as ShaderMaterial).shader.code == Stil3D.GOLD_CODE
	_check(gold_ok and huellen >= 3, "Güldener Nekromant: alle Körper Gold, Hüllen unverändert")
	var elite := FigurenBau.fuer_archetyp(&"kultist", {"akzent": Stil3D.farbe("lila")})
	_check(Gliederpuppe.cache_daten("zb|kultist|1.000|false|%s" % Stil3D.farbe("lila").to_html(false)).size() > 0,
		"Elite-Akzent: eigener Cache-Eintrag (lila Augen)")
	for f in [a, b, tod, bandit, diener, hexe, gold, elite]:
		f.free()


func _test_helden() -> void:
	print("Helden 2.0 (Rollen nach Ausrüstung, Farbwahl, Sonderfarben):")
	# Rollen-Zuordnung
	var rollen := {
		"tank": {},
		"krieger": {"bekannt": true, "waffe": "axt", "ruestung": Enums.ArmorClass.CHAIN},
		"schurke": {"bekannt": true, "waffe": "dolch", "neben": "dolch", "ruestung": Enums.ArmorClass.LEATHER},
		"magier": {"bekannt": true, "waffe": "offensivstab", "neben": "relikt"},
		"heiler": {"bekannt": true, "waffe": "heiligstab", "neben": "heiligkreuz"},
		"abenteurer": {"bekannt": true, "waffe": "schwert"},
	}
	var falsch: Array[String] = []
	for rolle in rollen:
		var f := FigurenBau.held_mit(Stil3D.farbe("ruestung"), rollen[rolle])
		if String(f.get_meta("rolle", "")) != rolle:
			falsch.append("%s>%s" % [rolle, f.get_meta("rolle", "")])
		f.free()
	_check(falsch.is_empty(), "Rolle folgt Rüstung und Waffe %s" % [falsch])
	# Alle Starter-Loadouts x Rüstungsklassen x Farben (inkl. Sonderfarben)
	var alle_sonder: Array = []
	for eintrag in FigurenBau.SONDER_FARBEN:
		alle_sonder.append(eintrag[0])
	var farben: Array[Color] = []
	for tile in FigurenBau.farb_tiles(alle_sonder):
		farben.append(FigurenBau.held_farbe_aus(tile, ""))
	var kaputt: Array[String] = []
	var max_dreiecke := 0
	var anzahl := 0
	for loadout in HeroLibrary.STARTER_LOADOUTS:
		var kit: Dictionary = HeroLibrary.STARTER_LOADOUTS[loadout]
		for klasse in [Enums.ArmorClass.NONE, Enums.ArmorClass.LEATHER, Enums.ArmorClass.CHAIN, Enums.ArmorClass.PLATE]:
			for farbe in farben:
				var aus := {"bekannt": true, "waffe": String(kit["weapon"]), "neben": String(kit["offhand"]),
					"ruestung": klasse, "haar": anzahl % 15}
				var f := FigurenBau.held_mit(farbe, aus)
				anzahl += 1
				if not _puppe_ok(f):
					kaputt.append("%s/%d" % [loadout, klasse])
				var d := Gliederpuppe.cache_daten("held:%s|%s" % [farbe.to_html(false), str(aus)])
				max_dreiecke = maxi(max_dreiecke, int(d.get("dreiecke", 99999)))
				f.free()
	_check(kaputt.is_empty(), "%d Helden (Loadouts x Rüstung x %d Farben) gültig %s" % [anzahl, farben.size(), kaputt])
	_check(max_dreiecke <= 8000, "Dreiecks-Budget Helden höchstens 8000 (max %d)" % max_dreiecke)
	# Farbwahl-Symbol = Tank; dunkle Sonderfarben mit aufgehellter Sekundärfarbe
	var tank := FigurenBau.held_mit(Stil3D.farbe("obsidian"))
	_check(String(tank.get_meta("rolle")) == "tank", "Farbwahl zeigt den Tank")
	_check(ZweibeinerBau.sekundaer(Stil3D.farbe("obsidian")).get_luminance() > Stil3D.farbe("obsidian").get_luminance()
		and ZweibeinerBau.sekundaer(Stil3D.farbe("gold")).get_luminance() < Stil3D.farbe("gold").get_luminance(),
		"Sekundärfarbe: dunkle Farben aufgehellt, helle abgedunkelt")
	var silber := FigurenBau.held_mit(Stil3D.farbe("silber"))
	_check((silber.get_child(0) as MeshInstance3D).mesh != (tank.get_child(0) as MeshInstance3D).mesh,
		"Sonderfarben haben eigene Meshes (Kamm, Nieten, Umhang)")
	for f in [tank, silber]:
		f.free()
	# Starter mit Feuerstab: Kristall flammt (Element aus dem Loadout)
	var feuer := FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[3], &"feuerstab")
	_check(String(feuer.get_meta("rolle")) == "magier" and String(feuer.get_meta("anim")) == "held_stab",
		"Starter Feuerstab: Magier mit Stab-Animation")
	feuer.free()
