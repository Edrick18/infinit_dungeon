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
	_check(zaehler.size() == Sonderregeln.ALLE.size(), "alle %d Regeln kommen vor (%s)" % [Sonderregeln.ALLE.size(), zaehler])
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
	var mimics := 0
	var gesamt := 0
	for s in 40:
		for chest in DungeonGenerator.generate(_karte(Sonderregeln.SCHATZFIEBER, 12, 1000 + s)).chests:
			gesamt += 1
			if chest.get("mimic", false):
				mimics += 1
	var anteil := float(mimics) / gesamt
	_check(anteil > 0.15 and anteil < 0.35, "etwa jede 4. Truhe ist ein Mimic (%.0f %%)" % (anteil * 100))
	var a := DungeonGenerator.generate(_karte(Sonderregeln.SCHATZFIEBER, 12, 77))
	var b := DungeonGenerator.generate(_karte(Sonderregeln.SCHATZFIEBER, 12, 77))
	var gleich := a.chests.size() == b.chests.size()
	for i in mini(a.chests.size(), b.chests.size()):
		gleich = gleich and a.chests[i]["mimic"] == b.chests[i]["mimic"]
	_check(gleich, "Mimics sind pro Karte fest (gleicher Seed, gleiche Truhen)")


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
