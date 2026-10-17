extends SceneTree
## Headless-Selbsttest für die Gegner-Eigenheiten (Eigenheiten.gd):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/eigenheiten_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_zuordnung()
	_test_schaden_regeln()
	_test_tod_regeln()
	_test_zugbeginn_regeln()
	_test_dieb()
	_test_entdeckung()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Eigenheiten-Tests bestanden")
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


func _stats(wert: int) -> StatBlock:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, wert)
	return stats


func _gegner(archetyp: StringName, stufe := 5) -> Combatant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return EnemyFactory.build(EnemyLibrary.get_archetype(archetyp), stufe, rng, [], -1, Enums.Element.NONE, false)


func _held(name := "Held") -> Combatant:
	var held := Combatant.create(name, _stats(20), true)
	held.max_hp = 100000
	held.hp = held.max_hp
	return held


func _kampf(helden: Array[Combatant], gegner: Array[Combatant]) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 3
	battle.start(helden, gegner)
	return battle


func _test_zuordnung() -> void:
	print("Zuordnung:")
	var ohne: Array[String] = []
	for archetyp in EnemyLibrary.all_archetypes():
		if not archetyp.boss_only and Eigenheiten.fuer(archetyp.id) == &"":
			ohne.append(String(archetyp.id))
	_check(ohne.is_empty(), "jeder normale Grundtyp hat eine Eigenheit %s" % [ohne])
	var ohne_text: Array[String] = []
	for id in Eigenheiten.ZUORDNUNG.values():
		if Eigenheiten.name_von(id).is_empty() or Eigenheiten.text_von(id).is_empty():
			ohne_text.append(String(id))
	_check(ohne_text.is_empty(), "jede Eigenheit hat Name und Text %s" % [ohne_text])
	_check(_gegner(&"wolf").eigenheit == &"rudel", "gebauter Wolf trägt „Rudel“")


