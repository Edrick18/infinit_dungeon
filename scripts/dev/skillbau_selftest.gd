extends SceneTree
## Headless-Selbsttest für Skillbau 3.0 — Grundbausteine (Treffer, Zielwahl,
## Überschlag, Aufladen, Blutpreis, Zeitpunkt, Krit/Schwachstelle, Kombos,
## Effekt-Ziele) und die Waffen-Besonderheiten:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/skillbau_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_treffer_und_ziele()
	_test_ueberschlag()
	_test_aufladen_und_blutpreis()
	_test_zeitpunkt()
	_test_krit_und_schwachstelle()
	_test_kombos()
	_test_effekt_ziele()
	_test_waffen_besonderheiten()
	_test_vollheilung()
	_test_meisterschaft()
	_test_serienschlag()
	_test_buff_stufen()
	_test_neue_effekte()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Skillbau-Tests bestanden")
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


func _held(name := "Held") -> Combatant:
	var held := Combatant.create(name, _stats(10), true)
	held.mp = 999
	return held


func _puppe(name := "Puppe", vit := 60) -> Combatant:
	var stats := _stats(1)
	stats.vitality = vit
	var puppe := Combatant.create(name, stats, false)
	return puppe


func _mod(art: Enums.SkillModifier, staerke := 0, schaden := 1.0, stapel := false) -> ModifierBlock:
	var block := ModifierBlock.new()
	block.modifier = art
	block.magnitude = staerke
	block.schaden_faktor = schaden
	block.stapelbar = stapel
	block.display_name = "Test-%d" % art
	return block


func _effekt(status: Enums.Status, ziel: EffectBlock.Ziel, dauer := 3, potenz := 20) -> EffectBlock:
	var block := EffectBlock.new()
	block.status = status
	block.chance_percent = 100
	block.duration_turns = dauer
	block.potency = potenz
	block.ziel = ziel
	block.display_name = "Effekt-%d" % status
	return block


