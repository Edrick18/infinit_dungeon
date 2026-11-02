extends SceneTree
## Headless-Selbsttest für besondere Dungeons (Sonderregeln + Tresor):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/sonder_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_wuerfeln()
	_test_speichern()
	_test_gegner()
	_test_manaflut()
	_test_schatzfieber()
	_test_tresor()
	_test_kampfregeln_wuerfeln()
	_test_kampfregeln_wirkung()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Sonder-Dungeon-Tests bestanden")
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


func _karte(regel: StringName, stufe := 12, seed_wert := 4242) -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	var card := CardFactory.make_card(stufe, rng)
	card.sonderregel = regel
	card.sonder_element = Enums.Element.ICE if regel == Sonderregeln.ELEMENTARSTURM else -1
	if card.modifier_ids.is_empty():
		card.modifier_ids = EnemyLibrary.roll_modifiers(stufe, rng)
	return card


func _gruppen(card: DungeonCard, anzahl := 30) -> Array:
	var gruppen: Array = []
	for i in anzahl:
		var rng := RandomNumberGenerator.new()
		rng.seed = card.seed + i * 7919
		gruppen.append(EnemyFactory.make_encounter(card, rng, false, 0))
	return gruppen


func _test_wuerfeln() -> void:
	print("Würfeln:")
	var zaehler := {}
	var unter_stufe := 0
	for i in 2000:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var card := CardFactory.make_card(10, rng)
		if card.sonderregel != &"":
			zaehler[card.sonderregel] = int(zaehler.get(card.sonderregel, 0)) + 1
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = i
		if CardFactory.make_card(2, rng2).sonderregel != &"":
			unter_stufe += 1
	var gesamt := 0
	for regel in zaehler:
		gesamt += int(zaehler[regel])
	var auf_stufe_10 := Sonderregeln.pool(10)
	_check(zaehler.size() == auf_stufe_10.size(), "alle %d Regeln der Stufe 10 kommen vor (%s)" % [auf_stufe_10.size(), zaehler])
	_check(gesamt > 100 and gesamt < 400, "etwa jede 10. Karte ab Stufe 3 ist besonders (%d von 2000)" % gesamt)
	_check(unter_stufe == 0, "unter Stufe 3 keine Sonderregel")
	_check(CardFactory.make_starter_card().sonderregel == &"", "Startkarte ohne Sonderregel")
	var sturm := _karte(Sonderregeln.ELEMENTARSTURM)
	_check(Sonderregeln.text_von(sturm).contains(BlockLibrary.element_block(Enums.Element.ICE).display_name),
		"Elementarsturm nennt sein Element: %s" % Sonderregeln.text_von(sturm))


func _test_speichern() -> void:
	print("Speichern:")
	var card := _karte(Sonderregeln.ELEMENTARSTURM)
	var kopie := DungeonCard.from_dict(card.to_dict())
	_check(kopie.sonderregel == Sonderregeln.ELEMENTARSTURM and kopie.sonder_element == Enums.Element.ICE,
		"Sonderregel und Element überstehen den Rundweg")
	var alt := card.to_dict()
	alt.erase("sonderregel")
	alt.erase("sonder_element")
	_check(DungeonCard.from_dict(alt).sonderregel == &"", "alte Karten ohne Feld » keine Sonderregel")


