extends SceneTree
## Headless-Selbsttest für Baukasten 2.0, Phase 2 — Schwächen/Resistenzen,
## Erstschlag/Hinterhalt, Anschleichen, Überlegenheit:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/entdeckung_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_schwaechen_daten()
	_test_schwaeche_im_kampf()
	_test_element_schicht()
	_test_wissen_speichern()
	_test_ueberraschungsrunde()
	_test_anschleichen_und_ruecken()
	_test_xp_formel()
	_test_initiative()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Entdeckungs-Tests bestanden")
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


func _gegner(archetyp: StringName, element := Enums.Element.NONE) -> Combatant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return EnemyFactory.build(EnemyLibrary.get_archetype(archetyp), 1, rng, [], -1, element, false)


func _test_schwaechen_daten() -> void:
	print("Schwächen-Tabelle:")
	var fehlend: Array[String] = []
	var falsch: Array[String] = []
	for id in EnemyLibrary.SCHWAECHEN:
		var archetyp := EnemyLibrary.get_archetype(id)
		if archetyp == null:
			fehlend.append(String(id))
			continue
		for element in EnemyLibrary.SCHWAECHEN[id]:
			var faktor: float = EnemyLibrary.SCHWAECHEN[id][element]
			if faktor != 0.5 and faktor != 1.5:
				falsch.append("%s: Faktor %s" % [id, faktor])
			if archetyp.undead and element == Enums.Element.HOLY and faktor > 1.0:
				falsch.append("%s: untot UND heilig-schwach (doppelt)" % id)
	_check(fehlend.is_empty(), "jeder Eintrag gehört zu einem Grundtyp %s" % [fehlend])
	_check(falsch.is_empty(), "nur ×0.5/×1.5, Untote nicht doppelt heilig-schwach %s" % [falsch])
	var ohne: Array[String] = []
	for archetyp in EnemyLibrary.all_archetypes():
		if archetyp.element_faktoren.is_empty():
			ohne.append(String(archetyp.id))
	_check(ohne.is_empty(), "jeder Grundtyp hat mindestens eine Element-Eigenheit %s" % [ohne])
	var wolf := _gegner(&"wolf")
	_check(wolf.element_faktor(Enums.Element.FIRE) == 1.5 and wolf.element_faktor(Enums.Element.ICE) == 0.5
		and wolf.element_faktor(Enums.Element.HOLY) == 1.0, "Wolf: Feuer ×1.5, Eis ×0.5, Rest ×1")


func _test_schwaeche_im_kampf() -> void:
	print("Schwäche im Kampf:")
	var zauberer := Combatant.create("Eismagier", _stats(10), true)
	zauberer.innate_spell_damage = 20
	var neutral := Combatant.create("Neutral", _stats(30), false)
	var anfaellig := Combatant.create("Anfällig", _stats(30), false)
	anfaellig.element_faktoren = {Enums.Element.ICE: 1.5}
	var zaeh := Combatant.create("Zäh", _stats(30), false)
	zaeh.element_faktoren = {Enums.Element.ICE: 0.5}
	var eis := Skill.new()
	eis.blocks = [BlockLibrary.get_block(&"src_spell"), BlockLibrary.get_block(&"elem_ice")]
	var schaden := {}
	var meldungen: Array = []
	for ziel in [neutral, anfaellig, zaeh]:
		var battle := Battle.new()
		battle.crit_enabled = false
		battle.rng.seed = 3
		battle.start([zauberer] as Array[Combatant], [ziel] as Array[Combatant])
		zauberer.mp = 999
		battle.element_reaktion.connect(func(t: Combatant, e: Enums.Element, f: float) -> void:
			meldungen.append([t.display_name, e, f]))
		var vorher: int = ziel.hp
		battle.use_skill(zauberer, eis, ziel)
		schaden[ziel.display_name] = vorher - ziel.hp
	var n: int = schaden["Neutral"]
	_check(absf(schaden["Anfällig"] - n * 1.5) <= 1.0, "schwach: ×1.5 (%d statt %d)" % [schaden["Anfällig"], n])
	_check(absf(schaden["Zäh"] - n * 0.5) <= 1.0, "resistent: ×0.5 (%d statt %d)" % [schaden["Zäh"], n])
	_check(meldungen.size() == 2 and meldungen[0][2] == 1.5 and meldungen[1][2] == 0.5,
		"Signal element_reaktion nur bei Schwäche/Resistenz (%d×)" % meldungen.size())


func _test_element_schicht() -> void:
	print("Element-Schicht:")
	var feuerwolf := _gegner(&"wolf", Enums.Element.FIRE)
	_check(feuerwolf.element_faktor(Enums.Element.FIRE) == 0.5, "Feuer-Wolf widersteht Feuer (statt schwach)")
	_check(feuerwolf.element_faktor(Enums.Element.ICE) == 1.5, "Feuer-Wolf ist eisschwach (Gegenteil)")
	var dunkelskelett := _gegner(&"skelett", Enums.Element.DARK)
	_check(dunkelskelett.element_faktor(Enums.Element.HOLY) == 1.0,
		"Untote bekommen keine zweite Heilig-Schwäche (×1.5 ist schon eingebaut)")
	_check(feuerwolf.wissens_schluessel() != _gegner(&"wolf").wissens_schluessel(),
		"Feuer-Wolf und Wolf haben getrenntes Element-Wissen")


