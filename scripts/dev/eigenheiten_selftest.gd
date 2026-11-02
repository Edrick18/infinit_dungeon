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
	_test_gestein_sofort()
	_test_entdeckung()
	_test_gegenwege()
	_test_hoehle()
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


## Spieltest 2026-10-22: Blutung stand am Golem bis zu seinem Zugbeginn.
func _test_gestein_sofort() -> void:
	print("Gesteinskörper (sofort):")
	var held := _held()
	held.equip(ItemLibrary.make_item(&"dolch"))
	held.max_mp = 500
	held.mp = 500
	var golem := _gegner(&"golem")
	golem.max_hp = 100000
	golem.hp = golem.max_hp
	var battle := _kampf([held], [golem])
	var skill := Skill.new()
	skill.blocks = [BlockLibrary.get_block(&"src_weapon"), BlockLibrary.get_block(&"tech_blutung")]
	battle.use_skill(held, skill, golem)
	_check(golem.hp < golem.max_hp and not golem.has_status(Enums.Status.BLEED),
		"Blutung haftet am Golem gar nicht erst (Treffer zählt)")


## Gegenwege (Eigenheiten.KONTER, Lutz 2026-11-02): jede Eigenheit hat
## einen sachlich beschriebenen Gegenweg über Schadensart, Waffe oder Element.
func _test_gegenwege() -> void:
	print("Gegenwege:")
	var ohne: Array[String] = []
	var tipp: Array[String] = []
	var arten := {}
	for id in Eigenheiten.TEXTE:
		var k: Array = Eigenheiten.KONTER.get(id, [])
		if k.size() != 3 or String(k[1]).is_empty() or String(k[2]).is_empty():
			ohne.append(String(id))
			continue
		if k[0] != &"" and not Eigenheiten.TREFFER_NAMEN.has(k[0]):
			ohne.append("%s (Art %s)" % [id, k[0]])
		arten[k[0]] = true
		for satz in [Eigenheiten.TEXTE[id][2], Eigenheiten.TEXTE[id][3], k[1], k[2]]:
			var klein := String(satz).to_lower()
			if klein.contains("tipp") or klein.contains("versuche ") or klein.contains(" try ") or klein.contains("tip:"):
				tipp.append(String(id))
	_check(ohne.is_empty(), "jede Eigenheit hat einen Gegenweg (DE+EN) %s" % [ohne])
	_check(tipp.is_empty(), "Gegenwege sachlich, keine Tipps %s" % [tipp])
	_check(arten.size() >= 7, "Gegenwege nutzen viele Treffer-Arten (%d)" % arten.size())
	var konter_de := Eigenheiten.konter_text(&"rudel")
	_check(Eigenheiten.text_von(&"rudel").ends_with(konter_de), "Regeltext nennt den Gegenweg am Ende")

	# Feuer hebt das Rudel auf (Element-Treffer, auch über Brand-Stacks).
	var w1 := _gegner(&"wolf")
	var w2 := _gegner(&"wolf")
	var held := _held()
	var b := _kampf([held] as Array[Combatant], [w1, w2] as Array[Combatant])
	var mit := b._deal_damage(w1, held, 100.0, Enums.DamageAxis.ELEMENTAL)
	b._apply_elemental_hit(held, w1, 10.0, BlockLibrary.element_block(Enums.Element.FIRE))
	var ohne_bonus := b._deal_damage(w1, held, 100.0, Enums.DamageAxis.ELEMENTAL)
	_check(w1.eigenheit == &"" and w1.eigenheit_aufgehoben == &"rudel" and mit > ohne_bonus,
		"Feuer hebt den Rudel-Bonus auf (%d » %d)" % [mit, ohne_bonus])
	_check(w2.eigenheit == &"rudel", "nur der getroffene Wolf verliert die Eigenheit")

	# Stumpf (vorher geprüft): der stumpfe Treffer selbst wirkt schon ohne Neun Leben.
	var katze := _gegner(&"verfluchtkatz")
	b = _kampf([_held()] as Array[Combatant], [katze, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(b.players[0], katze, 999999.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.BLUNT])
	_check(not katze.is_alive(), "stumpfer Treffer: Neun Leben greift nicht mehr")

	# Schnitt zerschlägt den Schildwall; Stich nicht.
	var krieger := _gegner(&"schattenkrieger")
	b = _kampf([_held()] as Array[Combatant], [krieger] as Array[Combatant])
	b._deal_damage(b.players[0], krieger, 10.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.PIERCE])
	_check(krieger.eigenheit == &"schildwall", "Stich lässt den Schildwall stehen")
	b._deal_damage(b.players[0], krieger, 10.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.SLASH])
	_check(krieger.eigenheit == &"" and krieger.eigenheit_aufgehoben == &"schildwall", "Schnitt hebt den Schildwall auf")

	# Fernkampf: der Dieb lässt das Gold fallen und flieht nicht mehr.
	var bandit := _gegner(&"bandit")
	var schuetze := _held("Schütze")
	schuetze.equip(ItemLibrary.make_item(&"bogen"))
	b = _kampf([schuetze] as Array[Combatant], [bandit, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(bandit, schuetze, 20.0, Enums.DamageAxis.MAGICAL)
	var zeilen: Array[String] = []
	b.log_line.connect(func(t: String) -> void: zeilen.append(t))
	b._deal_damage(schuetze, bandit, 5.0, Enums.DamageAxis.PHYSICAL, schuetze.weapon_subtypes())
	_check(b.gestohlenes_gold(1000) == 0 and bandit.eigenheit == &"" and not b._eigenheit_zug(bandit),
		"Fernkampftreffer: Dieb lässt das Gold fallen und flieht nicht")
	_check(zeilen.any(func(t: String) -> bool: return t.contains(Eigenheiten.name_von(&"taschendieb"))),
		"gewirkte Eigenheit: das Aufheben steht im Log %s" % [zeilen])

	# Noch nicht gezeigt: aufheben ja, aber kein Log (Eigenheiten zeigen sich erst nach dem Wirken).
	var spinne := _gegner(&"spinne")
	b = _kampf([_held()] as Array[Combatant], [spinne] as Array[Combatant])
	var still: Array[String] = []
	b.log_line.connect(func(t: String) -> void: still.append(t))
	b._apply_elemental_hit(b.players[0], spinne, 10.0, BlockLibrary.element_block(Enums.Element.FIRE))
	_check(spinne.eigenheit == &"" and not still.any(func(t: String) -> bool: return t.contains(Eigenheiten.name_von(&"netz"))),
		"ungezeigte Eigenheit: still aufgehoben %s" % [still])
	var opfer := _held("Opfer")
	b = _kampf([opfer] as Array[Combatant], [spinne] as Array[Combatant])
	b._deal_damage(spinne, opfer, 50.0, Enums.DamageAxis.MAGICAL)
	_check(not opfer.has_status(Enums.Status.SLOW), "aufgehobenes Netz verlangsamt nicht mehr")

	# Gegner treffen Gegner nicht über den Gegenweg; verbrauchte Einmal-Eigenheiten bleiben.
	var skelett := _gegner(&"skelett")
	skelett.eigenheit_verbraucht = true
	var nekro := _gegner(&"nekromant")
	b = _kampf([_held()] as Array[Combatant], [skelett, nekro] as Array[Combatant])
	b._deal_damage(b.players[0], nekro, 5.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.PIERCE])
	nekro.eigenheit_verbraucht = true
	_check(nekro.eigenheit == &"" and nekro.eigenheit_aufgehoben == &"totenruf", "Stich hebt den Totenruf auf")
	var golem := _gegner(&"golem")
	b = _kampf([_held()] as Array[Combatant], [golem, _gegner(&"wolf")] as Array[Combatant])
	b._deal_damage(b.enemies[1], golem, 5.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.BLUNT])
	_check(golem.eigenheit == &"gesteinskoerper", "nur Helden-Treffer heben Eigenheiten auf")