func _test_gegner() -> void:
	print("Gegner:")
	var alle_eis := true
	for gruppe in _gruppen(_karte(Sonderregeln.ELEMENTARSTURM)):
		for gegner in gruppe:
			if int(gegner.get_meta(&"element_schicht", -1)) != Enums.Element.ICE:
				alle_eis = false
	_check(alle_eis, "Elementarsturm: jeder Gegner trägt das Element")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var boss := EnemyFactory.make_encounter(_karte(Sonderregeln.ELEMENTARSTURM), rng, true, 0)
	_check(int(boss[0].get_meta(&"element_schicht", -1)) == Enums.Element.ICE, "Elementarsturm: auch der Boss")

	var alle_untot := true
	for gruppe in _gruppen(_karte(Sonderregeln.TOTENREICH)):
		for gegner in gruppe:
			alle_untot = alle_untot and gegner.is_undead
	_check(alle_untot, "Totenreich: alle Gegner untot")

	var max_gruppe := 0
	var normal := _gruppen(_karte(&""))
	var riesen := _gruppen(_karte(Sonderregeln.RIESENWUCHS))
	for gruppe in riesen:
		max_gruppe = maxi(max_gruppe, gruppe.size())
	_check(max_gruppe <= Sonderregeln.RIESEN_GRUPPE, "Riesenwuchs: höchstens 2 Gegner pro Gruppe (%d)" % max_gruppe)
	_check(riesen[0][0].max_hp > normal[0][0].max_hp * 1.5, "Riesenwuchs: deutlich mehr HP (%d vs %d)"
		% [riesen[0][0].max_hp, normal[0][0].max_hp])

	var alle_elite := true
	for gruppe in _gruppen(_karte(Sonderregeln.JAGDGEBIET)):
		alle_elite = alle_elite and gruppe[0].has_meta(&"rang")
	_check(alle_elite, "Jagdgebiet: jeder Anführer ist Elite oder Champion")
	var jagd := _gruppen(_karte(Sonderregeln.JAGDGEBIET))
	_check(jagd[0][0].loot_mult > normal[0][0].loot_mult, "Jagdgebiet: mehr Beute")


func _test_manaflut() -> void:
	print("Manaflut:")
	var held := Combatant.create("Magier", StatBlock.new(), true)
	var skill := Skill.new()
	skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
	skill.blocks.append(BlockLibrary.get_block(&"elem_fire"))
	var normal := skill.get_mp_cost(held)
	held.kosten_mult = Sonderregeln.kosten_mult(_karte(Sonderregeln.MANAFLUT))
	var flut := skill.get_mp_cost(held)
	_check(flut < normal and flut >= 1, "Manaflut halbiert die Kosten (%d » %d)" % [normal, flut])
	_check(is_equal_approx(Sonderregeln.kosten_mult(_karte(&"")), 1.0), "ohne Manaflut Faktor 1")


func _test_schatzfieber() -> void:
	print("Schatzfieber:")
	var normal := DungeonGenerator.generate(_karte(&"", 12, 99))
	var fieber := DungeonGenerator.generate(_karte(Sonderregeln.SCHATZFIEBER, 12, 99))
	_check(fieber.chests.size() >= normal.chests.size() * 2 - 1,
		"doppelt so viele Truhen (%d vs %d)" % [fieber.chests.size(), normal.chests.size()])
	# Mimics würfeln beim Öffnen (nicht in der Karte festgelegt, Lutz 2026-10-24).
	var markiert := 0
	for chest in fieber.chests:
		if chest.has("mimic"):
			markiert += 1
	_check(markiert == 0, "keine Truhe ist schon in der Karte als Mimic festgelegt")
	_check(is_equal_approx(Sonderregeln.mimic_chance(_karte(Sonderregeln.SCHATZFIEBER, 12, 1)), 0.25)
		and is_equal_approx(Sonderregeln.mimic_chance(_karte(&"", 12, 1)), 0.05)
		and Sonderregeln.mimic_chance(_karte(&"", 2, 1)) == 0.0,
		"Mimic-Chance beim Öffnen: Schatzfieber 25 %, sonst 5 %, Stufe 1–2 nie")