func _test_wissen_speichern() -> void:
	print("Element-Wissen:")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.entdecke_element("wolf", Enums.Element.FIRE), "erste Entdeckung ist neu")
	_check(not state.entdecke_element("wolf", Enums.Element.FIRE), "zweites Mal nicht mehr neu")
	_check(state.kennt_element("wolf", Enums.Element.FIRE) and not state.kennt_element("wolf", Enums.Element.ICE),
		"kennt nur, was entdeckt wurde")
	var daten: Dictionary = JSON.parse_string(JSON.stringify(state.to_save_dict()))
	var geladen: Node = load("res://autoload/game_state.gd").new()
	geladen.apply_save_dict(daten)
	_check(geladen.kennt_element("wolf", Enums.Element.FIRE), "Wissen übersteht Speichern/Laden (JSON)")
	state.free()
	geladen.free()


func _runde_1(ueberraschung: int) -> Array:
	var held_a := Combatant.create("Held A", _stats(5), true)
	var held_b := Combatant.create("Held B", _stats(5), true)
	var flink := Combatant.create("Flinker Gegner", _stats(30), false)
	var battle := Battle.new()
	battle.start([held_a, held_b] as Array[Combatant], [flink] as Array[Combatant])
	battle.ueberraschung = ueberraschung
	var seiten := []
	var actor := battle.next_turn()
	seiten.append(actor.is_player)
	while not battle.round_pending():
		actor = battle.next_turn()
		seiten.append(actor.is_player)
	var runde_2: Array = []
	for i in 3:
		runde_2.append(battle.next_turn().is_player)
	return [seiten, runde_2]


func _test_ueberraschungsrunde() -> void:
	print("Erstschlag & Hinterhalt:")
	var erst := _runde_1(Battle.ERSTSCHLAG)
	_check(erst[0] == [true, true], "Erstschlag: in Runde 1 handeln nur die Helden %s" % [erst[0]])
	_check(false in erst[1] and true in erst[1], "Runde 2: wieder alle")
	var hinter := _runde_1(Battle.HINTERHALT)
	_check(hinter[0] == [false], "Hinterhalt: in Runde 1 handeln nur die Gegner %s" % [hinter[0]])
	var normal := _runde_1(Battle.KEINE_UEBERRASCHUNG)
	_check(normal[0].size() == 3, "ohne Überraschung: alle in Runde 1")


func _test_anschleichen_und_ruecken() -> void:
	print("Anschleichen & Rücken (Dungeon):")
	var spieler := Vector2(100, 100)
	var weg := {"pos": Vector2(130, 100), "kurs": Vector2(1, 0), "jagd": false}
	_check(Anschleichen.ueberraschung(spieler, Vector2(0, 1), weg) == Battle.ERSTSCHLAG,
		"Gegner schaut weg » Erstschlag")
	var hin := {"pos": Vector2(130, 100), "kurs": Vector2(-1, 0), "jagd": false}
	_check(Anschleichen.ueberraschung(spieler, Vector2(0, 1), hin) == Battle.KEINE_UEBERRASCHUNG,
		"Gegner schaut her » normaler Kampf")
	var verfolger := {"pos": Vector2(70, 100), "kurs": Vector2(1, 0), "jagd": true}
	_check(Anschleichen.ueberraschung(spieler, Vector2(1, 0), verfolger) == Battle.HINTERHALT,
		"Verfolger erwischt den Fliehenden von hinten » Hinterhalt")
	_check(Anschleichen.ueberraschung(spieler, Vector2(-1, 0), verfolger) == Battle.KEINE_UEBERRASCHUNG,
		"wer sich dem Verfolger stellt, wird nicht überrascht")
	_check(Anschleichen.bemerkt(spieler, {"kurs": Vector2(-1, 0)}, Vector2(200, 100), 100.0),
		"Gegner rechts, schaut nach links zum Spieler » gesehen")
	_check(Anschleichen.bemerkt(spieler, {"kurs": Vector2(1, 0)}, Vector2(0, 100), 100.0),
		"Gegner links, schaut nach rechts zum Spieler » gesehen")
	_check(not Anschleichen.bemerkt(spieler, {"kurs": Vector2(-1, 0)}, Vector2(0, 100), 100.0),
		"von hinten (weit) bleibt man unbemerkt")
	_check(Anschleichen.bemerkt(spieler, {"kurs": Vector2(-1, 0)}, Vector2(130, 100), 30.0),
		"ganz nah hört er dich")

## Anteil der Würfe, in denen `schnell` vor `langsam` handelt.
func _vorne_anteil(agi_schnell: int, agi_langsam: int) -> float:
	var stats_a := _stats(5)
	stats_a.agility = agi_schnell
	var stats_b := _stats(5)
	stats_b.agility = agi_langsam
	var schnell := Combatant.create("Schnell", stats_a, true)
	var langsam := Combatant.create("Langsam", stats_b, false)
	var battle := Battle.new()
	battle.rng.seed = 11
	var vorne := 0
	for i in 2000:
		battle._initiative_wurf.clear()
		if battle.initiative(schnell) > battle.initiative(langsam):
			vorne += 1
	return vorne / 2000.0


