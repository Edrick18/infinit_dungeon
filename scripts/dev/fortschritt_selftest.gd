extends SceneTree
## Headless-Selbsttest für Lauf-Bilanz, Chronik, Bestiarium-Stufen,
## Rüstungsfarben und die Zahl abholbarer Belohnungen (Stadt-Knopf):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/fortschritt_selftest.gd
## Schreibt nichts auf die Platte (nur to_save_dict/apply_save_dict).

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_bilanz()
	_test_bilanz_alter_stand()
	_test_chronik()
	_test_chronik_alter_stand()
	_test_bestiarium_stufen()
	_test_farben()
	_test_abholbar()
	_test_speicher_rundweg()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Fortschritts-Tests bestanden")
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


func _state() -> Node:
	return load("res://autoload/game_state.gd").new()


func _test_bilanz() -> void:
	print("Lauf-Bilanz:")
	var state := _state()
	state.bilanz_add("gold", 50)
	_check(not state.current_run.has("bilanz") and state.chronik_wert("gold") == 50,
		"ohne Lauf: keine Bilanz, verdientes Gold zählt nur in der Chronik")
	state.spielzeit_s = 600.0
	state.start_run(CardFactory.make_starter_card())
	var bilanz: Dictionary = state.current_run["bilanz"]
	_check(not bilanz["teilweise"] and is_equal_approx(float(bilanz["start_s"]), 600.0),
		"start_run legt eine volle Bilanz an (Startzeit 600 s)")
	state.bilanz_add("gold", 120)
	state.bilanz_add("gold", 30)
	state.bilanz_add("xp", 400)
	state.bilanz_add("kaempfe")
	state.bilanz_add("kaempfe")
	state.bilanz_add("level_auf", 0)
	state.bilanz_add("level_auf", 2)
	state.bilanz_add("materialien", 3)
	state.bilanz_item(Enums.Rarity.EPIC)
	state.bilanz_item(Enums.Rarity.RARE)
	state.bilanz_item(Enums.Rarity.RARE)
	state.medaille(2)
	_check(int(bilanz["gold"]) == 150 and int(bilanz["xp"]) == 400 and int(bilanz["kaempfe"]) == 2
		and int(bilanz["level_auf"]) == 2 and int(bilanz["materialien"]) == 3 and int(bilanz["medaillen"]) == 2,
		"Gold, XP, Kämpfe, Level-Aufstiege, Materialien und Medaillen werden summiert")
	_check(int(bilanz["items"][Enums.Rarity.RARE]) == 2 and int(bilanz["items"][Enums.Rarity.EPIC]) == 1,
		"Items nach Seltenheit gezählt")
	_check(state.chronik_wert("gold") == 200, "Chronik: Gold über alle Läufe (200)")
	Loc.set_language("de")
	var zeilen: Array[String] = state.bilanz_zeilen(bilanz, 600.0 + 23 * 60.0)
	var text := "\n".join(zeilen)
	_check(text.contains("Kämpfe 2") and text.contains("+400 XP") and text.contains("+150 Gold"),
		"Zeile 1: Kämpfe, XP, Gold (%s)" % zeilen[0])
	_check(text.contains("1 Episch") and text.contains("2 Selten") and text.find("Episch") < text.find("Selten"),
		"Zeile 2: Items, die seltensten zuerst (%s)" % zeilen[1])
	_check(text.contains("+2 Mini-Medaillen") and text.contains("2 Level-Aufstiege") and text.contains("23 Min."),
		"Zeile 3: Medaillen, Aufstiege, Dauer (%s)" % zeilen[2])
	Loc.set_language("en")
	_check("\n".join(state.bilanz_zeilen(bilanz, 600.0)).contains("Battles 2"), "auch auf Englisch")
	Loc.set_language("de")
	_check(state.bilanz_zeilen({}, 0.0).is_empty(), "leere Bilanz: keine Zeilen")
	state.clear_run()
	state.bilanz_item(Enums.Rarity.EPIC)  # ohne Lauf: kein Absturz
	state.free()


