extends SceneTree
## Headless-Selbsttest für die drei Affix-Arten (fest, prozentual, Skill-Affix),
## Spanne/Güte, Gruppen-Ausschluss, Würfel-Anteil und Kampfwirkung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/affix_selftest.gd

var failures := 0


func _init() -> void:
	_test_spanne_und_guete()
	_test_pools()
	_test_wuerfeln()
	_test_prozent_rechenweg()
	_test_skill_bonus()
	_test_kampf()
	_test_speichern_und_schmiede()
	_test_texte()
	if failures == 0:
		print("SELFTEST OK — alle Affix-Tests bestanden")
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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Item mit genau diesen Affixen und Würfen.
func _item(base_id: StringName, level: int, affix_ids: Array, rolls: Array) -> ItemInstance:
	var item := ItemLibrary.make_item(base_id, level)
	for i in affix_ids.size():
		item.affixes.append(ItemLibrary.get_affix(affix_ids[i]))
		item.affix_rolls.append(float(rolls[i]) if i < rolls.size() else 1.0)
	return item


func _held(items: Array = []) -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 10)
	var held := Combatant.create("Held", stats, true)
	for item in items:
		held.equip(item)
	held.recompute_derived()
	held.hp = held.max_hp
	held.mp = held.max_mp
	return held


func _skill(ids: Array) -> Skill:
	var skill := Skill.new()
	for id in ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _test_spanne_und_guete() -> void:
	print("Spanne und Güte:")
	_check(LootGenerator.wert_spanne(10) == Vector2(10, 16), "wert_spanne(10) = 10–16")
	_check(LootGenerator.wert_spanne(4) == Vector2(4, 6), "wert_spanne(4) = 4–6 (gerundet wie affix_value)")
	_check(LootGenerator.wert_spanne(15) == Vector2(15, 24), "wert_spanne(15) = 15–24")
	# Grenzen: Wurf MIN » Min-Wert, Wurf MAX » Max-Wert — fest (mit Item-Level),
	# prozentual und Skill-Affix.
	for id in [&"robust", &"brutal", &"p_ruestung_2", &"s_salve_2", &"staerke", &"lodernd", &"frostabwehr"]:
		var unten := _item(&"ruestung_schwer" if id != &"lodernd" else &"schwert", 37, [id],
			[LootGenerator.AFFIX_ROLL_MIN])
		var oben := _item(&"ruestung_schwer" if id != &"lodernd" else &"schwert", 37, [id],
			[LootGenerator.AFFIX_ROLL_MAX])
		var spanne := unten.affix_spanne(0)
		_check(spanne == oben.affix_spanne(0) and unten.affix_wert(0) == int(spanne.x)
			and oben.affix_wert(0) == int(spanne.y),
			"%s: Wurf %.1f » %d, Wurf %.1f » %d, Spanne [%d–%d]" % [id, LootGenerator.AFFIX_ROLL_MIN,
			unten.affix_wert(0), LootGenerator.AFFIX_ROLL_MAX, oben.affix_wert(0), spanne.x, spanne.y])
	# Fester Wert wächst mit dem Item-Level — die Spanne auch.
	var klein := _item(&"ruestung_schwer", 1, [&"robust"], [1.3])
	var gross := _item(&"ruestung_schwer", 80, [&"robust"], [1.3])
	_check(gross.affix_spanne(0).y > klein.affix_spanne(0).y * 10, "feste Spanne skaliert mit dem Item-Level")
	_check(_item(&"ring", 80, [&"p_ruestung_1"], [1.3]).affix_spanne(0) == Vector2(8, 13),
		"Prozent-Spanne unabhängig vom Item-Level")
	# Güte = (Wurf − MIN) ÷ (MAX − MIN).
	var mitte := _item(&"ring", 10, [&"staerke"], [1.3])
	_check(is_equal_approx(mitte.affix_guete(0), 0.5), "Güte bei Wurf 1,3 = 50 %")
	_check(is_equal_approx(_item(&"ring", 10, [&"staerke"], [1.0]).affix_guete(0), 0.0)
		and is_equal_approx(_item(&"ring", 10, [&"staerke"], [1.6]).affix_guete(0), 1.0), "Güte 0 % / 100 %")
	var alt := ItemLibrary.make_item(&"ring", 10)
	alt.affixes.append(ItemLibrary.get_affix(&"staerke"))
	_check(is_equal_approx(alt.affix_roll(0), 1.0) and is_equal_approx(alt.affix_guete(0), 0.0),
		"fehlender Wurf = 1,0")
	var regel := _item(&"ring", 50, [&"doppelkern"], [1.0])
	_check(not regel.affixes[0].rollt() and regel.affix_spanne(0).x == regel.affix_spanne(0).y,
		"Regelbrecher ohne Spanne")
	var dauer := _item(&"ring", 50, [&"s_nachhall"], [1.0])
	_check(not dauer.affixes[0].rollt() and dauer.affix_wert(0) == 1, "„+1 Runde“ ist fest")
	var boss := _item(&"ring", 50, [&"boss_golem_haut"], [1.6])
	_check(boss.affix_spanne(0) == LootGenerator.wert_spanne(6) and boss.affix_wert(0) == 10,
		"Boss-Affix mit Spanne seines boss_wert (6 » 6–10)")


