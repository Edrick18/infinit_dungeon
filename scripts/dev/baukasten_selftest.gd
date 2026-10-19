extends SceneTree
## Headless-Selbsttest für die Bauregeln des Baukastens 2.0:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/baukasten_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_sockel()
	_test_duplikate_und_gruppen()
	_test_kern()
	_test_regeltabelle()
	_test_kosten()
	_test_waffenhieb_schlaegt_angriff()
	_test_starter_und_gegner()
	_test_boss_kontrolle()
	_test_geist_skaliert()
	_test_werkstatt()
	_test_rezeptbuch()
	_test_heilung_waechst_mit()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Baukasten-Tests bestanden")
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


func _b(id: StringName) -> SkillBlock:
	var block := BlockLibrary.get_block(id)
	assert(block != null, "Unbekannter Klotz %s" % id)
	return block


func _skill(ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Test"
	for id in ids:
		skill.blocks.append(_b(id))
	return skill


func _gleiche_stats(wert: int) -> StatBlock:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, wert)
	return stats


func _test_sockel() -> void:
	print("Sockel nach Level:")
	_check(CharacterDef.block_sockets_for(1) == 3 and CharacterDef.block_sockets_for(7) == 3,
		"Level 1–7: 3 Sockel")
	_check(CharacterDef.block_sockets_for(8) == 4 and CharacterDef.block_sockets_for(18) == 5
		and CharacterDef.block_sockets_for(30) == 6 and CharacterDef.block_sockets_for(50) == 7,
		"Level 8/18/30/50: 4/5/6/7 Sockel")
	_check(CharacterDef.block_sockets_for(50, 1) == 8 and CharacterDef.block_sockets_for(200, 5) == 8,
		"nach der Wiedergeburt 8 — Maximum")
	_check(CharacterDef.next_socket_level(10) == 18 and CharacterDef.next_socket_level(60) == -1,
		"nächster Sockel: Lv 10 » 18, ab 50 keiner mehr über Level")

	var held := HeroLibrary.create_hero("Sockelprobe", &"feuerstab")
	var gross := _skill([&"src_spell", &"elem_fire", &"form_aoe", &"mod_treffer"])
	_check(not gross.is_valid(held) and gross.is_valid(),
		"4 Klötze auf Level 1: für den Helden ungültig, ohne Anwender gültig")
	_check("4 von 3" in gross.fehler(held), "Grund nennt Klötze/Sockel: " + gross.fehler(held))
	held.peak_level = 8
	_check(gross.is_valid(held), "nach Level 8 (Höchstlevel zählt) passt der Skill")

	var gegner := Combatant.create("Riese", _gleiche_stats(5), false)
	var riesig := _skill([&"src_spell", &"elem_fire", &"form_aoe", &"mod_treffer", &"eff_weaken"])
	_check(riesig.is_valid(gegner), "Gegner haben kein Sockel-Limit")