func _test_bilanz_alter_stand() -> void:
	print("Bilanz und alte Spielstände:")
	var state := _state()
	state.start_run(CardFactory.make_starter_card())
	var daten: Dictionary = state.to_save_dict()
	(daten["current_run"] as Dictionary).erase("bilanz")
	var alt := _state()
	alt.spielzeit_s = 100.0
	alt.apply_save_dict(daten)
	var bilanz: Dictionary = alt.current_run.get("bilanz", {})
	_check(not bilanz.is_empty() and bilanz["teilweise"] == true and int(bilanz["gold"]) == 0,
		"laufender Lauf ohne Bilanz-Daten: Teil-Bilanz ab jetzt, kein Absturz")
	_check("\n".join(alt.bilanz_zeilen(bilanz, alt.spielzeit_s)).contains("unvollständig"),
		"Teil-Bilanz wird als unvollständig ausgewiesen")
	# Ganz ohne Bilanz-Schlüssel im Lauf (z. B. Co-op-Lauf von außen): legt sie bei Bedarf an.
	alt.current_run.erase("bilanz")
	alt.bilanz_add("gold", 5)
	_check(int(alt.current_run["bilanz"]["gold"]) == 5, "fehlende Bilanz wird beim ersten Zählen angelegt")
	state.free()
	alt.free()


func _test_chronik() -> void:
	print("Chronik-Zähler:")
	var state := _state()
	var karte := CardFactory.make_starter_card()
	karte.tier = 7
	state.chronik_dungeon(karte)
	karte.tier = 4
	state.chronik_dungeon(karte)
	state.chronik_add("kaempfe", 3)
	state.chronik_add("helden_gefallen")
	state.chronik_add("wiedergeburten")
	_check(state.chronik_wert("dungeons") == 2 and state.chronik_wert("bosse") == 2,
		"Dungeons und Bosse zählen je Abschluss")
	_check(state.chronik_wert("hoechste_stufe") == 7, "höchste Kartenstufe bleibt das Maximum (7)")
	_check(state.chronik_wert("kaempfe") == 3 and state.chronik_wert("helden_gefallen") == 1
		and state.chronik_wert("wiedergeburten") == 1 and state.chronik_wert("unbekannt") == 0,
		"Kämpfe, gefallene Helden, Wiedergeburten; Unbekanntes = 0")
	var eintraege := LexiconLibrary.chronik_entries(state)
	var alles := ""
	for eintrag in eintraege:
		alles += String(eintrag["title"]) + "\n" + String(eintrag["body"]) + "\n"
	_check(alles.contains("Abgeschlossene Dungeons:[/b] 2") and alles.contains("Kartenstufe:[/b] 7")
		and alles.contains("Gefallene Helden:[/b] 1"), "Lexikon-Kategorie Chronik zeigt die Zahlen")
	_check(LexiconLibrary.chronik_entries(null).size() == eintraege.size(), "ohne Spielstand: alles 0, kein Absturz")
	var gefunden := false
	for kategorie in LexiconLibrary.categories():
		gefunden = gefunden or kategorie["id"] == &"chronik"
	_check(gefunden, "Chronik ist eine Lexikon-Kategorie")
	state.free()


func _test_chronik_alter_stand() -> void:
	print("Chronik aus alten Spielständen:")
	var state := _state()
	var a := CardFactory.make_starter_card()
	a.tier = 9
	a.times_completed = 3
	var b := CardFactory.make_starter_card()
	b.tier = 12
	var c := CardFactory.make_starter_card()
	c.tier = 5
	c.times_completed = 1
	state.cards.append(a)
	state.cards.append(b)
	state.card_archive.append(c)
	state.party = TestContent.make_party()
	state.party[0].rebirths = 2
	var daten: Dictionary = state.to_save_dict()
	daten.erase("chronik")
	var alt := _state()
	alt.apply_save_dict(daten)
	_check(alt.chronik_wert("dungeons") == 4 and alt.chronik_wert("bosse") == 4,
		"Abschlüsse aus den vorhandenen Karten (4)")
	_check(alt.chronik_wert("hoechste_stufe") == 9, "höchste abgeschlossene Stufe 9 (die 12 ist nicht abgeschlossen)")
	_check(alt.chronik_wert("wiedergeburten") == 2 and alt.chronik_wert("helden_gefallen") == 0,
		"Wiedergeburten aus den Helden, gefallene Helden starten bei 0")
	state.free()
	alt.free()