func _test_pools() -> void:
	print("Pools:")
	var prozent_unter_10 := false
	for prefix in [true, false]:
		for affix in ItemLibrary.affixes_for_tier(9, prefix):
			prozent_unter_10 = prozent_unter_10 or affix.prozent_art != &""
	_check(not prozent_unter_10, "keine Prozent-Affixe unter Kartenstufe 10")
	var ab_10 := 0
	for affix in ItemLibrary.affixes_for_tier(10, true) + ItemLibrary.affixes_for_tier(10, false):
		if affix.prozent_art != &"":
			ab_10 += 1
	_check(ab_10 == ItemLibrary.PROZENT_AFFIXE.size(), "ab Stufe 10 je Größe ein Prozent-Affix (%d)" % ab_10)
	var skill_alle := ItemLibrary.skill_affixes_for_tier(9999)
	_check(skill_alle.size() >= 15 and skill_alle.size() <= 25, "%d Skill-Affixe (15–25)" % skill_alle.size())
	var normal_ohne_skill := true
	for affix in ItemLibrary.affixes_for_tier(9999, true) + ItemLibrary.affixes_for_tier(9999, false):
		normal_ohne_skill = normal_ohne_skill and not affix.ist_skill_affix()
	_check(normal_ohne_skill, "Skill-Affixe nicht im Werte-Pool")
	# Jeder Bezug zeigt auf etwas Echtes in der BlockLibrary.
	var bezug_ok := true
	for affix in skill_alle:
		var teile := String(affix.klotz_bezug).split(":")
		var echt := false
		match teile[0]:
			"klotz":
				echt = BlockLibrary.get_block(StringName(teile[1])) != null
			"gruppe":
				for block in BlockLibrary.all_blocks():
					echt = echt or Skill.gruppe_von(block) == StringName(teile[1])
			"gattung":
				echt = not BlockLibrary.tree_blocks(StringName(teile[1])).is_empty()
			"element":
				echt = Skill.BEZUG_ELEMENT.has(teile[1])
			"form":
				echt = Skill.BEZUG_FORM.has(teile[1])
		if not echt:
			bezug_ok = false
			printerr("    Bezug ohne Klotz: %s" % affix.klotz_bezug)
	_check(bezug_ok, "alle Skill-Bezüge treffen echte Klötze/Gruppen/Gattungen")
	# Gruppen: fest und prozentual derselben Größe teilen sich die Gruppe.
	_check(&"ruestung" in ItemLibrary.get_affix(&"robust").gruppen()
		and &"ruestung" in ItemLibrary.get_affix(&"p_ruestung_1").gruppen(), "„Robustes“ und „Beschlagenes“: Gruppe Rüstung")
	_check(ItemLibrary.get_affix(&"s_glut_1").gruppen() == ItemLibrary.get_affix(&"s_glut_2").gruppen(),
		"Skill-Affixe gleichen Bezugs teilen die Gruppe")
	var A := func(id: StringName) -> Affix: return ItemLibrary.get_affix(id)
	_check(A.call(&"robust").konflikt(A.call(&"p_ruestung_1")) and A.call(&"p_ruestung_1").konflikt(A.call(&"p_ruestung_3")),
		"„+x Rüstung“ schließt „+x % Rüstung“ aus, zwei Rüstungs-% ebenso")
	_check(not A.call(&"robust").konflikt(A.call(&"abwehr")), "zwei feste Rüstungs-Affixe bleiben kombinierbar")
	_check(A.call(&"titanen").konflikt(A.call(&"p_strength_1")) and not A.call(&"titanen").konflikt(A.call(&"p_spirit_1")),
		"„der Titanen“ (STR+VIT) schließt STR-% aus, nicht SPI-%")
	_check(A.call(&"s_glut_1").konflikt(A.call(&"s_glut_2")) and not A.call(&"s_glut_1").konflikt(A.call(&"s_salve_1")),
		"Skill-Affixe: je Bezug einer")
	# Würfeln mit einem schon vorhandenen Affix (Neuwürfeln mit Boss-Affix):
	var mit_boss := ItemLibrary.make_item(&"ruestung_schwer", 150)
	mit_boss.rarity = Enums.Rarity.LEGENDARY
	var rng := _rng(12)
	var boss_ok := true
	for n in 200:
		mit_boss.affixes = [A.call(&"p_ruestung_3")] as Array[Affix]
		mit_boss.affix_rolls = [1.0] as Array[float]
		LootGenerator.apply_random_affixes(mit_boss, rng)
		for i in range(1, mit_boss.affixes.size()):
			boss_ok = boss_ok and not mit_boss.affixes[i].konflikt(mit_boss.affixes[0])
	_check(boss_ok, "vorhandene Affixe sperren ihre Gruppe beim Nachwürfeln")