func _test_initiative() -> void:
	print("Zugreihenfolge mit Würfel:")
	var knapp := _vorne_anteil(11, 10)
	_check(knapp > 0.6 and knapp < 0.85, "knapp schneller (11 vs 10): meistens zuerst (%d %%)" % roundi(knapp * 100))
	var deutlich := _vorne_anteil(20, 10)
	_check(deutlich == 1.0, "doppelt so schnell: immer zuerst")
	var gleich := _vorne_anteil(10, 10)
	_check(gleich > 0.4 and gleich < 0.6, "gleich schnell: Münzwurf (%d %%)" % roundi(gleich * 100))
	# Vorschau = echte Reihenfolge: die Zugleiste würfelt nicht neu.
	var a := Combatant.create("A", _stats(10), true)
	var b := Combatant.create("B", _stats(10), false)
	var battle := Battle.new()
	battle.rng.seed = 5
	battle.start([a] as Array[Combatant], [b] as Array[Combatant])
	var vorschau := battle.upcoming_turns(2)
	var erster := battle.next_turn()
	_check(erster == vorschau[0], "Zugleiste zeigt vorab die gewürfelte Reihenfolge")


func _test_xp_formel() -> void:
	print("XP-Formel (gemeinsam für Kampf und Sofortsieg):")
	var foe := Combatant.create("Probe", _stats(5), false)
	foe.level = 5
	var xp := LootGenerator.xp_fuer([foe] as Array[Combatant], false, [])
	# Normale Gegner: × Dichte-Ausgleich (weniger Gegner pro Ebene), Bosse nicht.
	var grund := 8 + 5 * 4 + 25 / 20.0
	_check(xp == roundi(grund * DungeonGenerator.beute_faktor(5)), "Level 5: %d XP (mit Dichte-Ausgleich)" % xp)
	_check(LootGenerator.xp_fuer([foe] as Array[Combatant], true, [&"uralt"]) == roundi(roundi(grund) * 3 * 1.25),
		"Boss ×3, uralt ×1.25 (ohne Dichte-Ausgleich)")
	var gruppe := [foe] as Array[Combatant]
	_check(LootGenerator.xp_anteil(gruppe, false, [], 5, 4) == roundi(xp / 4.0),
		"XP wird geteilt: 4 Helden bekommen je ein Viertel")
	_check(LootGenerator.xp_anteil(gruppe, false, [], 5, 1) == xp,
		"allein (Rest auf der Bank): die ganze XP")
	_check(LootGenerator.xp_fuer(gruppe, false, [], 15) < xp and LootGenerator.xp_fuer(gruppe, false, [], 15) > 0,
		"10 Level über dem Gegner: deutlich weniger XP (%d)" % LootGenerator.xp_fuer(gruppe, false, [], 15))
	_check(LootGenerator.xp_fuer(gruppe, false, [], 1) > xp,
		"stärkere Gegner geben mehr XP (%d)" % LootGenerator.xp_fuer(gruppe, false, [], 1))
	# Nachzügler-Bonus: der niedrigste Held bekommt die Hälfte.
	var helden: Array[Combatant] = []
	for lv in [20, 20, 20, 8]:
		var h := Combatant.create("H%d" % helden.size(), _stats(5), true)
		h.level = lv
		helden.append(h)
	var verteilung := LootGenerator.xp_verteilung(helden)
	_check(is_equal_approx(verteilung[helden[3]], 0.5) and is_equal_approx(verteilung[helden[0]], 0.5 / 3),
		"Nachzügler (Lv 8) bekommt 50 %%, die drei anderen je %.0f %%" % (100.0 * verteilung[helden[0]]))
	for h in helden:
		h.level = 20
	verteilung = LootGenerator.xp_verteilung(helden)
	_check(is_equal_approx(verteilung[helden[3]], 0.25), "gleiches Level: gleich geteilt")
	helden[2].level = 10
	helden[3].level = 10
	verteilung = LootGenerator.xp_verteilung(helden)
	_check(is_equal_approx(verteilung[helden[2]], 0.25) and is_equal_approx(verteilung[helden[0]], 0.25),
		"zwei gleich niedrige teilen sich die Hälfte")
	var summe := 0.0
	for h in verteilung:
		summe += verteilung[h]
	_check(is_equal_approx(summe, 1.0), "keine XP geht verloren oder entsteht")
	_check(is_equal_approx(LootGenerator.xp_level_faktor(100, 10), LootGenerator.XP_UNTER_MIN)
		and is_equal_approx(LootGenerator.xp_level_faktor(1, 100), LootGenerator.XP_UEBER_MAX),
		"Level-Faktor gedeckelt (min %d %%, max %d %%)" % [roundi(LootGenerator.XP_UNTER_MIN * 100),
		roundi(LootGenerator.XP_UEBER_MAX * 100)])