func _test_bestiarium_stufen() -> void:
	print("Bestiarium-Stufen:")
	var gesamt := BestiariumStufen.grundtypen()
	_check(BestiariumStufen.schwelle(0) == 5 and BestiariumStufen.schwelle(1) == 10,
		"alle 5 Grundtypen eine Stufe")
	_check(BestiariumStufen.schwelle(BestiariumStufen.anzahl() - 1) == gesamt
		and BestiariumStufen.schwelle(BestiariumStufen.anzahl() - 2) < gesamt,
		"die letzte Stufe gilt für alle %d Grundtypen (%d Stufen)" % [gesamt, BestiariumStufen.anzahl()])
	var state := _state()
	state.party = TestContent.make_party()
	var archetypen := EnemyLibrary.all_archetypes()
	for i in 4:
		state.record_kill(archetypen[i].id)
		state.record_kill(archetypen[i].id)  # mehrfach zählt einmal
	_check(state.entdeckte_grundtypen() == 4, "entdeckt = Grundtypen mit mindestens einem Kill (4)")
	_check(BestiariumStufen.abholen(state).is_empty() and state.bestiarium_stufen == 0,
		"4 entdeckt: Stufe 1 noch nicht abholbar")
	state.record_kill(archetypen[4].id)
	var medaillen_vorher: int = state.medaillen_gesamt
	var text := BestiariumStufen.abholen(state)
	_check(not text.is_empty() and state.bestiarium_stufen == 1 and state.medaillen_gesamt == medaillen_vorher + 1,
		"Stufe 1: 1 Mini-Medaille (%s)" % text)
	_check(state.farben_frei.size() == 1 and state.farben_frei[0] == FigurenBau.SONDER_FARBEN[0][0],
		"Stufe 1 schaltet die erste Rüstungsfarbe frei")
	_check(BestiariumStufen.abholen(state).is_empty(), "jede Stufe nur einmal")
	for i in range(5, 10):
		state.record_kill(archetypen[i].id)
	var gold_vorher: int = state.gold
	var level: int = state.average_party_level()
	BestiariumStufen.abholen(state)
	_check(state.gold == gold_vorher + BestiariumStufen.gold_betrag(1, level) and state.gold > gold_vorher,
		"Stufe 2: Gold nach Party-Level (+%d)" % (state.gold - gold_vorher))
	_check(BestiariumStufen.gold_betrag(1, 30) > BestiariumStufen.gold_betrag(1, 5),
		"Gold-Belohnung skaliert mit dem Level")
	for archetyp in archetypen:
		state.record_kill(archetyp.id)
	var stufen := 0
	while not BestiariumStufen.abholen(state).is_empty():
		stufen += 1
	_check(state.bestiarium_stufen == BestiariumStufen.anzahl() and stufen == BestiariumStufen.anzahl() - 2,
		"alle entdeckt: die übrigen %d Stufen nacheinander abholbar" % stufen)
	_check(state.farben_frei.size() == mini(BestiariumStufen.anzahl(), FigurenBau.SONDER_FARBEN.size()),
		"je Stufe eine neue Farbe (%d)" % state.farben_frei.size())
	_check(not BestiariumStufen.abholbar(gesamt, BestiariumStufen.anzahl()), "nach der letzten Stufe ist Schluss")
	state.free()


func _test_farben() -> void:
	print("Rüstungsfarben:")
	var gesamt_ok := true
	for eintrag in FigurenBau.SONDER_FARBEN:
		if not Stil3D.PAL.has(String(eintrag[0])):
			gesamt_ok = false
	_check(gesamt_ok, "jede Sonderfarbe steht in der Hauspalette (STIL-3D)")
	_check(FigurenBau.farb_tiles().size() == SpriteLib.HERO_PORTRAITS.size(),
		"ohne Freischaltung nur die Grundfarben")
	var frei: Array = [FigurenBau.SONDER_FARBEN[2][0], FigurenBau.SONDER_FARBEN[0][0]]
	var tiles := FigurenBau.farb_tiles(frei)
	_check(tiles.size() == SpriteLib.HERO_PORTRAITS.size() + 2
		and tiles[-2] == FigurenBau.SONDER_FARBE_BASIS and tiles[-1] == FigurenBau.SONDER_FARBE_BASIS + 2,
		"freigeschaltete Farben hängen in Stufen-Reihenfolge an")
	var sonder := FigurenBau.held_farbe_aus(FigurenBau.SONDER_FARBE_BASIS + 1, "Edda")
	_check(sonder.is_equal_approx(Stil3D.farbe(String(FigurenBau.SONDER_FARBEN[1][0]))),
		"portrait_tile einer Sonderfarbe ergibt diese Rüstungsfarbe")
	_check(FigurenBau.held_farbe_aus(SpriteLib.HERO_PORTRAITS[0], "Edda").is_equal_approx(Stil3D.farbe("ruestung")),
		"Grundfarben unverändert")
	_check(FigurenBau.held_farbe_aus(-1, "Edda").is_equal_approx(FigurenBau.held_farbe("Edda")),
		"ohne Wahl weiter nach Namen")
	Loc.set_language("en")
	_check(FigurenBau.farb_name(FigurenBau.SONDER_FARBE_BASIS + 1) == "Emerald", "Farbname auf Englisch")
	Loc.set_language("de")
	_check(FigurenBau.farb_name(FigurenBau.SONDER_FARBE_BASIS + 1) == "Smaragd", "… und auf Deutsch")


