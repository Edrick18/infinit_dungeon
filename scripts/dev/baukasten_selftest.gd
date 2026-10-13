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
	var gross := _skill([&"src_spell", &"elem_fire", &"form_aoe", &"mod_power"])
	_check(not gross.is_valid(held) and gross.is_valid(),
		"4 Klötze auf Level 1: für den Helden ungültig, ohne Anwender gültig")
	_check("4 von 3" in gross.fehler(held), "Grund nennt Klötze/Sockel: " + gross.fehler(held))
	held.peak_level = 8
	_check(gross.is_valid(held), "nach Level 8 (Höchstlevel zählt) passt der Skill")

	var gegner := Combatant.create("Riese", _gleiche_stats(5), false)
	var riesig := _skill([&"src_spell", &"elem_fire", &"form_aoe", &"mod_power", &"eff_weaken"])
	_check(riesig.is_valid(gegner), "Gegner haben kein Sockel-Limit")


func _test_duplikate_und_gruppen() -> void:
	print("Einzigartig & Gruppen:")
	_check(not _skill([&"src_weapon", &"src_weapon"]).is_valid(), "doppelte Waffennutzung ungültig")
	_check(not _skill([&"src_spell", &"eff_weaken", &"eff_weaken"]).is_valid(), "doppelter Effekt ungültig")
	_check(_skill([&"src_weapon", &"src_spell", &"elem_fire"]).is_valid(),
		"Hybrid Waffe + Zauber + Element bleibt erlaubt")
	_check(not _skill([&"src_spell", &"elem_fire", &"elem_ice"]).is_valid(), "zwei Elemente ungültig")
	_check(not _skill([&"src_spell", &"form_aoe", &"form_aura"]).is_valid(), "zwei Formen ungültig")
	var kraft := _skill([&"src_weapon", &"mod_power", &"tech_sw_power2"])
	_check(not kraft.is_valid(), "Verstärken I + II stapeln nicht (Gruppe)")
	_check("Verstärken" in kraft.fehler(), "Grund nennt die Gruppe: " + kraft.fehler())
	_check(not _skill([&"src_weapon", &"mod_multi", &"tech_bo_multi2"]).is_valid(),
		"Mehrfachtreffer I + II (Bogen) ungültig")
	_check(not _skill([&"src_weapon", &"eff_stun", &"tech_sh_stun2"]).is_valid(),
		"Betäuben I + Schild-Betäuben ungültig")
	_check(_skill([&"src_weapon", &"mod_power", &"mod_multi", &"mod_pierce"]).is_valid(),
		"verschiedene Gruppen vertragen sich")
	_check(not _skill([&"src_weapon", &"form_aoe"]).is_valid(), "Waffennutzung + Form bleibt ungültig")


func _test_kern() -> void:
	print("Kern-Klötze:")
	_check(_b(&"tech_echo").kern and _b(&"mod_chain").kern and _b(&"eff_revive").kern
		and _b(&"form_summon").kern, "Echo, Kette, Wiederbeleben, Beschwörung sind Kern")
	for familie in [&"schwert", &"dolch", &"axt", &"stumpf", &"bogen", &"armbrust",
			&"offensivstab", &"heiligstab", &"schild"]:
		var meister: SkillBlock = null
		for block in BlockLibrary.tree_blocks(familie):
			if block.tree_points == 100:
				meister = block
		_check(meister != null and meister.kern, "Meister-Klotz (100) im Baum %s ist Kern" % familie)
	_check(not _skill([&"src_spell", &"tech_echo", &"mod_chain"]).is_valid(), "zwei Kern-Klötze ungültig")
	_check(_skill([&"src_spell", &"mod_chain"]).is_valid(), "ein Kern-Klotz ist erlaubt")


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


func _test_kosten() -> void:
	print("MP-Kosten:")
	_check(_skill([&"src_spell"]).get_mp_cost() == 3, "Zauber allein: 3 MP")
	_check(_skill([&"src_spell", &"mod_power"]).get_mp_cost() == roundi(3 * 1.2),
		"Verstärken multipliziert: 3 × 1.2")
	_check(_skill([&"src_spell", &"mod_power", &"mod_multi"]).get_mp_cost() == roundi(3 * 1.2 * 1.5),
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


func _test_geist_skaliert() -> void:
	print("Geist (SPI) skaliert Support-Effekte:")
	var schild := _skill([&"src_spell", &"form_self", &"eff_shield"])
	var ergebnisse: Array[int] = []
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
	_check(ergebnisse[0] >= 10 and ergebnisse[1] > ergebnisse[0] * 1.8,
		"Schild: Geist 5 » %d, Geist 40 » %d" % [ergebnisse[0], ergebnisse[1]])
