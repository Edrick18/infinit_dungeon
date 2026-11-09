extends SceneTree
## Headless-Selbsttest endlose Ebenen (2026-11-09): jede dritte Ebene Boss,
## jeder fünfte Boss groß, +1 Gegnerstufe alle drei Ebenen, Truhen/Beute auf
## Gegnerstufe, Tiefe alle zehn Ebenen (Licht + Kampfregel), Rastlager,
## Fortschritt pro Karte, kleiner Spielstand, alte Läufe werden beendet.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/endlos_selftest.gd
##
## Speichern ist gesperrt (GameState.slot_gesperrt), Wegwerf-Slot 99.

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	_test_rhythmus()
	_test_generator()
	_test_gegnerstufe()
	_test_grosser_boss()
	_test_truhen()
	_test_tiefe()
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		gs.slot_gesperrt = true
		SaveManager.active_slot = 99
		_test_lauf(gs)
		_test_alte_laeufe(gs)
		await _test_kartenlager(gs)
		await _test_rastlager(gs)
		gs.clear_run()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Tests der endlosen Ebenen bestanden")
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


func _bilder(anzahl: int) -> void:
	for i in anzahl:
		await process_frame


func _karte(seed_wert: int, stufe: int, biom := Enums.Biome.CAVE) -> DungeonCard:
	var karte := DungeonCard.new()
	karte.seed = seed_wert
	karte.tier = stufe
	karte.biome = biom
	return karte