func _test_abholbar() -> void:
	print("Abholbare Belohnungen (Stadt-Knopf):")
	var state := _state()
	_check(state.abholbar_anzahl() == 0, "frischer Stand: nichts abholbar")
	state.merchant_orders = [{"type": "hunt", "count": 5, "progress": 5, "reward": {"kind": "gold", "gold": 10}},
		{"type": "hunt", "count": 5, "progress": 2, "reward": {"kind": "gold", "gold": 10}}] as Array[Dictionary]
	_check(state.abholbar_anzahl() == 1, "ein erfüllter Auftrag zählt (1)")
	state.medaille(10)
	_check(state.abholbar_anzahl() == 3, "+ zwei erreichte Medaillen-Stufen (5, 10) = 3")
	for i in 5:
		state.record_kill(EnemyLibrary.all_archetypes()[i].id)
	_check(state.abholbar_anzahl() == 4, "+ eine Bestiarium-Stufe = 4")
	MedaillenStufen.abholen(state)
	_check(state.abholbar_anzahl() == 3, "nach dem Abholen zählt es nicht mehr")
	state.free()


func _test_speicher_rundweg() -> void:
	print("Speicher-Rundweg:")
	var state := _state()
	state.party = TestContent.make_party()
	state.bestiarium_stufen = 3
	state.farben_frei.append(&"smaragd")
	state.farben_frei.append(&"obsidian")
	state.chronik_add("bosse", 7)
	state.chronik_add("helden_gefallen", 2)
	state.spielzeit_s = 50.0
	state.start_run(CardFactory.make_starter_card())
	state.bilanz_add("gold", 99)
	state.bilanz_item(Enums.Rarity.LEGENDARY)
	# Über JSON wie die echte Datei (Schlüssel werden zu Strings).
	var daten: Dictionary = JSON.parse_string(JSON.stringify(state.to_save_dict()))
	var neu := _state()
	neu.apply_save_dict(daten)
	_check(neu.bestiarium_stufen == 3 and Array(neu.farben_frei) == [&"smaragd", &"obsidian"],
		"Bestiarium-Stufen und freigeschaltete Farben überstehen den Rundweg")
	_check(neu.chronik_wert("bosse") == 7 and neu.chronik_wert("helden_gefallen") == 2,
		"Chronik übersteht den Rundweg")
	var bilanz: Dictionary = neu.current_run["bilanz"]
	_check(int(bilanz["gold"]) == 99 and int(bilanz["items"].get(Enums.Rarity.LEGENDARY, 0)) == 1
		and not bilanz["teilweise"] and is_equal_approx(float(bilanz["start_s"]), 50.0),
		"Lauf-Bilanz übersteht den Rundweg (Items nach Seltenheit, Startzeit)")
	var alt := daten.duplicate(true)
	for schluessel in ["bestiarium_stufen", "farben_frei", "chronik"]:
		alt.erase(schluessel)
	neu.apply_save_dict(alt)
	_check(neu.bestiarium_stufen == 0 and neu.farben_frei.is_empty() and neu.chronik_wert("bosse") == 0,
		"alter Spielstand ohne neue Schlüssel: Startwerte, kein Absturz")
	neu.reset_to_new_game()
	_check(neu.chronik.is_empty() and neu.farben_frei.is_empty(), "neues Spiel setzt alles zurück")
	state.free()
	neu.free()