func _test_wuerfeln() -> void:
	print("Würfeln:")
	var rng := _rng(77)
	var skill_zahl := 0
	var gesamt := 0
	var gruppen_ok := true
	var zahl_ok := true
	for n in 3000:
		var item := LootGenerator.roll_item_with_rarity(60, Enums.Rarity.RARE, rng)
		for a in item.affixes.size():
			var affix: Affix = item.affixes[a]
			if affix.regelbruch != &"":
				continue
			gesamt += 1
			if affix.ist_skill_affix():
				skill_zahl += 1
			for b in a:
				if affix.konflikt(item.affixes[b]):
					gruppen_ok = false
		zahl_ok = zahl_ok and item.affixes.size() == 2 and item.affix_rolls.size() == 2
	var anteil := float(skill_zahl) / gesamt
	print("    Skill-Affix-Anteil: %.3f (%d von %d)" % [anteil, skill_zahl, gesamt])
	_check(absf(anteil - LootGenerator.SKILL_AFFIX_ANTEIL) < 0.03, "Anteil Skill-Affixe ≈ 1/3 (%.3f)" % anteil)
	_check(gruppen_ok, "nie fest + prozentual derselben Größe (bzw. zwei gleiche Bezüge) auf einem Item")
	_check(zahl_ok, "Affix-Zahl und Würfe passen zur Rarität")
	# Legendär auf hoher Stufe: auch mit Gruppen genug Kandidaten für 4 Affixe.
	var voll := true
	for n in 300:
		var item := LootGenerator.roll_item_with_rarity(150, Enums.Rarity.LEGENDARY, rng)
		var normale := 0
		for affix in item.affixes:
			if affix.regelbruch == &"":
				normale += 1
		voll = voll and normale == 4
	_check(voll, "Legendär: immer 4 Affixe trotz Gruppen-Ausschluss")
	# Unter Stufe 5 gibt es keine Skill-Affixe — dann nur Werte-Affixe.
	var frueh_ok := true
	for n in 200:
		for affix in LootGenerator.roll_item_with_rarity(3, Enums.Rarity.EPIC, rng).affixes:
			frueh_ok = frueh_ok and not affix.ist_skill_affix()
	_check(frueh_ok, "Stufe 3: leerer Skill-Pool » nur Werte-Affixe")