func _test_duplikate_und_gruppen() -> void:
	print("Einzigartig & Gruppen:")
	_check(not _skill([&"src_weapon", &"src_weapon"]).is_valid(), "doppelte Waffennutzung ungültig")
	_check(not _skill([&"src_spell", &"eff_weaken", &"eff_weaken"]).is_valid(), "doppelter Effekt ungültig")
	_check(_skill([&"src_weapon", &"src_spell", &"elem_fire"]).is_valid(),
		"Hybrid Waffe + Zauber + Element bleibt erlaubt")
	_check(not _skill([&"src_spell", &"elem_fire", &"elem_ice"]).is_valid(), "zwei Elemente ungültig")
	_check(not _skill([&"src_spell", &"form_aoe", &"form_aura"]).is_valid(), "zwei Formen ungültig")
	var krit := _skill([&"src_weapon", &"mod_praezision", &"tech_schwertkunst"])
	_check(not krit.is_valid(), "Präzision + Schwertkunst stapeln nicht (Gruppe)")
	_check("Krit-Chance" in krit.fehler(), "Grund nennt die Gruppe: " + krit.fehler())
	_check(_skill([&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_treffer"]).is_valid(),
		"Zusatztreffer ist stapelbar")
	_check(not _skill([&"src_weapon", &"mod_wucht", &"mod_flinkheit"]).is_valid(),
		"Wucht + Flinkheit: nur ein Zeitpunkt")
	_check(not _skill([&"src_weapon", &"form_aoe", &"mod_ziel_zufall"]).is_valid(),
		"Alle Gegner + Zufallsziel: nur eine Zielwahl")
	_check(not _skill([&"src_weapon", &"eff_stun", &"tech_sh_stun2"]).is_valid(),
		"Betäuben I + Schild-Betäuben ungültig")
	_check(_skill([&"src_weapon", &"mod_treffer", &"mod_praezision", &"mod_pierce"]).is_valid(),
		"verschiedene Gruppen vertragen sich")
	_check(_skill([&"src_weapon", &"form_aoe"]).is_valid(), "Waffenangriff + Alle Gegner ist erlaubt")
	_check(not _skill([&"src_weapon", &"form_ally"]).is_valid(), "Waffenangriff + Verbündeter bleibt ungültig")


func _test_kern() -> void:
	print("Kern-Klötze:")
	_check(_b(&"tech_echo").kern and _b(&"tech_klingentanz").kern and _b(&"eff_revive").kern
		and _b(&"form_summon").kern, "Echo, Klingentanz, Wiederbeleben, Beschwörung sind Kern")
	for familie in [&"schwert", &"dolch", &"axt", &"stumpf", &"bogen", &"armbrust",
			&"offensivstab", &"heiligstab", &"schild"]:
		var baum := BlockLibrary.tree_blocks(familie)
		_check(baum.size() >= 7 and baum.back().kern,
			"Baum %s: %d Waffen-Klötze, der höchste ist Kern" % [familie, baum.size()])
	_check(not _skill([&"src_spell", &"tech_echo", &"tech_os_meister"]).is_valid(), "zwei Kern-Klötze ungültig")
	_check(_skill([&"src_spell", &"tech_echo"]).is_valid(), "ein Kern-Klotz ist erlaubt")


func _test_regeltabelle() -> void:
	print("Regeltabelle:")
	var fehlend: Array[String] = []
	for id in BlockLibrary.REGELN:
		if BlockLibrary.get_block(id) == null:
			fehlend.append(String(id))
	_check(fehlend.is_empty(), "jede Regel gehört zu einem existierenden Klotz %s" % [fehlend])
	var flach: Array[String] = []
	for block in BlockLibrary.all_blocks():
		if block is ModifierBlock and block.mp_cost != 0:
			flach.append(String(block.id))
	_check(flach.is_empty(), "Verstärker kosten keine flachen MP mehr %s" % [flach])
	var namenlos: Array[String] = []
	for block in BlockLibrary.all_blocks():
		if block.gruppe != &"" and not BlockLibrary.GRUPPEN.has(block.gruppe) \
				and not Skill.GRUPPEN_NAMEN.has(block.gruppe):
			namenlos.append(String(block.gruppe))
	_check(namenlos.is_empty(), "jede Gruppe hat einen Anzeigenamen %s" % [namenlos])

	# Alte Spielstände: entfernte Klötze werden beim Laden umgeschrieben.
	var alt := Skill.from_dict({"name": "Alt", "block_ids":
		["src_weapon", "mod_power", "tech_bo_multi2", "mod_chain"]})
	var ids: Array[StringName] = []
	for block in alt.blocks:
		ids.append(block.id)
	_check(ids == [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_wechsel"],
		"Migration: Verstärken entfällt, Mehrfachtreffer II » 2× Zusatztreffer, Kette » Wechselziel %s" % [ids])
	for id in BlockLibrary.ALIAS:
		_check(BlockLibrary.get_block(id) == null, "alte ID %s gibt es nicht mehr" % id)


func _test_kosten() -> void:
	print("MP-Kosten:")
	_check(_skill([&"src_spell"]).get_mp_cost() == 3, "Zauber allein: 3 MP")
	_check(_skill([&"src_spell", &"mod_treffer"]).get_mp_cost() == roundi(3 * 1.2),
		"Zusatztreffer multipliziert: 3 × 1.2")
	_check(_skill([&"src_spell", &"mod_treffer", &"mod_overload"]).get_mp_cost() == roundi(3 * 1.2 * 1.5),
		"Verstärker multiplizieren sich: 3 × 1.2 × 1.5")
	_check(_skill([&"src_spell", &"eff_weaken"]).get_mp_cost() == 6, "Effekte addieren flach: 3 + 3")
	var held := Combatant.create("Ausgeglichen", _gleiche_stats(40), true)
	var waffe := _skill([&"src_weapon"]).get_mp_cost(held)
	var zauber := _skill([&"src_spell"]).get_mp_cost(held)
	_check(waffe < zauber, "Waffenskill billiger als Zauber bei gleichen Werten (%d < %d MP)" % [waffe, zauber])


func _test_waffenhieb_schlaegt_angriff() -> void:
	print("Waffennutzung vs. freier Angriff:")
	var held := HeroLibrary.create_hero("Hiebprobe", &"schwert_schild")
	var puppe_a := Combatant.create("Puppe A", _gleiche_stats(30), false)
	var puppe_b := Combatant.create("Puppe B", _gleiche_stats(30), false)
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.start([held] as Array[Combatant], [puppe_a, puppe_b] as Array[Combatant])
	held.mp = 99
	var vorher_a := puppe_a.hp
	battle.basic_attack(held, puppe_a)
	var angriff := vorher_a - puppe_a.hp
	var vorher_b := puppe_b.hp
	battle.use_skill(held, held.skills[0], puppe_b)
	var hieb := vorher_b - puppe_b.hp
	_check(hieb > angriff, "Waffenhieb (%d) trifft härter als Angriff (%d)" % [hieb, angriff])


func _test_starter_und_gegner() -> void:
	print("Starter-Kits & Gegner-Skills:")
	for loadout in HeroLibrary.STARTER_LOADOUTS:
		var held := HeroLibrary.create_hero("Start", loadout)
		_check(held.skills[0].is_valid(held), "Start-Skill %s passt in 3 Sockel" % loadout)
	var kaputt: Array[String] = []
	for archetyp in EnemyLibrary.all_archetypes():
		for skill in archetyp.skill_pool:
			if not skill.is_valid():
				kaputt.append("%s/%s: %s" % [archetyp.id, skill.display_name, skill.fehler()])
	for gruppe in EnemyFactory.VARIANT_GROUPS:
		for variante in EnemyFactory.VARIANT_GROUPS[gruppe]:
			if variante.has("blocks"):
				var skill := Skill.new()
				for id in variante["blocks"]:
					skill.blocks.append(_b(id))
				if not skill.is_valid():
					kaputt.append("%s/%s: %s" % [gruppe, variante["skill_name"], skill.fehler()])
	for modifikator in EnemyLibrary.all_modifiers():
		if modifikator.granted_skill != null and not modifikator.granted_skill.is_valid():
			kaputt.append("%s: %s" % [modifikator.id, modifikator.granted_skill.fehler()])
	_check(kaputt.is_empty(), "alle Gegner-Skills halten die Bauregeln ein %s" % [kaputt])

	var technik := _skill([&"src_weapon", &"tech_erstschlag"])
	var gegner := Combatant.create("Dachs", _gleiche_stats(5), false)
	var held := HeroLibrary.create_hero("Ohne Dolch", &"schwert_schild")
	_check(technik.usable_with_weapon(gegner), "Gegner-Techniken sind angeboren (keine Waffe nötig)")
	_check(not technik.usable_with_weapon(held), "Helden brauchen weiterhin die Waffe (Dolch)")


func _test_boss_kontrolle() -> void:
	print("Kontrolle gegen Bosse:")
	var battle := Battle.new()
	battle.rng.seed = 42
	var normal := Combatant.create("Wicht", _gleiche_stats(5), false)
	var immer := true
	for i in 50:
		immer = immer and battle.kontrolle_gelingt(normal, 100)
	_check(immer, "normale Gegner: 100 % bleiben 100 %")
	var boss := Combatant.create("Boss", _gleiche_stats(5), false)
	boss.is_boss = true
	var treffer := 0
	for i in 1000:
		boss.kontroll_resistenz = 0.0
		if battle.kontrolle_gelingt(boss, 100):
			treffer += 1
	_check(treffer > 430 and treffer < 570, "Boss: halbe Chance (%d/1000 bei 100 %%)" % treffer)
	boss.kontroll_resistenz = 0.0
	while not battle.kontrolle_gelingt(boss, 100):
		pass
	_check(is_equal_approx(boss.kontroll_resistenz, 0.5), "jeder Erfolg: +50 % Resistenz")
	treffer = 0
	for i in 1000:
		boss.kontroll_resistenz = 1.0
		if battle.kontrolle_gelingt(boss, 100):
			treffer += 1
	_check(treffer > 180 and treffer < 320, "Resistenz 100 %%: nur noch ~25 %% (%d/1000)" % treffer)
	boss.reset_for_battle(true)
	_check(boss.kontroll_resistenz == 0.0, "Resistenz gilt nur für einen Kampf")


func _test_werkstatt() -> void:
	print("Werkstatt (Ziehen, Reparieren, Vorlagen):")
	var held := HeroLibrary.create_hero("Bastler", &"feuerstab")
	var feuerball := _skill([&"src_spell", &"elem_fire"])
	_check(WerkstattLogik.passt(feuerball, 2, _b(&"mod_treffer"), held).is_empty(),
		"Verstärker in den freien Sockel: passt")
	_check(not WerkstattLogik.passt(feuerball, 2, _b(&"elem_ice"), held).is_empty(),
		"zweites Element: rot (mit Grund)")
	_check(WerkstattLogik.passt(feuerball, 1, _b(&"elem_ice"), held).is_empty(),
		"Element gegen Element tauschen: passt")
	_check(WerkstattLogik.passt(Skill.new(), 0, _b(&"elem_fire"), held).is_empty(),
		"leerer Skill: Element zuerst ist erlaubt (unfertig ≠ Regelbruch)")
	var kaputt := _skill([&"src_spell", &"elem_fire", &"src_spell", &"src_spell"])
	_check(WerkstattLogik.passt(kaputt, 2, _b(&"mod_treffer"), held).is_empty(),
		"alter kaputter Skill: Reparatur-Tausch bleibt möglich")

	var alt := _skill([&"src_weapon", &"mod_praezision", &"mod_praezision", &"mod_praezision", &"mod_praezision"])
	var neu := WerkstattLogik.repariert(alt.blocks, held)
	var repariert := Skill.new()
	repariert.blocks = neu
	_check(neu.size() == 2 and repariert.is_valid(held), "Reparatur: Waffe + 4× Präzision » Waffe + Präzision")
	var verdreht := _skill([&"elem_fire", &"elem_ice", &"src_spell", &"form_aoe"])
	var gerettet := Skill.new()
	gerettet.blocks = WerkstattLogik.repariert(verdreht.blocks, held)
	_check(gerettet.is_valid(held) and gerettet.has_source(Enums.SkillSource.SPELL)
		and gerettet.blocks.size() == 3, "Reparatur: zwei Elemente VOR der Quelle » Quelle bleibt erhalten")

	var alles_frei := func(_block: SkillBlock) -> bool: return true
	var nichts_frei := func(block: SkillBlock) -> bool: return block.id == &"src_spell"
	var alle := WerkstattLogik.vorlagen([["A", "A", [&"src_spell", &"elem_fire"]],
		["B", "B", [&"src_spell", &"elem_fire", &"form_aoe", &"mod_treffer"]]], held, alles_frei)
	_check(alle.size() == 1 and alle[0].display_name == "A", "Vorlagen: nur was in 3 Sockel passt")
	_check(WerkstattLogik.vorlagen([["A", "A", [&"src_spell", &"elem_fire"]]], held, nichts_frei).is_empty(),
		"Vorlagen: nur mit freigeschalteten Klötzen")
	var meister := HeroLibrary.create_hero("Meister", &"feuerstab")
	meister.peak_level = 50
	_check(WerkstattLogik.vorlagen(WerkstattLogik.REZEPTE, meister, alles_frei).size()
		== WerkstattLogik.REZEPTE.size(), "alle %d Rezepte sind gültige Skills" % WerkstattLogik.REZEPTE.size())


func _test_geist_skaliert() -> void:
	print("Geist (SPI) skaliert Support-Effekte:")
	var schild := _skill([&"src_spell", &"form_self", &"eff_shield"])
	var ergebnisse: Array[int] = []
	var max_hp := 0
	for geist in [5, 40]:
		var stats := _gleiche_stats(5)
		stats.spirit = geist
		var held := Combatant.create("Geist %d" % geist, stats, true)
		held.mp = 999
		var battle := Battle.new()
		battle.start([held] as Array[Combatant],
			[Combatant.create("Puppe", _gleiche_stats(5), false)] as Array[Combatant])
		held.mp = 999
		battle.use_skill(held, schild, null)
		ergebnisse.append(int(held.get_status(Enums.Status.SHIELD).get("potency", 0)))
		max_hp = held.max_hp
	_check(ergebnisse[0] >= max_hp * 0.15 and ergebnisse[1] > ergebnisse[0] * 1.2,
		"Schild in %% der Max-HP: Geist 5 » %d, Geist 40 » %d (Max-HP %d)" % [ergebnisse[0], ergebnisse[1], max_hp])

	# Endgame: auf Level 100 bleibt der Schild ein fester Anteil der Max-HP —
	# weder bedeutungslos klein noch explodierend (Geist-Bonus höchstens ×2).
	var stats_hoch := _gleiche_stats(60)
	var veteran := Combatant.create("Veteran", stats_hoch, true)
	veteran.level = 100
	veteran.recompute_derived()
	veteran.hp = veteran.max_hp
	var battle_hoch := Battle.new()
	battle_hoch.start([veteran] as Array[Combatant],
		[Combatant.create("Puppe", _gleiche_stats(5), false)] as Array[Combatant])
	veteran.mp = 99999
	battle_hoch.use_skill(veteran, schild, null)
	var anteil := float(veteran.get_status(Enums.Status.SHIELD).get("potency", 0)) / veteran.max_hp
	_check(anteil >= 0.15 and anteil <= 0.3,
		"Level 100: Schild = %d %% der Max-HP (%d HP)" % [roundi(anteil * 100), veteran.max_hp])


func _test_rezeptbuch() -> void:
	print("Rezeptbuch & Aufstieg:")
	var held := HeroLibrary.create_hero("Sammler", &"feuerstab")
	var feuerball := _skill([&"src_spell", &"elem_fire"])
	feuerball.display_name = "Feuerball"
	held.skills = [feuerball]
	_check(WerkstattLogik.ins_buch(held, feuerball) and held.rezeptbuch.size() == 1,
		"Ins Buch: Kopie liegt im Rezeptbuch")
	_check(held.rezeptbuch[0] != feuerball, "es ist eine Kopie, kein Verweis")
	_check(not WerkstattLogik.ins_buch(held, feuerball), "dasselbe Rezept nicht doppelt")
	_check(not WerkstattLogik.ins_buch(held, Skill.new()), "leere Skills kommen nicht ins Buch")

	var eis := _skill([&"src_spell", &"elem_ice"])
	eis.display_name = "Eissplitter"
	held.rezeptbuch.append(eis)
	held.skills[0] = _skill([&"src_spell", &"elem_lightning"])
	WerkstattLogik.ausruesten(held, 1, 0)
	_check(held.skills[0] == eis, "Ausrüsten: Eissplitter steckt im Slot")
	_check(held.rezeptbuch.size() == 2 and not WerkstattLogik.im_buch(held, eis)
		and WerkstattLogik.im_buch(held, _skill([&"src_spell", &"elem_lightning"])),
		"der alte Slot-Skill wandert ins Buch, nichts geht verloren")
	WerkstattLogik.ausruesten(held, 0, 3)
	_check(held.skills.size() == 4 and held.skills[3].display_name == "Feuerball",
		"Ausrüsten in einen noch leeren Slot füllt die Liste auf")

	var geladen := Combatant.from_dict(held.to_dict())
	_check(geladen.rezeptbuch.size() == held.rezeptbuch.size()
		and WerkstattLogik.gleiches_rezept(geladen.rezeptbuch[0], held.rezeptbuch[0]),
		"Rezeptbuch übersteht den Speicher-Rundweg")

	_check(BlockLibrary.neu_ab_level(1, 3).size() == 3, "Level 1 » 3: drei neue Klötze (Verbündeter, Schwächen, Körper)")
	var text := BlockLibrary.aufstieg_text(7, 8)
	_check("Zufallsziel" in text or "Random target" in text, "Level 8: Zufallsziel wird angekündigt (%s)" % text)
	_check("Sockel" in text or "socket" in text, "Level 8: +1 Sockel wird angekündigt")
	_check(BlockLibrary.aufstieg_text(61, 62).is_empty(), "ohne Neues kein Text")


## Heilung darf nicht davonlaufen: Anteil an den Max-HP eines Tanks bleibt
## über die Level ungefähr gleich (früher Lv 50 = Vollheilung je Zauber).
func _test_heilung_waechst_mit() -> void:
	print("Heilung skaliert wie die Welt (nicht doppelt):")
	var anteile: Array[float] = []
	for level in [10, 80]:
		var heiler := _messheld("Heiler", level, {&"intelligence": 0.4, &"spirit": 0.4, &"vitality": 0.2},
			[&"heiligstab", &"robe_heil"])
		var tank := _messheld("Tank", level, {&"vitality": 0.6, &"strength": 0.4},
			[&"schwert", &"ruestung_schwer"])
		var battle := Battle.new()
		battle.crit_enabled = false
		battle.start([heiler, tank] as Array[Combatant],
			[Combatant.create("Puppe", _gleiche_stats(5), false)] as Array[Combatant])
		heiler.mp = 99999
		tank.hp = 1
		battle.use_skill(heiler, _skill([&"src_spell", &"elem_holy", &"form_ally"]), tank)
		anteile.append(float(tank.hp - 1) / tank.max_hp)
	_check(anteile[1] < 0.9 and anteile[1] < anteile[0] * 1.6,
		"Heilung in %% der Tank-HP: Lv 10 » %d %%, Lv 80 » %d %%" % [roundi(anteile[0] * 100), roundi(anteile[1] * 100)])


func _messheld(name: String, level: int, anteile: Dictionary, gear: Array) -> Combatant:
	var stats := _gleiche_stats(5)
	var punkte := 0
	for l in range(2, level + 1):
		punkte += Combatant.stat_points_for_level(l, 0)
	for stat in anteile:
		stats.set(stat, stats.get(stat) + roundi(punkte * anteile[stat]))
	var held := Combatant.create(name, stats, true)
	held.level = level
	for id in gear:
		held.equip(ItemLibrary.make_item(id, level))
	held.recompute_derived()
	held.hp = held.max_hp
	return held