func _skill(bloecke: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Probe"
	skill.blocks.append(BlockLibrary.get_block(&"src_weapon"))
	for block in bloecke:
		skill.blocks.append(block)
	return skill


func _battle(spieler: Array, gegner: Array, krits := false) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = krits
	battle.rng.seed = 21
	var a: Array[Combatant] = []
	a.assign(spieler)
	var b: Array[Combatant] = []
	b.assign(gegner)
	battle.start(a, b)
	return battle


func _schaden(skill: Skill, held: Combatant = null, krits := false) -> int:
	held = held if held != null else _held()
	var puppe := _puppe()
	var battle := _battle([held], [puppe], krits)
	var vorher := puppe.hp
	battle.use_skill(held, skill, puppe)
	return vorher - puppe.hp


func _test_treffer_und_ziele() -> void:
	print("Zusatztreffer & Zielwahl:")
	var treffer := _mod(Enums.SkillModifier.TREFFER, 0, 1.0, true)
	var einzeln := _schaden(_skill([]))
	var dreifach := _skill([treffer, treffer])
	_check(dreifach.is_valid(), "Zusatztreffer darf mehrfach in einen Skill (stapelbar)")
	_check(dreifach.treffer() == 3 and is_equal_approx(dreifach.schaden_je_treffer(), 1.3 / 3.0),
		"3 Treffer teilen sich 130 %")
	var gesamt := _schaden(dreifach)
	_check(absf(gesamt - einzeln * 1.3) <= 3, "3 Treffer ≈ 130 %% des Einzeltreffers (%d vs %d)" % [gesamt, einzeln])

	var held := _held()
	held.peak_level = 50  # 7 Klötze brauchen 7 Sockel
	var gegner := [_puppe("A"), _puppe("B"), _puppe("C")]
	var battle := _battle([held], gegner)
	var zufall := _skill([_mod(Enums.SkillModifier.ZIEL_ZUFALL, 0, 1.1), treffer, treffer, treffer, treffer, treffer])
	battle.use_skill(held, zufall, gegner[0])
	var getroffen := gegner.filter(func(c: Combatant) -> bool: return c.hp < c.max_hp).size()
	_check(getroffen >= 2, "Zufallsziel verteilt 6 Treffer auf mehrere Gegner (%d)" % getroffen)

	var held2 := _held()
	var zwei := [_puppe("X"), _puppe("Y")]
	var battle2 := _battle([held2], zwei)
	battle2.use_skill(held2, _skill([_mod(Enums.SkillModifier.ZIEL_WECHSEL), treffer]), zwei[0])
	_check(zwei[0].hp < zwei[0].max_hp and zwei[1].hp < zwei[1].max_hp, "Wechselziel: zweiter Treffer geht auf den anderen")

	var held3 := _held()
	var drei := [_puppe("1"), _puppe("2"), _puppe("3")]
	var battle3 := _battle([held3], drei)
	battle3.use_skill(held3, _skill([BlockLibrary.get_block(&"form_aoe")]), drei[0])
	_check(drei.all(func(c: Combatant) -> bool: return c.hp < c.max_hp), "Waffenangriff + Alle Gegner trifft alle")


func _test_ueberschlag() -> void:
	print("Überschlag:")
	var held := _held()
	var schwach := _puppe("Schwach", 0)
	schwach.hp = 3
	var stark := _puppe("Stark")
	var battle := _battle([held], [schwach, stark])
	battle.use_skill(held, _skill([_mod(Enums.SkillModifier.UEBERSCHLAG)]), schwach)
	_check(not schwach.is_alive() and stark.hp < stark.max_hp, "Überschüssiger Schaden trifft den nächsten Gegner")


func _test_aufladen_und_blutpreis() -> void:
	print("Aufladen & Blutpreis:")
	var held := _held()
	var puppe := _puppe()
	var battle := _battle([held], [puppe])
	var normal := _schaden(_skill([]))
	var laden := _skill([_mod(Enums.SkillModifier.AUFLADEN, 0, 2.0)])
	battle.use_skill(held, laden, puppe)
	_check(puppe.hp == puppe.max_hp and battle.hat_aufladung(held), "Aufladen: erst passiert nichts, der Skill ist geladen")
	battle.aufladung_ausloesen(held)
	var entladen := puppe.max_hp - puppe.hp
	_check(absf(entladen - normal * 2) <= 2 and not battle.hat_aufladung(held),
		"im nächsten Zug ×2 (%d vs %d)" % [entladen, normal])

	var blut := _held("Blut")
	var mp_vorher := blut.mp
	var hp_vorher := blut.hp
	var battle2 := _battle([blut], [_puppe()])
	battle2.use_skill(blut, _skill([_mod(Enums.SkillModifier.BLUTPREIS)]), battle2.enemies[0])
	_check(blut.mp == mp_vorher and blut.hp < hp_vorher, "Blutpreis: kostet HP statt MP")


func _test_zeitpunkt() -> void:
	print("Flinkheit & Wucht:")
	var stats_langsam := _stats(10)
	stats_langsam.agility = 1
	var langsam := Combatant.create("Langsam", stats_langsam, true)
	var stats_flink := _stats(10)
	stats_flink.agility = 30
	var flink_gegner := Combatant.create("Flink", stats_flink, false)
	var battle := _battle([langsam], [flink_gegner])
	battle.vorrang[langsam] = 1
	_check(battle.next_turn() == langsam, "Flinkheit: der Langsame handelt zuerst")
	var schnell := Combatant.create("Schnell", stats_flink, true)
	var battle2 := _battle([schnell], [Combatant.create("Lahm", stats_langsam, false)])
	battle2.vorrang[schnell] = -1
	_check(battle2.next_turn() != schnell, "Wucht: der Schnelle handelt als Letzter")


func _test_krit_und_schwachstelle() -> void:
	print("Krit, Schwachstelle, Volltreffer:")
	var normal := _schaden(_skill([]))
	var nichts := _skill([_mod(Enums.SkillModifier.ALLES_ODER_NICHTS)])
	_check(_schaden(nichts) == 0, "Alles oder nichts ohne Krit: verfehlt")
	var sicher := _skill([_mod(Enums.SkillModifier.KRIT_BONUS, 200)])
	_check(absf(_schaden(sicher, null, true) - normal * 1.5) <= 2, "garantierter Krit: ×1,5")
	var aon_krit := _skill([_mod(Enums.SkillModifier.ALLES_ODER_NICHTS), _mod(Enums.SkillModifier.KRIT_BONUS, 200)])
	_check(absf(_schaden(aon_krit, null, true) - normal * 3) <= 2, "Alles oder nichts mit Krit: ×3")
	var voll := _skill([_mod(Enums.SkillModifier.KRIT_BONUS, 200), _mod(Enums.SkillModifier.SCHWACHSTELLE, 200)])
	_check(absf(_schaden(voll, null, true) - normal * 4) <= 3, "Krit + Schwachstelle = VOLLTREFFER ×4")


func _test_kombos() -> void:
	print("Kombo-Klötze:")
	var entzuenden := _skill([_mod(Enums.SkillModifier.ENTZUENDEN, 100)])
	var held := _held()
	var puppe := _puppe()
	var battle := _battle([held], [puppe])
	puppe.add_status(Enums.Status.BURN, -1, 4)
	var vorher := puppe.hp
	battle.use_skill(held, entzuenden, puppe)
	var mit_brand := vorher - puppe.hp
	_check(not puppe.has_status(Enums.Status.BURN), "Entzünden löscht den Brand")
	_check(mit_brand >= _schaden(_skill([])) * 2 - 2, "Entzünden: ×2 gegen brennende Ziele")

	var held_a := _held("A")
	var held_b := _held("B")
	var ziel := _puppe()
	var battle2 := _battle([held_a, held_b], [ziel])
	battle2.basic_attack(held_a, ziel)
	var vorher2 := ziel.hp
	battle2.use_skill(held_b, _skill([_mod(Enums.SkillModifier.NACHSETZEN, 60)]), ziel)
	_check(vorher2 - ziel.hp > _schaden(_skill([])), "Nachsetzen: stärker, wenn ein Verbündeter schon traf")


func _test_effekt_ziele() -> void:
	print("Effekte auf Anwender und Party:")
	var held := _held()
	var freund := _held("Freund")
	var battle := _battle([held, freund], [_puppe()])
	battle.use_skill(held, _skill([_effekt(Enums.Status.ATK_UP, EffectBlock.Ziel.ANWENDER)]), battle.enemies[0])
	_check(held.has_status(Enums.Status.ATK_UP) and not freund.has_status(Enums.Status.ATK_UP)
		and not battle.enemies[0].has_status(Enums.Status.ATK_UP), "Kampfrausch: Waffenangriff stärkt nur den Anwender")
	battle.use_skill(held, _skill([_effekt(Enums.Status.REGEN, EffectBlock.Ziel.PARTY)]), battle.enemies[0])
	_check(held.has_status(Enums.Status.REGEN) and freund.has_status(Enums.Status.REGEN), "Party-Effekt erreicht alle Verbündeten")
	var gift := _effekt(Enums.Status.POISON_DOT, EffectBlock.Ziel.ZIEL, -1, 50)
	var puppe := battle.enemies[0]
	battle.use_skill(held, _skill([gift]), puppe)
	_check(puppe.has_status(Enums.Status.POISON_DOT), "Giftklinge: Gift-Stacks aus dem Trefferschaden")


func _test_waffen_besonderheiten() -> void:
	print("Waffen-Besonderheiten:")
	# Dolch: doppelte Treffer zu je 60 %.
	var dolch := HeroLibrary.create_hero("Dolch", &"dolche")
	var treffer_zahl := [0]
	var puppe := _puppe()
	var battle := _battle([dolch], [puppe])
	battle.effekt.connect(func(d: Dictionary) -> void:
		if d["art"] == &"waffe":
			treffer_zahl[0] += 1)
	battle.basic_attack(dolch, puppe)
	_check(treffer_zahl[0] == 2, "Zwillingsklinge: ein Angriff, zwei Treffer")

	# Axt: doppelter Schaden, danach erschöpft (nächster Zug fällt aus).
	var axt := HeroLibrary.create_hero("Axt", &"axt")
	var schwert := HeroLibrary.create_hero("Schwert", &"schwert_schild")
	var p1 := _puppe()
	var p2 := _puppe()
	var b1 := _battle([axt], [p1])
	var b2 := _battle([schwert], [p2])
	b1.basic_attack(axt, p1)
	b2.basic_attack(schwert, p2)
	_check(p1.max_hp - p1.hp > (p2.max_hp - p2.hp) * 1.6, "Wucht: Axt trifft rund doppelt so hart")
	_check(axt.has_status(Enums.Status.EXHAUSTED), "danach erschöpft")
	var zug := b1.next_turn()
	_check(zug != axt or not axt.has_status(Enums.Status.EXHAUSTED), "erschöpfter Zug fällt aus")

	# Armbrust: Bolzen trifft dahinter noch einen Gegner.
	var armbrust := _held("Armbrust")
	armbrust.equip(ItemLibrary.make_item(&"armbrust"))
	var vorne := _puppe("Vorne")
	var hinten := _puppe("Hinten")
	var b3 := _battle([armbrust], [vorne, hinten])
	b3.basic_attack(armbrust, vorne)
	_check(hinten.hp < hinten.max_hp, "Durchschlag: der Bolzen trifft einen zweiten Gegner")

	# Schwert: Parade (≈20 %).
	var ritter := HeroLibrary.create_hero("Ritter", &"schwert_schild")
	var angreifer := _puppe("Angreifer")
	var b4 := _battle([ritter], [angreifer])
	var pariert := 0
	for i in 600:
		ritter.hp = ritter.max_hp
		if b4._deal_damage(angreifer, ritter, 30.0, Enums.DamageAxis.PHYSICAL) == 0:
			pariert += 1
	_check(pariert > 70 and pariert < 170, "Parade: rund 20 %% der Nahkampftreffer abgewehrt (%d/600)" % pariert)

	# Bogen: Schwachstellen (15 % + Glück) — mit Krits auch Volltreffer.
	var bogen := HeroLibrary.create_hero("Bogen", &"bogen")
	_check(bogen.schwachstellen_chance() >= 15 and _held().schwachstellen_chance() == 0,
		"Schwachstellen-Chance nur mit Bogen (%d %%)" % bogen.schwachstellen_chance())

	# Offensivstab: Element-Signatur +50 % (mehr Brand-Stacks).
	var feuer := Skill.new()
	feuer.blocks = [BlockLibrary.get_block(&"src_spell"), BlockLibrary.get_block(&"elem_fire")]
	var magier := HeroLibrary.create_hero("Magier", &"feuerstab")
	var laie := _held("Laie")
	laie.equip(ItemLibrary.make_item(&"heiligstab"))
	var z1 := _puppe()
	var z2 := _puppe()
	var b5 := _battle([magier], [z1])
	var b6 := _battle([laie], [z2])
	magier.mp = 999
	laie.mp = 999
	b5.use_skill(magier, feuer, z1)
	b6.use_skill(laie, feuer, z2)
	var stacks_stab: int = z1.get_status(Enums.Status.BURN).get("potency", 0)
	var stacks_ohne: int = z2.get_status(Enums.Status.BURN).get("potency", 0)
	_check(stacks_stab > stacks_ohne, "Elementarmeister: mehr Brand-Stacks mit Offensivstab (%d vs %d)" % [stacks_stab, stacks_ohne])


## Heiler mit genug Sockeln für 4 Klötze (Level 8+).
func _heiler(name: String) -> Combatant:
	var held := _held(name)
	held.peak_level = 30
	return held


func _vollheil_skill() -> Skill:
	var skill := Skill.new()
	skill.display_name = "Vollheilung"
	for id in [&"src_spell", &"elem_holy", &"form_ally", &"mod_vollheilung"]:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _test_vollheilung() -> void:
	print("Vollheilung (MP nach Bedarf):")
	var skill := _vollheil_skill()
	_check(skill.is_valid(), "Heilig + Verbündeter + Vollheilung ist gültig")
	var ohne_heilig := Skill.new()
	for id in [&"src_spell", &"form_ally", &"mod_vollheilung"]:
		ohne_heilig.blocks.append(BlockLibrary.get_block(id))
	_check(not ohne_heilig.is_valid(), "ohne Heilig ungültig")
	var mit_blutpreis := _vollheil_skill()
	mit_blutpreis.blocks.append(BlockLibrary.get_block(&"mod_blutpreis"))
	_check(not mit_blutpreis.is_valid(), "verträgt keinen zweiten Kosten-Klotz (Blutpreis)")

	# Genug Mana: Ziel ganz voll, bezahlt wird nur der Bedarf.
	var heiler := _heiler("Heiler")
	var tank := Combatant.create("Tank", _stats(60), true)
	var battle := _battle([heiler, tank], [_puppe()])
	tank.hp = roundi(tank.max_hp * 0.1)
	heiler.mp = 99999
	_check(battle.use_skill(heiler, skill, tank) and tank.hp == tank.max_hp, "genug MP: heilt bis voll")
	var bezahlt := 99999 - heiler.mp
	var erwartet := ceili((tank.max_hp - roundi(tank.max_hp * 0.1))
		/ (battle.normale_heilung(heiler, skill) / skill.get_mp_cost(heiler)))
	_check(absi(bezahlt - erwartet) <= 1 and bezahlt < 99999,
		"kostet nur den Bedarf (%d MP, erwartet %d)" % [bezahlt, erwartet])

	# Zu wenig Mana: alle MP weg, anteilig geheilt.
	var arm := _heiler("Armer Heiler")
	var tank2 := Combatant.create("Tank", _stats(60), true)
	var battle2 := _battle([arm, tank2], [_puppe()])
	tank2.hp = 1
	var fehlt := tank2.max_hp - 1
	var noetig := ceili(fehlt / (battle2.normale_heilung(arm, skill) / skill.get_mp_cost(arm)))
	arm.mp = maxi(1, noetig / 4)
	var mp_vorher := arm.mp
	battle2.use_skill(arm, skill, tank2)
	var geheilt := tank2.hp - 1
	_check(arm.mp == 0, "zu wenig MP: alle MP verbraucht")
	_check(absf(float(geheilt) / fehlt - float(mp_vorher) / noetig) < 0.05 and geheilt < fehlt,
		"heilt anteilig so viel wie möglich (%d von %d HP)" % [geheilt, fehlt])

	# Heil-Boni zählen: mit Heiligstab (+50 %% Heilung) kostet dieselbe Vollheilung weniger.
	var stab := _heiler("Stabträger")
	stab.equip(ItemLibrary.make_item(&"heiligstab", 1))
	var ohne_stab := _heiler("Ohne Stab")
	var kosten := []
	for h in [ohne_stab, stab]:
		var t := Combatant.create("Tank", _stats(60), true)
		var b := _battle([h, t], [_puppe()])
		t.hp = 1
		h.mp = 99999
		b.use_skill(h, skill, t)
		kosten.append(99999 - h.mp)
	_check(kosten[1] < kosten[0], "Heil-Boni zählen: mit Heiligstab billiger (%d < %d MP)" % [kosten[1], kosten[0]])

	# Niemand verwundet: kein Wirken, keine Kosten.
	var voll := _heiler("Ruhig")
	var gesund := Combatant.create("Gesund", _stats(60), true)
	var battle3 := _battle([voll, gesund], [_puppe()])
	var mp := voll.mp
	_check(not battle3.use_skill(voll, skill, gesund) and voll.mp == mp,
		"niemand verwundet: nichts passiert, keine MP weg")


func _test_meisterschaft() -> void:
	print("Skillpunkte & Meisterschaften:")
	_check(Combatant.skill_punkte_bis(100) == 200, "bis Level 100 genau 200 Punkte = zwei volle Bäume")
	_check(Combatant.skill_punkte_bis(50) == 99, "Level 50: 99 Punkte (2 je Level, +1 auf 50)")

	# Falkenauge (Bogen-Meister): Krits ×2,5 — auch mit einem Schwert in der Hand.
	var schuetze := _held("Schütze")
	schuetze.equip(ItemLibrary.make_item(&"schwert", 1))
	schuetze.skill_points = 100
	schuetze.invest_point(&"bogen", 100)
	var ohne := _schaden(_skill([_mod(Enums.SkillModifier.KRIT_BONUS, 200)]), schuetze, true)
	_check(not schuetze.meister(&"bogen"), "freigeschaltet, aber ohne Slot keine Wirkung")
	schuetze.meisterschaft = &"bogen"
	var mit := _schaden(_skill([_mod(Enums.SkillModifier.KRIT_BONUS, 200)]), schuetze, true)
	_check(schuetze.meister(&"bogen") and absf(float(mit) / ohne - 2.5 / 1.5) < 0.1,
		"Falkenauge: Krit ×2,5 statt ×1,5 — mit Schwert (%d » %d)" % [ohne, mit])

	var neuling := _held("Neuling")
	neuling.meisterschaft = &"bogen"
	neuling.skill_points = 99
	neuling.invest_point(&"bogen", 99)
	_check(not neuling.meister(&"bogen"), "unter 100 Punkten wirkt die Rolle nicht")

	var geladen := Combatant.from_dict(schuetze.to_dict())
	_check(geladen.meisterschaft == &"bogen" and geladen.meister(&"bogen"), "Meisterschaft übersteht den Speicher-Rundweg")

	# Heiliger: Heilung ×1,5 auch ohne Heiligstab.
	var heiler := _held("Heiler")
	heiler.skill_points = 100
	heiler.invest_point(&"heiligstab", 100)
	var f_ohne := heiler.heil_faktor()
	heiler.meisterschaft = &"heiligstab"
	_check(is_equal_approx(heiler.heil_faktor(), f_ohne * 1.5), "Heiliger: Heilung ×1,5 mit jeder Waffe")


func _test_serienschlag() -> void:
	print("Serienschlag (Dolch):")
	var dieb := _held("Dieb")
	dieb.equip(ItemLibrary.make_item(&"dolch", 1))
	var puppe := _puppe("Sack", 400)
	var battle := _battle([dieb], [puppe])
	var serie := _skill([BlockLibrary.get_block(&"tech_serienschlag")])
	_check(serie.treffer() == 1 and BlockLibrary.get_block(&"tech_serienschlag").weapon_families.has(&"dolch"),
		"Dolch-Klotz aus dem Training")
	var schaeden: Array[int] = []
	for runde in 3:
		var vorher := puppe.hp
		dieb.mp = 999
		battle.use_skill(dieb, serie, puppe)
		schaeden.append(vorher - puppe.hp)
	_check(schaeden[1] > schaeden[0] and schaeden[2] > schaeden[1],
		"wird von Zug zu Zug stärker (%s)" % [schaeden])
	var schluessel := Battle._serien_schluessel(dieb, puppe)
	var stufe: float = battle._serie.get(schluessel, 0.0)
	_check(stufe > 0.5 and stufe <= Battle.SERIE_MAX, "Trefferstärke wächst mit gedeckelt bei 100 %% (jetzt %d %%)" % roundi(stufe * 100))
	var anderes := _puppe("Anderer", 400)
	battle.enemies.append(anderes)
	_check(battle._serie.get(Battle._serien_schluessel(dieb, anderes), Battle.SERIE_START) == Battle.SERIE_START,
		"ein neues Ziel beginnt wieder bei 10 %")


## Ein reiner Zauber aus Klötzen (ohne Waffen-Quelle).
func _zauber(ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Zauber"
	for id in ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _test_buff_stufen() -> void:
	print("Buff-/Debuff-Stufen (DQ9):")
	var held := _held("Priester")
	var ziel := _held("Ritter")
	var puppe := _puppe("Sack", 400)
	var battle := _battle([held, ziel], [puppe])
	var wappnen := _zauber([&"src_spell", &"form_ally", &"eff_def_up"])
	battle.use_skill(held, wappnen, ziel)
	var e1: Dictionary = ziel.get_status(Enums.Status.DEF_UP).duplicate()
	battle.use_skill(held, wappnen, ziel)
	var e2: Dictionary = ziel.get_status(Enums.Status.DEF_UP).duplicate()
	ziel.get_status(Enums.Status.DEF_UP)["turns"] = 1  # fast abgelaufen
	battle.use_skill(held, wappnen, ziel)
	var e3: Dictionary = ziel.get_status(Enums.Status.DEF_UP)
	_check(e1["stufe"] == 1 and e2["stufe"] == 2 and e2["potency"] == e1["potency"] * 2,
		"zweiter Zauber: Stufe 2, doppelte Wirkung (%d » %d %%)" % [e1["potency"], e2["potency"]])
	_check(e3["stufe"] == 2 and e3["potency"] == e2["potency"] and e3["turns"] > 1,
		"dritter Zauber: nur Auffrischen, keine Stufe 3")
	_check(" II" in Battle.status_label(e3) and "(" in Battle.status_label(e3),
		"Anzeige zeigt Stufe II und Restrunden (%s)" % Battle.status_label(e3))
	ziel.statuses.clear()
	ziel.add_status(Enums.Status.ATK_UP, 99, 20)  # Boss-Phase o.ä. — keine Klotz-Stufe
	_check(ziel.stufen_status_setzen(Enums.Status.ATK_UP, 3, 25) == 1, "direkt gesetzter Status zählt als Stufe 0")
	ziel.stufen_status_setzen(Enums.Status.ATK_UP, 3, 50)
	_check(ziel.get_status(Enums.Status.ATK_UP)["potency"] == Combatant.STUFEN_DECKEL[Enums.Status.ATK_UP],
		"Obergrenze greift (Stärken höchstens %d %%)" % Combatant.STUFEN_DECKEL[Enums.Status.ATK_UP])


func _test_neue_effekte() -> void:
	print("Magieschild, Magiebruch, Element-Schutz/-Schwäche, Eis/Blitz:")
	var magier := _held("Magier")
	magier.stats.intelligence = 60
	var blitz := _zauber([&"src_spell", &"elem_lightning"])
	var normal := _magie_schaden(magier, blitz, [])
	var mit_schild := _magie_schaden(magier, blitz, [[Enums.Status.MAGIE_SCHUTZ, 25, -1]])
	var mit_bruch := _magie_schaden(magier, blitz, [[Enums.Status.MAGIE_BRUCH, 25, -1]])
	_check(mit_schild < normal and mit_bruch > normal,
		"Magieschild senkt, Magiebruch erhöht Magieschaden (%d / %d / %d)" % [mit_schild, normal, mit_bruch])
	var eis := _zauber([&"src_spell", &"elem_ice"])
	var eis_normal := _magie_schaden(magier, eis, [])
	var eis_schwach := _magie_schaden(magier, eis, [[Enums.Status.ELEMENT_SCHWAECHE, 50, Enums.Element.ICE]])
	var eis_falsch := _magie_schaden(magier, eis, [[Enums.Status.ELEMENT_SCHWAECHE, 50, Enums.Element.FIRE]])
	var eis_schutz := _magie_schaden(magier, eis, [[Enums.Status.ELEMENT_SCHUTZ, 50, -1]])
	_check(eis_schwach > eis_normal and eis_falsch == eis_normal and eis_schutz < eis_normal,
		"Elementschwäche nur fürs eigene Element, Elementschutz für alle (%d / %d / %d / %d)"
		% [eis_schutz, eis_normal, eis_falsch, eis_schwach])
	# Elementschwäche übernimmt das Element des Zaubers.
	var puppe := _puppe("Sack", 400)
	var battle := _battle([magier], [puppe])
	battle.rng.seed = 3
	var schwaechen := _zauber([&"src_spell", &"elem_ice", &"eff_elementschwaeche"])
	for i in 6:
		if puppe.has_status(Enums.Status.ELEMENT_SCHWAECHE):
			break
		battle.use_skill(magier, schwaechen, puppe)
	var eintrag := puppe.get_status(Enums.Status.ELEMENT_SCHWAECHE)
	_check(not eintrag.is_empty() and int(eintrag["element"]) == Enums.Element.ICE,
		"Eis-Zauber mit Elementschwäche macht das Ziel eis-anfällig")
	# Eis schlägt härter zu als ein elementloser Zauber (Feuer läuft über Brand).
	var roh := _magie_schaden(magier, _zauber([&"src_spell"]), [])
	_check(eis_normal > roh, "Eis-Direktschaden über dem Grundzauber (%d > %d)" % [eis_normal, roh])
	_check(Battle._signatur_schaden(2.0) > 1.0 and is_equal_approx(Battle._signatur_schaden(1.0), 1.0),
		"Signatur verstärkt Eis/Blitz-Schaden anteilig")


## Magieschaden eines Zaubers gegen eine Puppe mit vorgegebenen Status
## [status, potency, element] (ohne Krit, Kontroll-Würfel egal).
func _magie_schaden(held: Combatant, skill: Skill, status: Array) -> int:
	var puppe := _puppe("Sack", 400)
	for s in status:
		puppe.statuses.append({"status": s[0], "turns": 5, "potency": s[1], "element": s[2], "stufe": 1})
	var battle := _battle([held], [puppe])
	var vorher := puppe.hp
	battle.use_skill(held, skill, puppe)
	return vorher - puppe.hp