func _test_prozent_rechenweg() -> void:
	print("Prozent-Rechenweg:")
	# Rüstung: feste Werte summieren, Item-% + Trainings-% additiv, einmal anwenden.
	var helm := _item(&"helm_schwer", 20, [&"p_ruestung_2"], [1.0])  # +12 %
	var schild := _item(&"schild", 20, [&"p_ruestung_1"], [1.5])     # 8 × 1,5 = +12 %
	var held := _held([helm, schild])
	var fest := helm.get_total_armor() + schild.get_total_armor()
	_check(held.item_prozent(&"ruestung") == 24, "Item-% summieren sich (12 + 12 = 24)")
	_check(held.total_armor() == roundi(fest * 1.24), "Rüstung = feste Summe × 1,24 (%d)" % held.total_armor())
	held.weapon_invest[&"schild"] = 14  # Schild-Training: 5 % + 5 %
	_check(held.training_armor_percent() == 10, "Schild-Training 10 %")
	_check(held.total_armor() == roundi(fest * 1.34),
		"additiv mit Training: × (1 + 0,24 + 0,10) = %d (nicht ×1,24×1,10)" % held.total_armor())
	# Waffenschaden und Zauberkraft: additiv mit den Trainings-Prozenten.
	var schwert := _item(&"schwert", 20, [&"p_schaden_1"], [1.0])  # +8 %
	var krieger := _held([schwert])
	_check(is_equal_approx(krieger.training_weapon_mult(), 1.08), "Waffenschaden +8 %")
	krieger.weapon_invest[&"schwert"] = 7  # +10 % Training
	_check(is_equal_approx(krieger.training_weapon_mult(), 1.18), "Waffenschaden: 8 % + 10 % Training = ×1,18")
	var stab := _item(&"offensivstab", 20, [&"p_zauberkraft_2"], [1.0])
	_check(is_equal_approx(_held([stab]).training_spell_mult(), 1.12), "Zauberkraft +12 %")
	# Attribute: EIN Faktor auf Basis + Ausrüstung, Level-Skalierung multipliziert.
	var ring := _item(&"ring", 20, [&"staerke", &"p_strength_1"], [1.0, 1.0])  # +3 STR, +8 % STR
	var starker := _held([ring])
	starker.level = 30
	var ohne := _held([_item(&"ring", 20, [&"staerke"], [1.0])])
	ohne.level = 30
	var basis_plus := 10 + ring.get_total_stat_bonus().strength
	_check(starker.stat(&"strength") == roundi(basis_plus * 1.08 * Scaling.factor(30)),
		"STR = (Basis + Ausrüstung) × 1,08 × Level-Skalierung (%d)" % starker.stat(&"strength"))
	_check(starker.stat_roh(&"strength") == roundi(basis_plus * 1.08), "stat_roh mit Attribut-%")
	_check(starker.stat(&"strength") > ohne.stat(&"strength"), "Attribut-% wirkt")
	var hp_vorher := _held([_item(&"ring", 20, [], [])]).max_hp
	_check(_held([_item(&"ring", 20, [&"p_vitality_3"], [1.0])]).max_hp > hp_vorher,
		"VIT-% hebt die Max-HP (über VIT, kein eigenes HP-%)")