func _test_tresor() -> void:
	print("Tresor:")
	var mit := 0
	var gueltig := true
	for s in 80:
		var card := _karte(&"", 12, 2000 + s)
		var map := DungeonGenerator.generate(card, 1)
		if map.tresor_cell.x < 0:
			continue
		mit += 1
		var traeger_da := false
		for gegner in map.enemies:
			if int(gegner["id"]) == map.schluessel_id:
				traeger_da = true
		gueltig = gueltig and traeger_da and map.is_floor(map.tresor_cell)
		var nochmal := DungeonGenerator.generate(card, 1)
		gueltig = gueltig and nochmal.tresor_cell == map.tresor_cell and nochmal.schluessel_id == map.schluessel_id
	_check(mit > 8 and mit < 35, "etwa jede 4. Ebene hat einen Tresor (%d von 80)" % mit)
	_check(gueltig, "Tresor liegt auf Boden, Schlüsselträger existiert, alles seed-fest")
	var auf_stufe_1 := 0
	for s in 40:
		if DungeonGenerator.generate(_karte(&"", 1, 3000 + s)).tresor_cell.x >= 0:
			auf_stufe_1 += 1
	_check(auf_stufe_1 == 0, "auf Stufe 1 kein Tresor")
	var sonder := 0
	for s in 80:
		if DungeonGenerator.generate(_karte(Sonderregeln.TOTENREICH, 12, 2000 + s), 1).tresor_cell.x >= 0:
			sonder += 1
	_check(sonder > mit, "besondere Dungeons haben öfter einen Tresor (%d > %d)" % [sonder, mit])


# --- Kampfregeln (Regeln statt nur Grind, 2026-11-02) ------------------------------

func _regel_anteil(stufe: int, anzahl := 3000) -> Dictionary:
	var mit := 0
	var zwei := 0
	var arten := {}
	for i in anzahl:
		var rng := RandomNumberGenerator.new()
		rng.seed = 50000 + i
		var card := CardFactory.make_card(stufe, rng)
		if card.sonderregel != &"":
			mit += 1
			arten[card.sonderregel] = true
		if card.sonderregel_2 != &"":
			zwei += 1
			arten[card.sonderregel_2] = true
			_check_still(card.sonderregel_2 in Sonderregeln.KAMPF_REGELN and card.sonderregel_2 != card.sonderregel,
				"zweite Regel ist eine andere Kampfregel")
	return {"mit": float(mit) / anzahl, "zwei": float(zwei) / anzahl, "arten": arten}


var _still_fehler := 0


func _check_still(bedingung: bool, label: String) -> void:
	if not bedingung:
		_still_fehler += 1
		if _still_fehler == 1:
			printerr("  FEHLER: " + label)
		failures += 1


