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