func _test_skill_bonus() -> void:
	print("skill_bonus:")
	var ring := _item(&"ring", 50, [&"s_salve_1"], [1.5])  # 8 × 1,5 = 12 %
	var amulett := _item(&"amulett", 50, [&"s_salve_1"], [1.0])  # 8 %
	var held := _held([ring])
	var mit := _skill([&"src_weapon", &"mod_treffer"])
	var ohne := _skill([&"src_weapon", &"mod_praezision"])
	_check(is_equal_approx(held.skill_bonus(mit, &"schaden"), 12.0), "Zusatztreffer-Skill: +12 %")
	_check(is_equal_approx(held.skill_bonus(ohne, &"schaden"), 0.0), "Skill ohne Zusatztreffer: 0")
	_check(is_equal_approx(held.skill_bonus(mit, &"mp"), 0.0), "andere Wirkung: 0")
	# Mehrere passende Klötze (Zusatztreffer ist stapelbar, dazu Sockel-Regelbruch):
	# Wirkung trotzdem nur einmal.
	var sockel := _item(&"amulett", 50, [&"baumeister"], [1.0])
	var baumeister := _held([ring, sockel])
	var dreifach := _skill([&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_treffer"])
	_check(is_equal_approx(baumeister.skill_bonus(dreifach, &"schaden"), 12.0),
		"drei Zusatztreffer (Sockel-Regelbruch): +12 % einmal, nicht dreimal")
	# Zwei Items mit demselben Skill-Affix addieren ihre Werte — je Skill einmal.
	var doppelt := _held([ring, amulett])
	_check(is_equal_approx(doppelt.skill_bonus(dreifach, &"schaden"), 20.0), "zwei Items: 12 + 8 = 20 %")
	# Doppelkern: zwei Schwert-Kerne im Skill » Schwert-Techniken-Bonus einmal.
	var kern_ring := _item(&"ring", 90, [&"doppelkern"], [1.0])
	var fechter := _item(&"amulett", 90, [&"s_fechter"], [1.0])
	var ritter := _held([ItemLibrary.make_item(&"schwert", 90), kern_ring, fechter])
	ritter.level = 100
	ritter.peak_level = 100
	ritter.weapon_invest[&"schwert"] = 100
	var zwei_kerne := _skill([&"src_weapon", &"tech_klingentanz", &"tech_sw_meister"])
	_check(zwei_kerne.is_valid(ritter), "Doppelkern: zwei Schwert-Kerne gültig")
	_check(is_equal_approx(ritter.skill_bonus(zwei_kerne, &"schaden"), 10.0),
		"Doppelkern mit zwei Schwert-Techniken: +10 % einmal")
	# Waffenfrei: die Technik im Skill zählt, nicht die geführte Waffe.
	var frei := _item(&"ring", 90, [&"waffenfreiheit"], [1.0])
	var berserker := _item(&"helm_leicht", 90, [&"s_berserker"], [1.0])
	var axt_held := _held([ItemLibrary.make_item(&"axt", 90), frei, fechter, berserker])
	axt_held.weapon_invest[&"schwert"] = 10
	var schwert_skill := _skill([&"src_weapon", &"tech_duellstoss"])
	_check(schwert_skill.usable_with_weapon(axt_held), "Waffenfrei: Schwert-Technik mit Axt einsetzbar")
	_check(is_equal_approx(axt_held.skill_bonus(schwert_skill, &"schaden"), 10.0),
		"Waffenfrei: Schwert-Techniken-Bonus wirkt (Technik zählt)")
	var nackt := _skill([&"src_weapon", &"mod_wucht"])
	_check(is_equal_approx(axt_held.skill_bonus(nackt, &"schaden"), 0.0),
		"Axt-Bonus nicht auf Skill ohne Axt-Technik (geführte Waffe zählt nicht)")
	# Element, Form, Gruppe, Deckel.
	var feuer := _skill([&"src_spell", &"elem_fire"])
	_check(is_equal_approx(_held([_item(&"ring", 50, [&"s_glut_1"], [1.0])]).skill_bonus(feuer, &"stacks"), 10.0),
		"element:feuer » Feuer-Zauber")
	var flaeche := _skill([&"src_spell", &"form_aoe"])
	_check(is_equal_approx(_held([_item(&"ring", 50, [&"s_weite_1"], [1.0])]).skill_bonus(flaeche, &"mp"), 8.0),
		"form:aoe » Flächen-Skill")
	_check(is_equal_approx(_held([_item(&"ring", 50, [&"s_scharfblick"], [1.0])]).skill_bonus(
		_skill([&"src_weapon", &"mod_praezision"]), &"krit"), 5.0), "gruppe:praezision » Präzision")
	var viele: Array = []
	for slot_base in [&"ring", &"ring", &"amulett", &"helm_leicht", &"handschuhe_leicht", &"stiefel_leicht"]:
		viele.append(_item(slot_base, 90, [&"s_salve_2"], [1.6]))
	_check(is_equal_approx(_held(viele).skill_bonus(mit, &"schaden"), Combatant.SKILL_BONUS_DECKEL[&"schaden"]),
		"Deckel je Wirkung")
	var gegner := Combatant.create("Feind", StatBlock.new(), false)
	gegner.equipment[Enums.EquipSlot.RING_1] = ring
	_check(is_equal_approx(gegner.skill_bonus(mit, &"schaden"), 0.0), "Gegner: keine Skill-Affixe")


func _test_kampf() -> void:
	print("Kampfwirkung:")
	var skill := _skill([&"src_weapon", &"mod_treffer"])
	var schaden := func(items: Array) -> int:
		var held := _held([ItemLibrary.make_item(&"schwert", 20)] + items)
		var feind := Combatant.create("Puppe", StatBlock.new(), false)
		feind.max_hp = 100000
		feind.hp = feind.max_hp
		var battle := Battle.new()
		battle.crit_enabled = false
		battle.rng.seed = 5
		battle.start([held] as Array[Combatant], [feind] as Array[Combatant])
		battle.use_skill(held, skill, feind)
		return feind.max_hp - feind.hp
	var ohne: int = schaden.call([])
	var mit: int = schaden.call([_item(&"ring", 50, [&"s_salve_2"], [1.0])])  # +15 %
	_check(mit > ohne and absf(float(mit) / ohne - 1.15) < 0.03,
		"echter Kampf: +15 %% Schaden für Zusatztreffer-Skill (%d » %d)" % [ohne, mit])
	var fremd: int = schaden.call([_item(&"ring", 50, [&"s_winter"], [1.0])])
	_check(fremd == ohne, "nicht passender Skill-Affix ändert nichts")
	# MP-Kosten: Kampf zieht genau die Werkstatt-Kosten ab.
	var flaeche := _skill([&"src_spell", &"elem_fire", &"form_aoe"])
	var stab := _item(&"offensivstab", 50, [], [])
	var normal := _held([stab])
	var sparer := _held([ItemLibrary.make_item(&"offensivstab", 50), _item(&"ring", 50, [&"s_weite_2"], [1.0])])
	var kosten_normal := flaeche.get_mp_cost(normal)
	var kosten_spar := flaeche.get_mp_cost(sparer)
	_check(kosten_spar < kosten_normal, "Flächen-Skill: −14 %% MP (%d » %d)" % [kosten_normal, kosten_spar])
	var feind := Combatant.create("Puppe", StatBlock.new(), false)
	feind.max_hp = 100000
	feind.hp = feind.max_hp
	var battle := Battle.new()
	battle.start([sparer] as Array[Combatant], [feind] as Array[Combatant])
	var mp_vorher := sparer.mp
	battle.use_skill(sparer, flaeche, feind)
	_check(mp_vorher - sparer.mp == kosten_spar, "Kampf zieht dieselben MP ab (%d)" % (mp_vorher - sparer.mp))
	# Dauer +1 auf Aura-Effekte, Stacks auf Brand.
	var aura := _skill([&"src_spell", &"form_aura", &"eff_def_up"])
	var hall := _held([ItemLibrary.make_item(&"heiligstab", 30), _item(&"ring", 30, [&"s_nachhall"], [1.0])])
	var b2 := Battle.new()
	var puppe := Combatant.create("Puppe", StatBlock.new(), false)
	puppe.max_hp = 1000
	puppe.hp = 1000
	b2.start([hall] as Array[Combatant], [puppe] as Array[Combatant])
	b2.use_skill(hall, aura, hall)
	var wappnen := hall.get_status(Enums.Status.DEF_UP)
	_check(not wappnen.is_empty() and int(wappnen["turns"]) == BlockLibrary.get_block(&"eff_def_up").duration_turns + 1,
		"Aura-Dauer +1 (%s Runden)" % str(wappnen.get("turns", "?")))
	var brand := func(items: Array) -> int:
		var magier := _held([ItemLibrary.make_item(&"offensivstab", 30)] + items)
		var ziel := Combatant.create("Puppe", StatBlock.new(), false)
		ziel.max_hp = 100000
		ziel.hp = ziel.max_hp
		var b := Battle.new()
		b.crit_enabled = false
		b.rng.seed = 9
		b.start([magier] as Array[Combatant], [ziel] as Array[Combatant])
		b.use_skill(magier, _skill([&"src_spell", &"elem_fire"]), ziel)
		return int(ziel.get_status(Enums.Status.BURN).get("potency", 0))
	var stacks_ohne: int = brand.call([])
	var stacks_mit: int = brand.call([_item(&"ring", 50, [&"s_glut_2"], [1.0])])  # +18 %
	_check(stacks_mit > stacks_ohne and absf(float(stacks_mit) / stacks_ohne - 1.18) < 0.05,
		"Brand-Stacks +18 %% (%d » %d)" % [stacks_ohne, stacks_mit])
	# Außerhalb eines Skills (Grundangriff) kein Rest-Bonus.
	_check(b2._bonus_dauer == 0 and is_equal_approx(b2._bonus_stacks, 0.0), "Bonus nach dem Skill zurückgesetzt")


func _test_speichern_und_schmiede() -> void:
	print("Speichern und Schmiede:")
	# Neue Affixe: nur IDs + Würfe.
	var item := _item(&"ruestung_schwer", 60, [&"p_ruestung_2", &"s_waechter"], [1.42, 1.0])
	var daten := item.to_dict()
	var geladen := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(daten)))
	_check(daten["affix_ids"] == ["p_ruestung_2", "s_waechter"] and geladen.affixes.size() == 2
		and is_equal_approx(geladen.affix_roll(0), 1.42) and geladen.affix_wert(0) == item.affix_wert(0),
		"Speicherformat: IDs + Würfe, Werte gleich")
	_check(daten.keys().size() == 5, "keine neuen Felder im Item-Speicher (%s)" % str(daten.keys()))
	# Alter Spielstand (ohne Würfe, alte Basis-ID, unbekannte Affix-ID).
	var alt := ItemInstance.from_dict({"base_id": "kettenhemd", "affix_ids": ["robust", "gibtsnicht", "staerke"],
		"rarity": 2, "item_level": 12})
	_check(alt != null and alt.affixes.size() == 2 and is_equal_approx(alt.affix_roll(1), 1.0)
		and alt.get_total_armor() > 0, "alter Spielstand lädt (Wurf fehlt » 1,0)")
	var alt_mit_wurf := ItemInstance.from_dict({"base_id": "ring", "affix_ids": ["staerke"],
		"affix_rolls": [1.45], "rarity": 1, "item_level": 3})
	_check(roundi(alt_mit_wurf.affix_guete(0) * 100) == 75, "alter Wurf » Güte sofort sichtbar (75 %)")
	# Neuwürfeln behält den Boss-Affix samt Wurf; Gruppen danach frei.
	var boss := _item(&"ruestung_schwer", 60, [&"boss_golem_panzer"], [1.33])
	boss.rarity = Enums.Rarity.EPIC
	var rng := _rng(4)
	var ok := true
	for n in 40:
		Smith.reroll(boss, rng)
		var gefunden := false
		for i in boss.affixes.size():
			gefunden = gefunden or (boss.affixes[i].id == &"boss_golem_panzer" and is_equal_approx(boss.affix_roll(i), 1.33))
		ok = ok and gefunden and boss.affixes.size() == 4 and boss.affix_rolls.size() == 4
	_check(ok, "Smith.reroll behält den Boss-Affix (40 Würfe)")