func _test_kampfregeln_wuerfeln() -> void:
	print("Kampfregeln — Häufigkeit und Pool:")
	var s10 := _regel_anteil(10)
	var s40 := _regel_anteil(40)
	var s60 := _regel_anteil(60)
	var s100 := _regel_anteil(100)
	print("  Anteil mit Regel: Stufe 10 %.1f %%, 40 %.1f %%, 60 %.1f %%, 100 %.1f %%; zwei Regeln: 60 %.1f %%, 100 %.1f %%"
		% [s10["mit"] * 100, s40["mit"] * 100, s60["mit"] * 100, s100["mit"] * 100, s60["zwei"] * 100, s100["zwei"] * 100])
	_check(s60["mit"] > s40["mit"] + 0.1 and s100["mit"] > s60["mit"], "ab Stufe 50 deutlich mehr Karten mit Regel")
	_check(s10["zwei"] == 0.0 and s40["zwei"] == 0.0 and s60["zwei"] > 0.02 and s100["zwei"] > s60["zwei"],
		"zweite Regel erst ab Stufe 50, danach häufiger")
	var neu_unter := false
	for regel in Sonderregeln.KAMPF_REGELN:
		neu_unter = neu_unter or s10["arten"].has(regel)
	_check(not neu_unter, "auf Stufe 10 noch keine Kampfregel")
	_check(s100["arten"].size() == Sonderregeln.ALLE.size(), "auf Stufe 100 kommen alle %d Regeln vor (%d)"
		% [Sonderregeln.ALLE.size(), s100["arten"].size()])
	for regel in Sonderregeln.ALLE:
		var t: Array = Sonderregeln.TEXTE.get(regel, [])
		_check_still(t.size() == 4 and not String(t[2]).is_empty() and not String(t[3]).is_empty(), "Texte DE+EN für %s" % regel)
	# Speichern: zweite Regel übersteht den Rundweg, alte Karten haben keine.
	var card := _karte(Sonderregeln.AUSWEGLOS)
	card.sonderregel_2 = Sonderregeln.POLARITAET
	var kopie := DungeonCard.from_dict(JSON.parse_string(JSON.stringify(card.to_dict())))
	_check(kopie.sonderregel == Sonderregeln.AUSWEGLOS and kopie.sonderregel_2 == Sonderregeln.POLARITAET,
		"zwei Regeln überstehen den Speicher-Rundweg")
	var alt := card.to_dict()
	alt.erase("sonderregel_2")
	_check(DungeonCard.from_dict(alt).sonderregel_2 == &"", "alte Karten ohne Feld » keine zweite Regel")
	# Anzeige: beide Regeln mit Namen und Text, in beiden Sprachen.
	var zeile := Sonderregeln.zeile(card)
	_check(zeile.contains("Ausweglos: Fliehen") and zeile.contains("Polarität: Element-Schwächen"),
		"Anzeige nennt beide Regeln: %s" % zeile.replace("\n", " | "))
	_check(Sonderregeln.name_von(card) == "Ausweglos · Polarität", "Kurzname: %s" % Sonderregeln.name_von(card))
	Loc.set_language("en")
	var zeile_en := Sonderregeln.zeile(card)
	Loc.set_language("de")
	_check(zeile_en.contains("No way out: Fleeing") and zeile_en.contains("Polarity:"), "Anzeige englisch: %s"
		% zeile_en.replace("\n", " | "))
	# Belohnungsausgleich: Faktoren multiplizieren sich.
	_check(is_equal_approx(Sonderregeln.beute_mult(card), 1.2 * 1.15)
		and is_equal_approx(Sonderregeln.xp_mult(card), 1.1), "Beute/XP-Faktoren beider Regeln")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var gruppe := EnemyFactory.make_encounter(card, rng, false, 0)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 77
	var ohne := EnemyFactory.make_encounter(_karte(&""), rng2, false, 0)
	_check(gruppe[0].loot_mult > ohne[0].loot_mult, "Gegner der Karte tragen den Beute-Bonus (%.2f vs %.2f)"
		% [gruppe[0].loot_mult, ohne[0].loot_mult])


func _held(name := "Held") -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 8)
	return Combatant.create(name, stats, true)