func _test_schaden_regeln() -> void:
	print("Schaden:")
	# Körperlos: Waffe halb, Zauber voll.
	var held := _held()
	var geist := _gegner(&"geist")
	var normal := _gegner(&"geist")
	normal.eigenheit = &""
	var b := _kampf([held] as Array[Combatant], [geist, normal] as Array[Combatant])
	var mit := b._deal_damage(held, geist, 200.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	var ohne := b._deal_damage(held, normal, 200.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	_check(mit > 0 and absi(mit * 2 - ohne) <= 2, "Körperlos: Waffentreffer halb (%d vs %d)" % [mit, ohne])
	var zauber_mit := b._deal_damage(held, geist, 200.0, Enums.DamageAxis.MAGICAL)
	var zauber_ohne := b._deal_damage(held, normal, 200.0, Enums.DamageAxis.MAGICAL)
	_check(zauber_mit == zauber_ohne, "Körperlos: Zauber voll (%d = %d)" % [zauber_mit, zauber_ohne])

	# Rudel: +15 % je weiterem Wolf.
	var w1 := _gegner(&"wolf")
	var w2 := _gegner(&"wolf")
	var w3 := _gegner(&"wolf")
	var ziel := _held("Ziel")
	b = _kampf([ziel] as Array[Combatant], [w1, w2, w3] as Array[Combatant])
	var rudel := b._deal_damage(w1, ziel, 100.0, Enums.DamageAxis.ELEMENTAL)
	w2.hp = 0
	w3.hp = 0
	var allein := b._deal_damage(w1, ziel, 100.0, Enums.DamageAxis.ELEMENTAL)
	_check(rudel > allein and absf(float(rudel) / allein - 1.3) < 0.05,
		"Rudel: zwei weitere Wölfe = +30 %% (%d vs %d)" % [rudel, allein])

	# Feuerseele: Feuer heilt.
	var daemon := _gegner(&"kleindaemon")
	daemon.hp = daemon.max_hp / 2
	var vorher := daemon.hp
	b = _kampf([_held()] as Array[Combatant], [daemon] as Array[Combatant])
	b._apply_elemental_hit(b.players[0], daemon, 50.0, BlockLibrary.element_block(Enums.Element.FIRE))
	_check(daemon.hp > vorher and not daemon.has_status(Enums.Status.BURN), "Feuerseele: Feuer heilt, kein Brand")

	# Neun Leben: einmal mit 1 HP.
	var katze := _gegner(&"verfluchtkatz")
	b = _kampf([_held()] as Array[Combatant], [katze, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(b.players[0], katze, 999999.0, Enums.DamageAxis.MAGICAL)
	_check(katze.hp == 1, "Neun Leben: tödlicher Treffer lässt 1 HP")
	b._deal_damage(b.players[0], katze, 999999.0, Enums.DamageAxis.MAGICAL)
	_check(not katze.is_alive(), "Neun Leben: nur einmal")

	# Stachelpanzer: Nahkampf bekommt Rückschaden.
	var igel := _gegner(&"verfluchtigel")
	var kaempfer := _held("Kämpfer")
	b = _kampf([kaempfer] as Array[Combatant], [igel] as Array[Combatant])
	var hp_vorher := kaempfer.hp
	b._deal_damage(kaempfer, igel, 100.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	_check(kaempfer.hp < hp_vorher, "Stachelpanzer: Nahkämpfer nimmt Rückschaden")

	# Netz: Treffer verlangsamt.
	var spinne := _gegner(&"spinne")
	var opfer := _held("Opfer")
	b = _kampf([opfer] as Array[Combatant], [spinne] as Array[Combatant])
	b._deal_damage(spinne, opfer, 50.0, Enums.DamageAxis.MAGICAL)
	_check(opfer.has_status(Enums.Status.SLOW), "Netz: Treffer verlangsamt")

	# Teilung: Flächentreffer spaltet einmal ab.
	var schleim := _gegner(&"schleim")
	schleim.max_hp = 100000
	schleim.hp = schleim.max_hp
	b = _kampf([_held()] as Array[Combatant], [schleim] as Array[Combatant])
	b._kontext = {"flaeche": true}
	b._deal_damage(b.players[0], schleim, 50.0, Enums.DamageAxis.MAGICAL)
	b._deal_damage(b.players[0], schleim, 50.0, Enums.DamageAxis.MAGICAL)
	_check(b.enemies.size() == 2, "Teilung: ein Flächentreffer spaltet genau einmal ab (%d Gegner)" % b.enemies.size())


func _test_tod_regeln() -> void:
	print("Tod:")
	# Wiederkehr: steht auf — außer Heilig/Stumpf.
	var skelett := _gegner(&"skelett")
	var b := _kampf([_held()] as Array[Combatant], [skelett, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(b.players[0], skelett, 999999.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	b._check_battle_end()
	_check(skelett.is_alive() and skelett.hp == roundi(skelett.max_hp * Eigenheiten.WIEDERKEHR_HP),
		"Wiederkehr: Skelett steht nach Schnitt-Treffer wieder auf")
	b._deal_damage(b.players[0], skelett, 999999.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	b._check_battle_end()
	_check(not skelett.is_alive(), "Wiederkehr: nur einmal")
	var skelett2 := _gegner(&"skelett")
	b = _kampf([_held()] as Array[Combatant], [skelett2, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(b.players[0], skelett2, 999999.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.BLUNT])
	b._check_battle_end()
	_check(not skelett2.is_alive(), "Wiederkehr: stumpfer Treffer verhindert das Aufstehen")

	# Zerfall + Leichenschmaus + Sporenwolke + Opfer.
	var stapel := _gegner(&"schleimstapel")
	var fresser := _gegner(&"leichenfresser")
	fresser.hp = fresser.max_hp / 2
	var hexe := _gegner(&"pilzhexe")
	var held := _held()
	b = _kampf([held] as Array[Combatant], [stapel, fresser, hexe] as Array[Combatant])
	var fresser_hp := fresser.hp
	stapel.hp = 0
	b._check_battle_end()
	_check(b.enemies.size() == 4, "Zerfall: Schleimstapel hinterlässt einen Schleim")
	_check(fresser.hp > fresser_hp, "Leichenschmaus: Fresser heilt bei einem Tod")
	hexe.hp = 0
	b._check_battle_end()
	_check(held.has_status(Enums.Status.POISON_DOT), "Sporenwolke: Pilzhexe vergiftet die Helden beim Tod")
	var kultist := _gegner(&"kultist")
	var wolf := _gegner(&"wolf")
	b = _kampf([_held()] as Array[Combatant], [kultist, wolf] as Array[Combatant])
	kultist.hp = 0
	b._check_battle_end()
	_check(wolf.has_status(Enums.Status.ATK_UP), "Opferbereit: fallender Kultist stärkt einen anderen Gegner")

	# Totenruf: Nekromant erweckt einmal.
	var nekro := _gegner(&"nekromant")
	var diener := _gegner(&"wolf")
	b = _kampf([_held()] as Array[Combatant], [nekro, diener] as Array[Combatant])
	diener.hp = 0
	b._check_battle_end()
	_check(b._eigenheit_zug(nekro) and diener.is_alive(), "Totenruf: Nekromant erweckt einen Gefallenen")
	diener.hp = 0
	b._check_battle_end()
	_check(not b._eigenheit_zug(nekro), "Totenruf: nur einmal")


func _test_zugbeginn_regeln() -> void:
	print("Zugbeginn:")
	var troll := _gegner(&"troll")
	troll.hp = troll.max_hp / 2
	var b := _kampf([_held()] as Array[Combatant], [troll] as Array[Combatant])
	var vorher := troll.hp
	b._process_turn_start(troll)
	_check(troll.hp > vorher, "Regeneration: Troll heilt zu Zugbeginn")
	troll.add_status(Enums.Status.BURN, -1, 1)
	vorher = troll.hp
	b._process_turn_start(troll)
	_check(troll.hp <= vorher, "Regeneration: Brand stoppt sie")

	var golem := _gegner(&"golem")
	b = _kampf([_held()] as Array[Combatant], [golem] as Array[Combatant])
	b._apply_elemental_hit(b.players[0], golem, 50.0, BlockLibrary.element_block(Enums.Element.POISON))
	golem.add_status(Enums.Status.BLEED, -1, 5)
	vorher = golem.hp
	b._process_turn_start(golem)
	_check(not golem.has_status(Enums.Status.POISON_DOT) and not golem.has_status(Enums.Status.BLEED)
		and golem.hp == vorher, "Gesteinskörper: kein Gift, keine Blutung")

	var dachs := _gegner(&"verfluchtdachs")
	b = _kampf([_held()] as Array[Combatant], [dachs] as Array[Combatant])
	dachs.add_status(Enums.Status.WEAKEN, 9, 20)
	b._process_turn_start(dachs)
	var nach_erstem := dachs.has_status(Enums.Status.WEAKEN)
	b._process_turn_start(dachs)
	_check(nach_erstem and not dachs.has_status(Enums.Status.WEAKEN), "Dickfellig: jeden 2. Zug Schwächungen weg")


func _test_dieb() -> void:
	print("Taschendieb:")
	var bandit := _gegner(&"bandit")
	var held := _held()
	var b := _kampf([held] as Array[Combatant], [bandit, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(bandit, held, 20.0, Enums.DamageAxis.MAGICAL)
	_check(b.gestohlenes_gold(1000) == 30, "erster Treffer stiehlt 3 %% (%d von 1000)" % b.gestohlenes_gold(1000))
	_check(b.gestohlenes_gold(1000000) == Eigenheiten.DIEB_MAX_JE_STUFE * bandit.level, "höchstens 25 × Stufe")
	bandit.hp = 0
	b._check_battle_end()
	_check(b.gestohlenes_gold(1000) == 0, "besiegter Dieb gibt das Gold zurück")


func _test_entdeckung() -> void:
	print("Entdeckung:")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.entdecke_eigenheit("wolf") and not state.entdecke_eigenheit("wolf"), "erste Entdeckung neu, zweite nicht")
	var gespeichert: Dictionary = state.to_save_dict()
	var neu: Node = load("res://autoload/game_state.gd").new()
	neu.apply_save_dict(gespeichert)
	_check(neu.kennt_eigenheit("wolf") and not neu.kennt_eigenheit("geist"), "Wissen übersteht Speichern/Laden")
	var b := _kampf([_held()] as Array[Combatant], [_gegner(&"geist")] as Array[Combatant])
	var gemeldet: Array = []
	b.eigenheit_ausgeloest.connect(func(g: Combatant, e: StringName) -> void: gemeldet.append(e))
	b._deal_damage(b.players[0], b.enemies[0], 50.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	_check(gemeldet == [&"koerperlos"], "Signal meldet die ausgelöste Eigenheit")
	state.free()
	neu.free()