func _test_texte() -> void:
	print("Item-Karte:")
	var item := _item(&"ruestung_schwer", 1, [&"robust", &"p_ruestung_3", &"s_salve_2"], [1.3, 1.3, 1.2])
	var lesbar := func(t: String) -> String: return t.replace(ItemInfo.NBSP, " ").replace(ItemInfo.WJ, "")
	var fest: String = lesbar.call(ItemInfo.affix_zeile(item, 0))
	var prozent: String = lesbar.call(ItemInfo.affix_zeile(item, 1))
	var skill: String = lesbar.call(ItemInfo.affix_zeile(item, 2))
	print("    " + fest + "  |  " + prozent + "  |  " + skill)
	_check(fest == "+3 Rüstung [2–3] · 50 %", "fest: %s" % fest)
	_check(prozent == "+21 % Rüstung [16–26 %] · 50 %", "prozentual: %s" % prozent)
	_check(skill == "+18 % Schaden für Skills mit Zusatztreffer [15–24 %] · 33 %", "Skill-Affix: %s" % skill)
	var regel := _item(&"ring", 50, [&"waffenfreiheit"], [1.0])
	_check(not ItemInfo.affix_zeile(regel, 0).contains("["), "Regelbrecher ohne Spanne")
	_check(not ItemInfo.affix_zeile(item, 2).contains("4 %"), "Spanne mit geschütztem Leerzeichen")
	var boss := _item(&"ring", 50, [&"boss_schleimgott_schlund"], [1.6])
	var boss_zeile: String = lesbar.call(ItemInfo.affix_zeile(boss, 0))
	_check(boss_zeile.ends_with("[4–6 %] · 100 %"), "Boss-Affix: %s" % boss_zeile)
	Loc.set_language("en")
	ItemLibrary.reset_cache()
	BlockLibrary.reset_cache()
	var en := _item(&"ruestung_schwer", 1, [&"p_ruestung_3", &"s_fechter"], [1.3, 1.0])
	var en_text: String = lesbar.call(ItemInfo.affix_zeile(en, 0) + " | " + ItemInfo.affix_zeile(en, 1))
	Loc.set_language("de")
	ItemLibrary.reset_cache()
	BlockLibrary.reset_cache()
	_check(en_text == "+21% armor [16–26%] · 50% | +10% damage for Sword techniques [10–16%] · 0%", "EN: %s" % en_text)
	var held := _held([_item(&"ring", 50, [&"s_salve_1"], [1.0])])
	var boni := ItemInfo.skill_boni_text(held, _skill([&"src_weapon", &"mod_treffer"]))
	_check(boni.contains("+8 % Schaden") and boni.contains("Ring der Salve"), "Werkstatt: %s" % boni)
	_check(ItemInfo.skill_boni_text(held, _skill([&"src_spell"])).is_empty(), "Werkstatt: leer ohne Bonus")