func _rng(seed_wert: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	return rng


func _knopf_mit(wurzel: Node, anfang: Array) -> Button:
	for knoten in wurzel.find_children("*", "Button", true, false):
		var knopf := knoten as Button
		if knopf.is_queued_for_deletion() or not knopf.is_visible_in_tree():
			continue
		for text in anfang:
			if knopf.text.begins_with(text):
				return knopf
	return null


func _test_rhythmus() -> void:
	print("Rhythmus der Ebenen:")
	var karte := _karte(1, 5)
	var bosse := []
	for ebene in 31:
		if DungeonGenerator.ist_boss_ebene(karte, ebene):
			bosse.append(ebene + 1)
	_check(bosse == [3, 6, 9, 12, 15, 18, 21, 24, 27, 30],
		"Boss auf Ebene 3, 6, 9 … (%s)" % [bosse])
	_check(DungeonGenerator.boss_nummer(2) == 1 and DungeonGenerator.boss_nummer(14) == 5
		and DungeonGenerator.boss_nummer(3) == 0, "Bossnummer: Ebene 3 = 1., Ebene 15 = 5., Ebene 4 keiner")
	var grosse := []
	for ebene in 61:
		if DungeonGenerator.ist_grosser_boss(ebene):
			grosse.append(ebene + 1)
	_check(grosse == [15, 30, 45, 60], "großer Boss auf Ebene 15, 30, 45, 60 (%s)" % [grosse])
	var boni := []
	for ebene in 7:
		boni.append(DungeonGenerator.tiefen_bonus(ebene))
	_check(boni == [0, 0, 0, 1, 1, 1, 2], "Gegner +1 alle drei Ebenen (%s)" % [boni])
	_check(DungeonGenerator.tiefe(9) == 0 and DungeonGenerator.tiefe(10) == 1 and DungeonGenerator.tiefe(29) == 2,
		"Tiefe: Ebene 1–10 = 0, Ebene 11 = 1, Ebene 30 = 2")
	var selten := _karte(1, 10)
	selten.card_rarity = Enums.Rarity.RARE
	_check(DungeonGenerator.gegner_stufe(selten, 31) == 10 + 10 + selten.rarity_level_bonus(),
		"Gegnerstufe = Kartenstufe + Tiefen-Bonus + Raritäts-Bonus")


func _test_generator() -> void:
	print("Generator mit beliebig tiefen Ebenen:")
	var karte := _karte(4711, 12)
	var ok := true
	for ebene in [2, 5, 8, 14, 299]:
		var map := DungeonGenerator.generate(karte, ebene)
		ok = ok and map.has_boss and map.stairs_cell.x < 0
	_check(ok, "Boss-Ebenen (auch Ebene 300) sind der Boss-Gang")
	for ebene in [3, 30, 1000]:
		var map := DungeonGenerator.generate(karte, ebene)
		var dist := map.distances_from(map.spawn)
		_check(not map.has_boss and map.stairs_cell.x >= 0 and dist.has(map.stairs_cell) and not map.enemies.is_empty(),
			"Ebene %d: normale Ebene mit erreichbarer Treppe und Gegnern" % (ebene + 1))
	var a := DungeonGenerator.generate(karte, 1000)
	var b := DungeonGenerator.generate(karte, 1000)
	_check(a.cells == b.cells and str(a.chests) == str(b.chests), "Ebene 1001 ist bei gleicher Karte gleich (Seed + Ebene)")
	_check(DungeonGenerator.generate(karte, 999).cells != a.cells, "benachbarte Ebenen unterscheiden sich")


func _test_gegnerstufe() -> void:
	print("Gegnerstufe und Bossstufe:")
	var karte := _karte(9, 9)
	var oben := EnemyFactory.make_encounter(karte, _rng(5), false, 0)[0].level
	var dritte := EnemyFactory.make_encounter(karte, _rng(5), false, 3)[0].level
	var tief := EnemyFactory.make_encounter(karte, _rng(5), false, 30)[0].level
	_check(dritte == oben + 1 and tief == oben + 10, "Ebene 4 +1, Ebene 31 +10 (%d, %d, %d)" % [oben, dritte, tief])
	var boss := EnemyFactory.make_encounter(karte, _rng(5), true, 5)[0]
	_check(boss.ist_bossgegner and boss.level == DungeonGenerator.gegner_stufe(karte, 5),
		"Boss auf Ebene 6 hat die Stufe seines Abschnitts (Lv %d)" % boss.level)
	var legacy := _karte(31, 8)
	legacy.legendary = true
	legacy.card_rarity = Enums.Rarity.LEGENDARY
	legacy.times_completed = 3
	var erster := EnemyFactory.make_encounter(legacy, _rng(2), true, 2)[0]
	_check(erster.level == CardFactory.legacy_boss_level(legacy),
		"Legacy-Anzeige = Level des ersten Bosses (Lv %d)" % erster.level)
	var spaeter := EnemyFactory.make_encounter(legacy, _rng(2), true, 8)[0]
	_check(spaeter.level == erster.level + 2, "Legacy-Bonus gilt zusätzlich zur Tiefe (Lv %d » %d)"
		% [erster.level, spaeter.level])
	var figur := EnemyFactory.boss_figur_id(karte, 14)
	var rng := RandomNumberGenerator.new()
	rng.seed = EnemyFactory.encounter_seed(karte, 14, -1)
	_check(EnemyFactory.make_encounter(karte, rng, true, 14)[0].archetype_id == figur,
		"Boss-Figur = Boss im Kampf, auch auf Ebene 15")


func _test_grosser_boss() -> void:
	print("Großer Boss:")
	var karte := _karte(1234, 12)
	var gross := EnemyFactory.make_encounter(karte, _rng(7), true, 14)[0]
	# Gleicher Abschnitt, gleiche Stufe, aber kein großer Boss (Ebene 13).
	var normal := EnemyFactory.make_encounter(karte, _rng(7), true, 12)[0]
	_check(gross.level == normal.level and gross.archetype_id == normal.archetype_id, "Vergleichs-Boss: gleiche Stufe, gleicher Typ")
	var merkmale := EnemyFactory.grosser_boss_merkmale(karte, 14, gross.level, [])
	var ohne_aura := true
	for merkmal in merkmale:
		ohne_aura = ohne_aura and merkmal.aura_status < 0
	_check(merkmale.size() == EnemyFactory.GROSSER_BOSS_MERKMALE and merkmale[0] != merkmale[1] and ohne_aura,
		"zwei verschiedene zusätzliche Merkmale, keine Anführer-Auren")
	var nochmal := EnemyFactory.grosser_boss_merkmale(karte, 14, gross.level, [])
	_check(merkmale == nochmal, "Merkmale fest aus Seed und Ebene")
	_check(gross.display_name != normal.display_name, "die Merkmale stehen im Namen (%s)" % gross.display_name)
	_check(gross.loot_mult >= normal.loot_mult * EnemyFactory.GROSSER_BOSS_BEUTE - 0.001,
		"doppelte Beute (×%.2f gegen ×%.2f)" % [gross.loot_mult, normal.loot_mult])


func _test_truhen() -> void:
	print("Truhen in der Tiefe:")
	var gold_oben := 0
	var gold_tief := 0
	for i in 20:
		var karte := _karte(500 + i, 6)
		for truhe in DungeonGenerator.generate(karte, 0).chests:
			gold_oben += int(truhe["gold"])
		for truhe in DungeonGenerator.generate(karte, 30).chests:
			gold_tief += int(truhe["gold"])
	_check(gold_tief > gold_oben, "Truhen-Gold folgt der Gegnerstufe (%d > %d)" % [gold_tief, gold_oben])
	_check(DungeonGenerator.TRUHEN_TIEFE_MAX == 4, "Seltenheits-Bonus der Tiefe auf 4 Würfe gedeckelt")


func _test_tiefe() -> void:
	print("Tiefe: Licht und Kampfregel:")
	_check(is_equal_approx(DungeonGenerator.tiefen_licht_faktor(0), 1.0)
		and is_equal_approx(DungeonGenerator.tiefen_licht_faktor(1), 0.92)
		and is_equal_approx(DungeonGenerator.tiefen_licht_faktor(50), DungeonGenerator.TIEFE_LICHT_MIN),
		"Licht: 100 %, Tiefe 1 92 %, gedeckelt bei 60 %")
	var stil := {"ambient_energie": 0.5, "licht_energie": 0.8}
	DungeonGenerator.tiefen_licht_anwenden(stil, 2)
	_check(is_equal_approx(stil["ambient_energie"], 0.42) and is_equal_approx(stil["licht_energie"], 0.672),
		"Licht wird im Stil gedimmt (Umgebung und Hauptlicht)")
	var hoch := _karte(77, 50)
	_check(Sonderregeln.tiefen_regel_fuer(hoch, 9) == &"", "Tiefe 0: keine Regel")
	var regel := Sonderregeln.tiefen_regel_fuer(hoch, 10)
	_check(regel in Sonderregeln.KAMPF_REGELN, "Tiefe 1: eine Kampfregel (%s)" % regel)
	_check(Sonderregeln.tiefen_regel_fuer(hoch, 19) == regel, "gleiche Regel in der ganzen Tiefe")
	var wechsel := false
	for s in 10:
		var probe := _karte(900 + s, 50)
		if Sonderregeln.tiefen_regel_fuer(probe, 10) != Sonderregeln.tiefen_regel_fuer(probe, 20):
			wechsel = true
	_check(wechsel, "mit der nächsten Tiefe kommt eine neue Regel")
	var eigene := _karte(77, 50)
	eigene.sonderregel = regel
	_check(Sonderregeln.tiefen_regel_fuer(eigene, 10) != regel, "nie die Regel, die die Karte schon trägt")
	var klein := _karte(77, 1)
	_check(Sonderregeln.tiefen_regel_fuer(klein, 10) == &"", "Mindeststufen gelten (Stufe-1-Karte, Tiefe 1: keine)")
	var mittel := _karte(77, 12)
	var mittel_regel := Sonderregeln.tiefen_regel_fuer(mittel, 10)
	_check(mittel_regel == Sonderregeln.AUSWEGLOS, "Gegnerstufe 15: nur Ausweglos möglich (%s)" % mittel_regel)
	hoch.tiefen_regel = regel
	_check(Sonderregeln.hat(hoch, regel) and regel in Sonderregeln.regeln(hoch), "die Regel der Tiefe wirkt (hat/regeln)")
	_check(not DungeonGenerator.tiefen_hinweis(hoch, 10).is_empty(), "Hinweistext zur Regel der Tiefe")
	_check(DungeonGenerator.ebenen_text(14, true).contains("15") and DungeonGenerator.ebenen_text(14, true) != DungeonGenerator.ebenen_text(11, true),
		"HUD: großer Boss eigens benannt")
	_check(DungeonGenerator.ebenen_text(12, false).contains("+4") and DungeonGenerator.ebenen_text(12, false).contains("1"),
		"HUD: Ebene 13 zeigt Gegner +4 und Tiefe 1 (%s)" % DungeonGenerator.ebenen_text(12, false))


func _test_lauf(gs: Node) -> void:
	print("Lauf: Einstieg, Ebenenwechsel, Fortschritt:")
	var lager_karte := CardFactory.make_starter_card()
	var karten: Array[DungeonCard] = [lager_karte]
	gs.cards = karten
	gs.start_run(lager_karte, 6)
	_check(int(gs.current_run["floor"]) == 6, "Einstieg ab gesichertem Fortschritt (Ebene 7)")
	gs.current_run["defeated"].append(6001)
	gs.current_run["opened"].append(6002)
	gs.current_run["explored_by_floor"] = {6: {Vector2i(1, 1): true}}
	gs.current_run["gegner_by_floor"] = {"6": [[1, 2, 3]]}
	gs.current_run["tresore"] = [6]
	gs.ebene_wechseln(7)
	var leer := true
	for liste in GameState.EBENEN_DATEN:
		leer = leer and (gs.current_run[liste] as Array).is_empty()
	_check(int(gs.current_run["floor"]) == 7 and leer and (gs.current_run["explored_by_floor"] as Dictionary).is_empty()
		and not gs.current_run.has("gegner_by_floor") and not gs.current_run["boss_defeated"],
		"Treppe: alle Daten der alten Ebene fallen weg")
	# Nach dem Laden trägt der Lauf eine Kopie der Karte.
	var kopie := DungeonCard.from_dict(lager_karte.to_dict())
	gs.boss_besiegt(kopie, 8)
	_check(lager_karte.fortschritt_ebene == 9 and kopie.fortschritt_ebene == 9
		and lager_karte.times_completed == 1 and kopie.times_completed == 1,
		"Bosssieg sichert Fortschritt und Abschluss, auch auf der Lagerkarte")
	gs.boss_besiegt(lager_karte, 2)
	_check(lager_karte.fortschritt_ebene == 9 and lager_karte.times_completed == 2, "Fortschritt sinkt nie")
	var streifzug := CardFactory.make_streifzug_card(5)
	gs.boss_besiegt(streifzug, 2)
	_check(gs.lager_karte(streifzug) == null and streifzug.fortschritt_ebene == 3, "Streifzug: kein Lagereintrag")
	lager_karte.tiefen_regel = Sonderregeln.WACHSAM
	gs.clear_run()
	_check(lager_karte.tiefen_regel == &"", "Zurück in der Stadt: keine Regel der Tiefe mehr auf der Karte")
	# Spielstand wächst nicht mit der Tiefe.
	gs.start_run(lager_karte)
	gs.current_run["explored_by_floor"] = {}
	var groessen := {}
	for ebene in range(1, 101):
		gs.current_run["defeated"].append(ebene * 1000 + 1)
		gs.current_run["explored_by_floor"][ebene] = {Vector2i(ebene, 1): true}
		gs.ebene_wechseln(ebene)
		if ebene in [10, 100]:
			groessen[ebene] = JSON.stringify(gs.to_save_dict()["current_run"]).length()
	# Nur die längere Ebenen-Nummer darf dazukommen (10 » 100: eine Ziffer).
	_check(groessen[100] <= groessen[10] + 2, "Laufdaten wachsen nicht mit der Tiefe (Ebene 11: %d, Ebene 101: %d Zeichen)"
		% [groessen[10], groessen[100]])
	gs.clear_run()


func _test_alte_laeufe(gs: Node) -> void:
	print("Alte Läufe beim Laden:")
	var karte := CardFactory.make_starter_card()
	var karten: Array[DungeonCard] = [karte]
	gs.cards = karten
	gs.start_run(karte, 3)
	var daten: Dictionary = gs.to_save_dict()
	_check(int(daten["current_run"].get("ebenen_version", 0)) == GameState.EBENEN_VERSION, "Lauf trägt die Ebenen-Version")
	gs.apply_save_dict(daten.duplicate(true))
	_check(not gs.current_run.is_empty() and int(gs.current_run["floor"]) == 3, "neuer Lauf übersteht Speichern/Laden")
	var alt: Dictionary = daten.duplicate(true)
	alt["current_run"].erase("ebenen_version")
	gs.apply_save_dict(alt)
	_check(gs.current_run.is_empty() and gs.cards.size() == 1, "alter Lauf wird einmal beendet, Karten bleiben")


func _test_kartenlager(gs: Node) -> void:
	print("Kartenlager: Einstieg ab Fortschritt:")
	var karte := CardFactory.make_starter_card()
	karte.fortschritt_ebene = 6
	var neu := CardFactory.make_starter_card()
	var karten: Array[DungeonCard] = [karte, neu]
	gs.cards = karten
	gs.current_run = {}
	var szene: Node = load("res://scenes/hub/card_storage.tscn").instantiate()
	root.add_child(szene)
	await _bilder(3)
	var ab := _knopf_mit(szene._card_list, [Loc.pick("Ab Ebene 7", "From floor 7")])
	_check(ab != null, "Knopf „Ab Ebene 7“ bei gesichertem Fortschritt")
	var zeilen := 0
	for knoten in szene._card_list.find_children("*", "Button", true, false):
		if (knoten as Button).text.begins_with(Loc.pick("Ab Ebene", "From floor")):
			zeilen += 1
	_check(zeilen == 1, "nur Karten mit Fortschritt haben den Knopf (%d)" % zeilen)
	# Laufender Dungeon: der erste Klick fragt nach.
	gs.current_run = {"card": neu}
	szene._refresh()
	await _bilder(2)
	_knopf_mit(szene._card_list, [Loc.pick("Ab Ebene 7", "From floor 7")]).pressed.emit()
	await _bilder(2)
	_check(_knopf_mit(szene._card_list, [Loc.pick("Laufenden Dungeon verwerfen?", "Discard the current dungeon?")]) != null
		and _knopf_mit(szene._card_list, [Loc.pick("Ab Ebene 7", "From floor 7")]) == null,
		"laufender Dungeon: erster Klick auf „Ab Ebene 7“ fragt nach")
	gs.current_run = {}
	szene.queue_free()
	await _bilder(1)


func _test_rastlager(gs: Node) -> void:
	print("Rastlager nach dem Boss:")
	var karte := DungeonCard.new()
	karte.seed = 4242
	karte.tier = 8
	gs.first_time("dungeon")  # Onboarding-Hinweis nicht ins Bild
	var karten: Array[DungeonCard] = [karte]
	gs.cards = karten
	gs.start_run(karte, 5)
	gs.current_run["boss_defeated"] = true
	var szene: Node = load("res://scenes/dungeon/dungeon_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(3)
	_check(szene._abschluss != null, "nach dem Boss öffnet das Rastlager")
	if szene._abschluss != null:
		var weiter := _knopf_mit(szene._abschluss, [Loc.pick("Weiter hinab", "Descend further")])
		var zurueck := _knopf_mit(szene._abschluss, [Loc.pick("Zurück in die Stadt", "Back to town")])
		_check(weiter != null and zurueck != null, "Wahl: weiter hinab oder zurück in die Stadt")
		_check(weiter != null and weiter.text.contains("7"), "„Weiter hinab“ nennt Ebene 7")
		_check(root.gui_get_focus_owner() == weiter, "Fokus liegt auf „Weiter hinab“")
	# „Weiter hinab“ ohne Szenenwechsel nachstellen: Heilung + nächste Ebene.
	var held: Combatant = gs.party[0] if not gs.party.is_empty() else null
	if held != null:
		held.hp = 1
	gs.heal_party()
	gs.ebene_wechseln(6)
	_check(held == null or held.hp == held.max_hp, "volle Heilung")
	_check(int(gs.current_run["floor"]) == 6 and not gs.current_run["boss_defeated"], "nächste Ebene, Boss-Status zurückgesetzt")
	szene.queue_free()
	await _bilder(2)