## Neue Höhlen-Eigenheiten: Seuchenbiss, Kristallpanzer, Häutung.
func _test_hoehle() -> void:
	print("Höhlen-Eigenheiten:")
	var ratte := _gegner(&"grubenratte")
	var held := _held()
	var b := _kampf([held] as Array[Combatant], [ratte] as Array[Combatant])
	b._deal_damage(ratte, held, 20.0, Enums.DamageAxis.MAGICAL)
	var gift: int = held.get_status(Enums.Status.POISON_DOT).get("potency", 0)
	b._deal_damage(ratte, held, 20.0, Enums.DamageAxis.MAGICAL)
	_check(gift == roundi(held.max_hp * Eigenheiten.SEUCHE_PROZENT)
		and int(held.get_status(Enums.Status.POISON_DOT)["potency"]) == gift,
		"Seuchenbiss: erster Treffer vergiftet (2 %%), der zweite nicht mehr (%d)" % gift)

	var kaefer := _gegner(&"kristallkaefer")
	var normal := _gegner(&"kristallkaefer")
	normal.eigenheit = &""
	b = _kampf([_held()] as Array[Combatant], [kaefer, normal] as Array[Combatant])
	var zauber_mit := b._deal_damage(b.players[0], kaefer, 400.0, Enums.DamageAxis.MAGICAL)
	var zauber_ohne := b._deal_damage(b.players[0], normal, 400.0, Enums.DamageAxis.MAGICAL)
	_check(zauber_mit > 0 and absi(zauber_mit * 2 - zauber_ohne) <= 2,
		"Kristallpanzer: Zauber halb (%d vs %d)" % [zauber_mit, zauber_ohne])
	b._deal_damage(b.players[0], kaefer, 5.0, Enums.DamageAxis.PHYSICAL, [Enums.PhysicalSubtype.BLUNT])
	var danach := b._deal_damage(b.players[0], kaefer, 400.0, Enums.DamageAxis.MAGICAL)
	_check(kaefer.eigenheit == &"" and absi(danach - zauber_ohne) <= 2, "stumpfer Treffer zerschlägt den Kristallpanzer")

	var olm := _gegner(&"blindolm")
	b = _kampf([_held()] as Array[Combatant], [olm] as Array[Combatant])
	olm.hp = roundi(olm.max_hp * 0.4)
	olm.add_status(Enums.Status.BURN, -1, 1)
	olm.add_status(Enums.Status.WEAKEN, 3, 20)
	var vorher := olm.hp
	b._process_turn_start(olm)
	_check(olm.hp > vorher and not olm.has_status(Enums.Status.WEAKEN) and not olm.has_status(Enums.Status.BURN),
		"Häutung: unter 50 %% Leiden weg und Heilung (%d » %d)" % [vorher, olm.hp])
	olm.hp = roundi(olm.max_hp * 0.3)
	vorher = olm.hp
	b._process_turn_start(olm)
	_check(olm.hp <= vorher, "Häutung: nur einmal")
	var olm2 := _gegner(&"blindolm")
	b = _kampf([_held()] as Array[Combatant], [olm2] as Array[Combatant])
	b._apply_elemental_hit(b.players[0], olm2, 5.0, BlockLibrary.element_block(Enums.Element.LIGHTNING))
	olm2.hp = roundi(olm2.max_hp * 0.3)
	vorher = olm2.hp
	b._process_turn_start(olm2)
	_check(olm2.eigenheit == &"" and olm2.hp <= vorher, "Blitztreffer hebt die Häutung auf")