func _test_kampfregeln_wirkung() -> void:
	print("Kampfregeln — Wirkung:")
	# Ausweglos / Versiegelte Taschen / Kampfrausch: Befehle gesperrt.
	_check(not Sonderregeln.befehl_gesperrt(_karte(Sonderregeln.AUSWEGLOS), "flee").is_empty()
		and Sonderregeln.befehl_gesperrt(_karte(&""), "flee").is_empty()
		and Sonderregeln.befehl_gesperrt(_karte(Sonderregeln.AUSWEGLOS), "item").is_empty(),
		"Ausweglos sperrt nur Fliehen")
	_check(not Sonderregeln.befehl_gesperrt(_karte(Sonderregeln.VERSIEGELT), "item").is_empty(),
		"Versiegelte Taschen sperren Gegenstände")
	var rausch := _karte(Sonderregeln.KAMPFRAUSCH)
	_check(not Sonderregeln.befehl_gesperrt(rausch, "defend").is_empty()
		and Sonderregeln.befehl_gesperrt(rausch, "focus").is_empty(), "Kampfrausch sperrt Verteidigen")
	var zweit := _karte(Sonderregeln.TOTENREICH)
	zweit.sonderregel_2 = Sonderregeln.AUSWEGLOS
	_check(not Sonderregeln.befehl_gesperrt(zweit, "flee").is_empty(), "auch als zweite Regel wirksam")
	_check(Sonderregeln.befehl_gesperrt(null, "flee").is_empty(), "Menü-Testkampf (keine Karte): nichts gesperrt")

	# Kampfrausch: Konzentrieren +100 % je Zug bis +300 %.
	var held := _held()
	var feind := Combatant.create("Feind", StatBlock.new(), false)
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.start([held] as Array[Combatant], [feind] as Array[Combatant])
	var stufen: Array[int] = []
	for i in 4:
		Sonderregeln.rausch_konzentrieren(battle, held)
		stufen.append(int(held.get_status(Enums.Status.FOCUS)["potency"]))
	_check(stufen == ([100, 200, 300, 300] as Array[int]), "Kampfrausch: Konzentrieren 100/200/300/300 (%s)" % [stufen])
	var normal := _held("Normal")
	battle.concentrate(normal)
	_check(int(normal.get_status(Enums.Status.FOCUS)["potency"]) == Battle.FOCUS_STEP, "ohne Regel bleibt es bei +50 %")

	# Polarität: Schwäche ×1,5 » ×2, Resistenz ×0,5 » ×0,25, nur einmal, nie Helden.
	var pol := _karte(Sonderregeln.POLARITAET)
	var gegner := Combatant.create("Feuerwolf", StatBlock.new(), false)
	gegner.element_faktoren = {Enums.Element.ICE: 1.5, Enums.Element.FIRE: 0.5, Enums.Element.HOLY: 1.0}
	Sonderregeln.polaritaet_anwenden(pol, gegner)
	Sonderregeln.polaritaet_anwenden(pol, gegner)
	_check(is_equal_approx(gegner.element_faktor(Enums.Element.ICE), 2.0)
		and is_equal_approx(gegner.element_faktor(Enums.Element.FIRE), 0.25)
		and is_equal_approx(gegner.element_faktor(Enums.Element.HOLY), 1.0),
		"Polarität: Eis ×2, Feuer ×0,25, Heilig ×1 (auch bei doppeltem Aufruf)")
	var ohne_pol := Combatant.create("Wolf", StatBlock.new(), false)
	ohne_pol.element_faktoren = {Enums.Element.ICE: 1.5}
	Sonderregeln.polaritaet_anwenden(_karte(&""), ohne_pol)
	_check(is_equal_approx(ohne_pol.element_faktor(Enums.Element.ICE), 1.5), "ohne Regel unverändert")
	# Im echten Treffer: Eis-Treffer auf den Gegner macht mehr Schaden.
	var echte := EnemyFactory.make_encounter(pol, _rng_mit(31), false, 0)
	var schwach := -1
	for element in echte[0].element_faktoren:
		if float(echte[0].element_faktoren[element]) > 1.0:
			schwach = element
	if schwach >= 0:
		var vorher := echte[0].element_faktor(schwach)
		Sonderregeln.polaritaet_anwenden(pol, echte[0])
		_check(echte[0].element_faktor(schwach) > vorher, "echter Gegner: Schwäche verstärkt (%.2f » %.2f)"
			% [vorher, echte[0].element_faktor(schwach)])

	# Nachschub: Simulation über viele Kämpfe — je Gefallenem 40 %, höchstens 2.
	var nach := _karte(Sonderregeln.NACHSCHUB, 45)
	var gesamt := 0
	var hoechstens := 0
	var kaempfe := 400
	for k in kaempfe:
		var b := Battle.new()
		b.rng.seed = 900 + k
		var foes := EnemyFactory.make_encounter(nach, _rng_mit(k), false, 0)
		b.start([_held()] as Array[Combatant], foes)
		var zaehler := 0
		for runde in 3:
			for foe in b.enemies:
				if foe.is_alive():
					foe.hp = 0
					break
			zaehler += Sonderregeln.nachschub(b, nach, 0, b.rng).size()
		gesamt += zaehler
		hoechstens = maxi(hoechstens, zaehler)
	var schnitt := float(gesamt) / kaempfe
	_check(hoechstens <= Sonderregeln.NACHSCHUB_MAX, "Nachschub: höchstens %d je Kampf (%d)" % [Sonderregeln.NACHSCHUB_MAX, hoechstens])
	_check(schnitt > 0.8 and schnitt < 1.5, "Nachschub: Ø %.2f neue Gegner bei 3 Gefallenen" % schnitt)
	var ohne_regel := Battle.new()
	var foes2 := EnemyFactory.make_encounter(_karte(&"", 45), _rng_mit(5), false, 0)
	ohne_regel.start([_held()] as Array[Combatant], foes2)
	foes2[0].hp = 0
	_check(Sonderregeln.nachschub(ohne_regel, _karte(&"", 45), 0, _rng_mit(1)).is_empty(), "ohne Regel kein Nachschub")
	var boss_kampf := Battle.new()
	var boss := EnemyFactory.make_encounter(nach, _rng_mit(8), true, 0)
	var begleiter := EnemyFactory.make_encounter(nach, _rng_mit(9), false, 0)
	var alle: Array[Combatant] = []
	alle.append_array(boss)
	alle.append_array(begleiter)
	boss_kampf.start([_held()] as Array[Combatant], alle)
	begleiter[0].hp = 0
	var im_boss := 0
	for i in 20:
		begleiter[0].remove_meta(&"nachschub_geprueft")
		im_boss += Sonderregeln.nachschub(boss_kampf, nach, 0, _rng_mit(i)).size()
	_check(im_boss == 0, "kein Nachschub im Bosskampf")
	var gemeldet := []
	var neue: Array[Combatant] = []
	var b3: Battle = null
	for versuch in 40:
		if not neue.is_empty():
			break
		b3 = Battle.new()
		b3.rng.seed = 3000 + versuch
		b3.start([_held()] as Array[Combatant], EnemyFactory.make_encounter(nach, _rng_mit(3000 + versuch), false, 0))
		b3.combatant_added.connect(func(c: Combatant) -> void: gemeldet.append(c))
		b3.enemies[0].hp = 0
		neue = Sonderregeln.nachschub(b3, nach, 0, b3.rng)
	_check(not neue.is_empty() and neue[0] in b3.enemies and neue[0] in gemeldet and neue[0].is_alive()
		and neue[0].level >= nach.tier, "Nachrücker kämpft mit, ist gemeldet und hat Kartenstufe")

	# Wachsamkeit: kein Erstschlag, Rundumsicht.
	var wach := _karte(Sonderregeln.WACHSAM)
	_check(Sonderregeln.ueberraschung_anpassen(wach, Battle.ERSTSCHLAG) == Battle.KEINE_UEBERRASCHUNG
		and Sonderregeln.ueberraschung_anpassen(wach, Battle.HINTERHALT) == Battle.HINTERHALT
		and Sonderregeln.ueberraschung_anpassen(_karte(&""), Battle.ERSTSCHLAG) == Battle.ERSTSCHLAG,
		"Wachsamkeit: Erstschlag entfällt, Hinterhalt bleibt")
	var gegner_hinten := {"kurs": Vector2(1, 0)}
	var von_hinten := Anschleichen.bemerkt(Vector2(0, 0), gegner_hinten, Vector2(200, 0), 200.0)
	_check(not von_hinten and Sonderregeln.rundumsicht(wach) and not Sonderregeln.rundumsicht(_karte(&"")),
		"Wachsamkeit: Gegner sehen auch nach hinten")


func _rng_mit(seed_wert: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	return rng
