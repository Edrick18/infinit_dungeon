extends SceneTree
## Headless-Selbsttest für den Gegner-Baukasten:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/enemy_selftest.gd

var failures := 0


func _init() -> void:
	_test_library()
	_test_build()
	_test_modifiers()
	_test_encounters()
	_test_boss()
	_test_layered_generation()
	_test_class_variants()
	_test_kombos_und_ki()
	_test_sondergegner()
	_test_anfuehrer()
	_test_anzeige_infos()
	_test_hoehlen_familie()
	_test_kombo_ausbau()
	_test_hoellenschlund()
	if failures == 0:
		print("SELFTEST OK — alle Gegner-Baukasten-Tests bestanden")
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


## Fünftes Biom „Höllenschlund“ (2026-11-02): alte Biom-Werte unverändert,
## jede Biom-Tabelle kennt es, die Dämonen leben dort, zwei neue Grundtypen
## sind vollständig (Eigenheit, Gegenweg, Schwächen, Rüstung, Kombos,
## Figur, Material), Boss-Pool und Boss-Beute, Speichern/Laden.
func _test_hoellenschlund() -> void:
	print("Höllenschlund (Biom 5):")
	var h := Enums.Biome.INFERNAL
	_check(Enums.Biome.FOREST == 0 and Enums.Biome.CAVE == 1 and Enums.Biome.RUINS == 2
		and Enums.Biome.CRYPT == 3 and h == 4, "alte Biom-Werte unverändert, Höllenschlund hinten (4)")
	var fehlt: Array[String] = []
	for biome in Enums.Biome.values():
		for tabelle in [["Orte", CardFactory.BIOME_PLACES], ["Orte EN", CardFactory.BIOME_PLACES_EN],
				["Namen", CardFactory.BIOME_NAMES], ["Namen EN", CardFactory.BIOME_NAMES_EN],
				["Kartennamen", CardFactory.BIOME_CARD_NAMES], ["Einstieg", CardFactory.BIOME_UNLOCK_TIER],
				["Rente", CardFactory.BIOME_RETIRE_TIER], ["Stil", BiomStil.DATEN],
				["Grundriss", DungeonGenerator.ORT_GRUNDRISS], ["Region", EnemyFactory.BIOME_VARIANTS],
				["Miniatur", VorratIcons.BIOM_TEILE], ["Händler", DungeonEreignisse.BIOM_ARTEN]]:
			if not (tabelle[1] as Dictionary).has(biome):
				fehlt.append("%s:%d" % [tabelle[0], biome])
		if (CardFactory.BIOME_PLACES[biome] as Array).size() != (CardFactory.BIOME_PLACES_EN[biome] as Array).size():
			fehlt.append("Orte DE/EN:%d" % biome)
	_check(fehlt.is_empty(), "jede Biom-Tabelle kennt alle %d Biome %s" % [Enums.Biome.size(), fehlt])
	var musik: Node = load("res://autoload/music.gd").new()
	var tracks := {}
	var kampf := {}
	for biome in Enums.Biome.values():
		tracks[musik.biom_track(biome)] = true
		kampf[musik.kampf_track(biome)] = true
	_check(tracks.size() == Enums.Biome.size() and kampf.size() == Enums.Biome.size()
		and musik.PARTITUREN.has(musik.biom_track(h)) and musik.PARTITUREN.has(musik.kampf_track(h)),
		"eigene Dungeon- und Kampfmusik je Biom")
	musik.free()
	_check(CardFactory.BIOME_UNLOCK_TIER[h] > CardFactory.BIOME_UNLOCK_TIER[Enums.Biome.CRYPT],
		"Höllenschlund kommt nach der Krypta (Stufe %d)" % CardFactory.BIOME_UNLOCK_TIER[h])
	var unter := {}
	for i in 80:
		unter[CardFactory.make_card(CardFactory.BIOME_UNLOCK_TIER[h] - 1, _rng(i)).biome] = true
	_check(not unter.has(h), "unter der Einstiegsstufe keine Höllenschlund-Karten")
	# Eigener Wurf für späte Biome: die Würfelfolge der Grund-Biome bleibt je
	# Seed wie vorher (gleiches Biom, gleicher Name), etwa jede 5. Karte wird
	# zum Höllenschlund.
	var gleich := true
	var hoellen := 0
	for i in 200:
		var karte_neu := CardFactory.make_card(25, _rng(i))
		var alt := _rng(i)
		alt.randi()  # Seed
		var biom_alt: int = [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS, Enums.Biome.CRYPT][alt.randi_range(0, 3)]
		var praefix_alt := alt.randi_range(0, CardFactory.NAME_PREFIXES.size() - 1)
		if karte_neu.biome == h:
			hoellen += 1
		else:
			gleich = gleich and karte_neu.biome == biom_alt
		gleich = gleich and karte_neu.name_teile[0] == praefix_alt
	_check(gleich, "Grund-Biome und Namen würfeln je Seed wie vor dem Höllenschlund")
	_check(hoellen >= 20 and hoellen <= 70, "Höllenschlund-Anteil auf Stufe 25: %d von 200" % hoellen)
	# Dämonen leben im Höllenschlund, der Klein-Dämon auch noch in der Krypta.
	var daemonen_ok := true
	for id in [&"demonenjager", &"demonenbeschwoerer", &"demonenkonig", &"peiniger", &"aschekoloss"]:
		var a := EnemyLibrary.get_archetype(id)
		daemonen_ok = daemonen_ok and a != null and a.biomes.size() == 1 and a.biomes[0] == h
	var klein := EnemyLibrary.get_archetype(&"kleindaemon")
	_check(daemonen_ok and h in klein.biomes and Enums.Biome.CRYPT in klein.biomes,
		"Dämonen im Höllenschlund, Klein-Dämon auch in der Krypta")
	var krypta := EnemyLibrary.archetypes_for_biome(Enums.Biome.CRYPT, false, 30)
	_check(krypta.size() >= 8 and not EnemyFactory.boss_pool(Enums.Biome.CRYPT, 30).is_empty(),
		"Krypta bleibt voll (%d Grundtypen) und hat Bosse" % krypta.size())
	var hoelle := EnemyLibrary.archetypes_for_biome(h, false, 30)
	_check(hoelle.size() >= 5, "Höllenschlund: genug Grundtypen (%d)" % hoelle.size())
	_check(not EnemyLibrary.archetypes_for_biome(h, false, 1).is_empty(),
		"Wunsch-Karte unter der Einstiegsstufe hat Gegner")
	var bosse := EnemyFactory.boss_pool(h, 20)
	var boss_ids := bosse.map(func(a: EnemyArchetype) -> StringName: return a.id)
	_check(&"demonenkonig" in boss_ids and &"aschekoloss" in boss_ids, "Boss-Pool: Dämonen-König und Aschekoloss")
	_check(ItemLibrary.boss_affixe(BossBeute.pool_boss(&"aschekoloss")).size() >= 2,
		"Aschekoloss lässt Boss-Beute fallen (Pool des Dämonen-Königs)")
	_check(EnemyFactory.BOSS_RUF.has(&"aschekoloss") and EnemyFactory.BOSS_SIGNATURES.has(&"aschekoloss"),
		"Aschekoloss: Begleiter-Ruf und Signatur")
	# Neue Grundtypen vollständig.
	for id in [&"peiniger", &"aschekoloss"]:
		var eig := Eigenheiten.fuer(id)
		_check(eig != &"" and Eigenheiten.TEXTE.has(eig) and Eigenheiten.KONTER.has(eig),
			"%s: Eigenheit mit Gegenweg (%s)" % [id, eig])
		_check(EnemyLibrary.SCHWAECHEN.has(id) and EnemyLibrary.RUESTUNGSKLASSEN.has(id)
			and EnemyLibrary.KOMBOS.get(id, []).size() >= 2 and LootGenerator.ARCHETYPE_MATERIALS.has(id),
			"%s: Schwächen, Rüstungsklasse, Kombos, Material" % id)
		_check(id in ZweibeinerBau.ARTEN or id in KreaturenBau.ARTEN, "%s: eigene Figur" % id)
		var gegner := EnemyFactory.build(EnemyLibrary.get_archetype(id), 25, _rng(3), [], h)
		_check(gegner.max_hp > 0 and gegner.display_name.begins_with("Höllen-"), "%s: baut als %s" % [id, gegner.display_name])
	Loc.set_language("en")
	EnemyLibrary.reset_cache()
	var en := EnemyLibrary.get_archetype(&"peiniger").display_name
	Loc.set_language("de")
	EnemyLibrary.reset_cache()
	_check(en == "Tormentor", "englischer Name (%s)" % en)
	# Begegnungen auf niedriger und hoher Stufe, Karte speichern/laden.
	var ok := true
	for i in 30:
		for gegner in EnemyFactory.make_encounter(_card(i, 3 if i % 2 else 25, h), _rng(i)):
			ok = ok and gegner.max_hp > 0
	_check(ok, "Höllenschlund-Begegnungen auf Stufe 3 und 25")
	var karte := CardFactory.make_card(25, _rng(5), h)
	var zurueck := DungeonCard.from_dict(karte.to_dict())
	_check(zurueck.biome == h and zurueck.display_name == karte.display_name and not karte.display_name.is_empty(),
		"Höllenschlund-Karte übersteht Speichern/Laden (%s)" % karte.display_name)
	_check(CardFactory.name_zerlegen(karte.display_name, h) == karte.name_teile, "Kartenname zerlegbar")


func _card(seed_value: int, tier: int, biome: Enums.Biome,
		modifier_ids: Array[StringName] = []) -> DungeonCard:
	var card := DungeonCard.new()
	card.seed = seed_value
	card.tier = tier
	card.biome = biome
	card.modifier_ids = modifier_ids
	return card


func _test_library() -> void:
	print("Gegner-Bibliothek:")
	_check(EnemyLibrary.all_archetypes().size() >= 7, "mindestens 7 Archetypen")
	var temperaments := {}
	for archetype in EnemyLibrary.all_archetypes():
		temperaments[archetype.temperament] = true
	_check(temperaments.size() >= 2, "mindestens zwei verschiedene Temperamente vertreten")
	var wolf: EnemyArchetype = null
	for archetype in EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST):
		if archetype.id == &"wolf":
			wolf = archetype
	_check(wolf != null and wolf.temperament == Enums.Temperament.AGGRESSIVE,
		"Waldwolf ist aggressiv (jagt immer)")
	_check(EnemyLibrary.all_modifiers().size() >= 6, "mindestens 6 Modifikatoren")
	for biome in Enums.Biome.values():
		_check(not EnemyLibrary.archetypes_for_biome(biome).is_empty(),
			"Biom %d hat Archetypen" % biome)
		_check(not EnemyLibrary.archetypes_for_biome(biome, true).is_empty(),
			"Biom %d hat Boss-Kandidaten" % biome)

	var rolled := EnemyLibrary.roll_modifiers(1, _rng(9))
	var tier_ok := true
	for id in rolled:
		if EnemyLibrary.get_modifier(id).min_tier > 1:
			tier_ok = false
	_check(rolled.size() >= 1 and tier_ok, "roll_modifiers respektiert min_tier")


func _test_build() -> void:
	print("Gegner bauen:")
	var wolf_archetype: EnemyArchetype = EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST)[0]
	var tier1 := EnemyFactory.build(wolf_archetype, 1, _rng(1))
	var tier5 := EnemyFactory.build(wolf_archetype, 5, _rng(1))
	_check(tier1.display_name == wolf_archetype.display_name, "Name ohne Modifikatoren = Archetyp")
	_check(tier5.max_hp > tier1.max_hp, "Tier 5 hat mehr HP als Tier 1")
	_check(not tier1.skills.is_empty(), "Gegner bekommt Skills aus dem Pool")
	_check(tier1.armor == wolf_archetype.armor, "Rüstung vom Archetyp übernommen")
	_check(EnemyFactory.brutal_faktor(25) == 1.0, "Endgame-Schere: bis Stufe 25 kein Aufschlag")
	_check(EnemyFactory.brutal_faktor(40) > 1.3 and EnemyFactory.brutal_faktor(50) > 1.8,
		"Schere spiegelt die Baum-Boni (Stufe 25-50)")
	_check(is_equal_approx(EnemyFactory.brutal_faktor(100), 2.275)
		and is_equal_approx(EnemyFactory.brutal_faktor(150), 2.925)
		and is_equal_approx(EnemyFactory.brutal_faktor(200), 3.575), "Endgame: ×2,3 / ×2,9 / ×3,6")
	_check(EnemyFactory.boss_hp_faktor(60) > EnemyFactory.boss_hp_faktor(10)
		and is_equal_approx(EnemyFactory.boss_hp_faktor(60), EnemyFactory.boss_hp_faktor(200)),
		"Boss-HP-Rampe wächst bis Stufe 60, danach übernimmt die Schere")


func _test_modifiers() -> void:
	print("Elite-Modifikatoren:")
	var archetype: EnemyArchetype = EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST)[0]
	var armored: Array[EnemyModifier] = [EnemyLibrary.get_modifier(&"gepanzert")]
	var plain := EnemyFactory.build(archetype, 1, _rng(1))
	var elite := EnemyFactory.build(archetype, 1, _rng(1), armored)
	_check(elite.armor == plain.armor + 4, "Gepanzert: +4 Rüstung")
	_check(elite.max_hp == roundi(plain.max_hp * 1.2), "Gepanzert: 20% mehr HP")
	_check("Gepanzert" in elite.display_name, "Modifikator steht im Namen")

	var burning: Array[EnemyModifier] = [EnemyLibrary.get_modifier(&"brennend")]
	var fiery := EnemyFactory.build(archetype, 1, _rng(1), burning)
	_check(fiery.skills.size() == plain.skills.size() + 1, "Brennend: verleiht Zusatz-Skill")


func _test_encounters() -> void:
	print("Encounter:")
	var mods: Array[StringName] = [&"gepanzert", &"schnell"]
	var card := _card(777, 2, Enums.Biome.FOREST, mods)
	var group_a := EnemyFactory.make_encounter(card, _rng(55))
	var group_b := EnemyFactory.make_encounter(card, _rng(55))
	_check(group_a.size() == group_b.size(), "gleicher Seed » gleiche Gruppengröße")
	var same := true
	for i in group_a.size():
		if group_a[i].display_name != group_b[i].display_name:
			same = false
	_check(same, "gleicher Seed » identische Gruppe (Kern des Karten-Farmens)")
	_check(group_a.size() >= 1 and group_a.size() <= 3, "Gruppengröße 1-3")

	var biome_ok := true
	for i in 20:
		for enemy in EnemyFactory.make_encounter(_card(i, 1, Enums.Biome.CRYPT), _rng(i)):
			if enemy.display_name.begins_with("Waldwolf") or enemy.display_name.begins_with("Urwaldbär"):
				biome_ok = false
	_check(biome_ok, "Krypta-Encounter enthalten keine Wald-Gegner")

	var elite_found := false
	for i in 40:
		for enemy in EnemyFactory.make_encounter(_card(i, EnemyFactory.ELITE_AB_STUFE, Enums.Biome.FOREST, mods), _rng(i * 3)):
			if "[" in enemy.display_name:
				elite_found = true
	_check(elite_found, "Elite-Gegner mit Karten-Modifikator tauchen auf (ab Stufe %d)" % EnemyFactory.ELITE_AB_STUFE)

	# Güldene Gegner: seltener XP-/Beute-Jackpot (Metallschleim-Prinzip
	# für jede Art) — zäh gepanzert und fluchtfreudig.
	var golden: Combatant = null
	for i in 300:
		for enemy in EnemyFactory.make_encounter(_card(i, 3, Enums.Biome.FOREST), _rng(i * 7)):
			if enemy.display_name.begins_with("Güldener "):
				golden = enemy
	_check(golden != null, "Güldene Gegner tauchen auf (~3% pro Gegner)")
	if golden != null:
		_check(golden.loot_mult >= 6.0, "Gülden: Gold-Jackpot, mindestens ×6 Beute")
		_check(golden.flee_chance >= 0.3, "Gülden: flüchtet gern (Jagd-Druck)")


func _test_boss() -> void:
	print("Boss:")
	var mods: Array[StringName] = [&"brennend"]
	var card := _card(4242, 3, Enums.Biome.FOREST, mods)
	var bosses := EnemyFactory.make_encounter(card, _rng(1), true)
	_check(bosses.size() == 1, "Boss-Encounter hat genau einen Gegner")
	var boss := bosses[0]
	_check(boss.display_name.begins_with("Boss: "), "Boss-Namenspräfix")
	_check("Brennend" in boss.display_name, "Boss trägt die Karten-Modifikatoren")

	var normal_rng := _rng(1)
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, true, card.tier)
	var archetype := pool[normal_rng.randi_range(0, pool.size() - 1)]
	var normal := EnemyFactory.build(archetype, card.tier, normal_rng,
		[EnemyLibrary.get_modifier(&"brennend")])
	_check(boss.max_hp > normal.max_hp, "Boss hat deutlich mehr HP als Normalform")

func _test_layered_generation() -> void:
	print("Geschichtete Generierung (Grundtyp × Region × Element × Rarität):")
	_check(EnemyLibrary.all_archetypes().size() >= 12,
		"Grundtyp-Pool ist gewachsen (%d)" % EnemyLibrary.all_archetypes().size())

	# Pool wächst mit der Stufe.
	var early := EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST, false, 1)
	var later := EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST, false, 5)
	_check(later.size() > early.size(),
		"Wald-Pool wächst mit der Stufe (%d » %d)" % [early.size(), later.size()])
	var crypt_low := EnemyLibrary.archetypes_for_biome(Enums.Biome.CRYPT, false, 7)
	var crypt_high := EnemyLibrary.archetypes_for_biome(Enums.Biome.CRYPT, false, 12)
	_check(crypt_high.size() > crypt_low.size(),
		"Krypta-Pool: Nekromant/Schattenbestie kommen später dazu (%d » %d)"
		% [crypt_low.size(), crypt_high.size()])

	# Region-Variante: Biom prägt Namen + Werte.
	var wolf := EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST, false, 1)[0]
	var forest_wolf := EnemyFactory.build(wolf, 3, _rng(1), [], Enums.Biome.FOREST)
	_check(forest_wolf.display_name.begins_with("Wald-"),
		"Region-Präfix im Namen (%s)" % forest_wolf.display_name)
	var cave_wolf := EnemyFactory.build(wolf, 3, _rng(1), [], Enums.Biome.CAVE)
	_check(cave_wolf.max_hp > forest_wolf.max_hp,
		"Höhlen-Variante hat mehr HP als Wald-Variante (%d > %d)"
		% [cave_wolf.max_hp, forest_wolf.max_hp])

	# Element-Schicht: Elementangriff + Resistenz + Namenszusatz.
	var fiery := EnemyFactory.build(wolf, 3, _rng(1), [], Enums.Biome.FOREST,
		Enums.Element.FIRE)
	_check("(Feuer)" in fiery.display_name, "Element im Namen (%s)" % fiery.display_name)
	_check(fiery.magic_resist > forest_wolf.magic_resist, "Element-Typ gibt Resistenz")
	var has_element_skill := false
	for skill in fiery.skills:
		if skill.get_element() != null and skill.get_element().element == Enums.Element.FIRE:
			has_element_skill = true
	_check(has_element_skill, "Element-Typ verleiht passenden Elementangriff")

	# Champions tauchen auf hohen Stufen auf (2 Modifikatoren, dicke Beute).
	var champion_card := DungeonCard.new()
	champion_card.seed = 42
	champion_card.tier = 8
	champion_card.biome = Enums.Biome.CAVE
	champion_card.modifier_ids = [&"gepanzert", &"schnell"] as Array[StringName]
	var champion_found := false
	for i in 80:
		var rng := _rng(i)
		for enemy in EnemyFactory.make_encounter(champion_card, rng):
			if enemy.display_name.begins_with("Champion: "):
				champion_found = true
				_check(enemy.loot_mult >= EnemyFactory.CHAMPION_LOOT_MULT,
					"Champion hat massiv erhöhte Beute (%.1f)" % enemy.loot_mult)
				break
		if champion_found:
			break
	_check(champion_found, "Champions erscheinen auf hohen Stufen")

	# Biome gehen NIE in Rente (Langzeit-Design: Krypta-only ab Stufe 17
	# wäre auf hunderten Stunden tödlich repetitiv) — auf hohen Stufen
	# bleiben ALLE vier Biome im Karten-Pool.
	var high_biomes := {}
	for i in 60:
		var roll_rng := _rng(i)
		high_biomes[CardFactory.make_card(25, roll_rng).biome] = true
	_check(high_biomes.has(Enums.Biome.FOREST),
		"Stufe 25: Wald bleibt im Pool (keine Biom-Rente)")
	_check(high_biomes.size() == Enums.Biome.size(), "Stufe 25: alle %d Biome verfügbar" % Enums.Biome.size())


func _test_class_variants() -> void:
	print("Klassen-Varianten (Humanoide nutzen Waffenarten, Schleim-Sorten):")
	var skeleton := EnemyLibrary.get_archetype(&"skelett")
	var slime := EnemyLibrary.get_archetype(&"schleim")
	_check(skeleton.variant_group == &"humanoid" and slime.variant_group == &"schleim",
		"Skelett und Schleim tragen Varianten-Gruppen")

	# Über viele Builds erscheinen mehrere Klassen — und die Basisform bleibt.
	var names := {}
	var archer: Combatant = null
	var summoner_found := false
	for i in 120:
		var enemy := EnemyFactory.build(skeleton, 6, _rng(i))
		names[enemy.display_name.split(" ")[0]] = true
		if "Bogenschütze" in enemy.display_name and archer == null:
			archer = enemy
		if "Beschwörer" in enemy.display_name:
			for skill in enemy.skills:
				if skill.get_form() == Enums.SkillForm.SUMMON:
					summoner_found = true
	_check(names.has("Skelett-Krieger") and names.has("Skelett-Magier"),
		"Skelette kommen als Krieger, Magier & Co. (%d Formen)" % names.size())
	_check(names.has("Skelett"), "die Basisform existiert weiterhin")
	_check(archer != null and archer.weapon_hit_count() == 2,
		"Skelett-Bogenschütze feuert 2 Pfeile pro Angriff")
	_check(summoner_found, "Skelett-Beschwörer nutzt das Beschwörungs-System")

	# Schleim-Sorten: Metall panzert, Gift vergiftet, Heil unterstützt.
	var slime_names := {}
	var metal: Combatant = null
	var toxic_has_poison := false
	for i in 120:
		var enemy := EnemyFactory.build(slime, 4, _rng(i * 3 + 1))
		slime_names[enemy.display_name] = true
		if enemy.display_name == "Metallschleim" and metal == null:
			metal = enemy
		if enemy.display_name == "Giftschleim":
			for skill in enemy.skills:
				var element := skill.get_element()
				if element != null and element.element == Enums.Element.POISON:
					toxic_has_poison = true
	_check(slime_names.has("Metallschleim") and slime_names.has("Giftschleim")
		and slime_names.has("Heilschleim"),
		"Metall-/Gift-/Heilschleim tauchen alle auf")
	_check(metal != null and metal.armor >= slime.armor + 6,
		"Metallschleim ist deutlich gepanzerter")
	_check(toxic_has_poison, "Giftschleim greift mit Gift an")

	# Determinismus: gleicher Seed » gleiche Variante (Karten-Farmen!).
	var a := EnemyFactory.build(skeleton, 6, _rng(77))
	var b := EnemyFactory.build(skeleton, 6, _rng(77))
	_check(a.display_name == b.display_name, "gleicher Seed » gleiche Klasse")

	# Troll hat keine Varianten-Gruppe und bleibt unangetastet.
	var troll := EnemyLibrary.get_archetype(&"troll")
	var plain_troll := EnemyFactory.build(troll, 6, _rng(5))
	_check(plain_troll.display_name == "Troll", "Archetypen ohne Gruppe bleiben pur")

	# Bestien-/Geister-/Konstrukt-Gruppen + Bandit (Monster-Welle).
	_check(EnemyLibrary.get_archetype(&"wolf").variant_group == &"bestie"
		and EnemyLibrary.get_archetype(&"geist").variant_group == &"geist"
		and EnemyLibrary.get_archetype(&"golem").variant_group == &"konstrukt",
		"Bestien/Geister/Konstrukte tragen ihre Varianten-Gruppen")
	var bandit := EnemyLibrary.get_archetype(&"bandit")
	_check(bandit != null and bandit.variant_group == &"humanoid"
		and bandit.calls_reinforcements,
		"Bandit: humanoide Klassen-Varianten + ruft Kumpane")


func _test_kombos_und_ki() -> void:
	print("Kombo-Skills & Gegner-KI:")
	# Jede Kombo gehört zu einem echten Grundtyp und ist ein gültiger Skill.
	var kaputt: Array[String] = []
	for id in EnemyLibrary.KOMBOS:
		if EnemyLibrary.get_archetype(id) == null:
			kaputt.append(String(id))
		for skill in EnemyLibrary.kombos_fuer(id, 999):
			if not skill.is_valid():
				kaputt.append("%s: %s (%s)" % [id, skill.display_name, skill.fehler()])
	_check(kaputt.is_empty(), "alle Kombos gültig und zugeordnet %s" % [kaputt])
	_check(EnemyLibrary.kombos_fuer(&"wolf", 1).size() == 1 and EnemyLibrary.kombos_fuer(&"wolf", 4).size() == 2,
		"Kombos schalten sich mit der Kartenstufe frei")

	# Gleicher Seed » gleiche Skills (Karten bleiben deterministisch).
	var a := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 6, _rng(5))
	var b := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 6, _rng(5))
	var namen_a: Array[String] = []
	var namen_b: Array[String] = []
	for skill in a.skills:
		namen_a.append(skill.display_name)
	for skill in b.skills:
		namen_b.append(skill.display_name)
	_check(namen_a == namen_b, "gleicher Seed, gleiche Skills (%s)" % [namen_a])
	var mit_kombo := 0
	for i in 40:
		var wolf := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 6, _rng(100 + i))
		if wolf.skills.size() > 1:
			mit_kombo += 1
	_check(mit_kombo > 15 and mit_kombo < 40, "die meisten, aber nicht alle Wölfe haben eine Kombo (%d/40)" % mit_kombo)

	# Rollen der KI.
	var heil := EnemyLibrary.kombos_fuer(&"koenigschleim", 1)[0]
	var panzer := EnemyLibrary.kombos_fuer(&"golem", 1)[0]
	var biss := EnemyLibrary.kombos_fuer(&"wolf", 1)[0]
	_check(Battle.ki_rolle(heil) == &"heilen" and Battle.ki_rolle(panzer) == &"helfen"
		and Battle.ki_rolle(biss) == &"angreifen", "KI erkennt Heilen / Helfen / Angreifen")

	# Heilt verwundete Verbündete — und stärkt niemals die Helden.
	var held := Combatant.create("Held", _gleich(8), true)
	var priester := Combatant.create("Priester", _gleich(8), false)
	priester.innate_spell_damage = 10
	priester.skills = [heil]
	var krieger := Combatant.create("Krieger", _gleich(8), false)
	var battle := Battle.new()
	battle.rng.seed = 3
	battle.start([held] as Array[Combatant], [priester, krieger] as Array[Combatant])
	krieger.hp = 1
	var geheilt := false
	for i in 6:
		priester.mp = 999
		battle.ai_take_turn(priester)
		if krieger.hp > 1:
			geheilt = true
			break
	_check(geheilt, "Gegner-Priester heilt den angeschlagenen Verbündeten")

	var golem := Combatant.create("Golem", _gleich(8), false)
	golem.skills = [panzer]
	var held2 := Combatant.create("Held", _gleich(8), true)
	var battle2 := Battle.new()
	battle2.rng.seed = 4
	battle2.start([held2] as Array[Combatant], [golem] as Array[Combatant])
	var golem_gepanzert := false
	for i in 20:
		golem.mp = 999
		held2.hp = held2.max_hp
		battle2.ai_take_turn(golem)
		golem_gepanzert = golem_gepanzert or golem.has_status(Enums.Status.DEF_UP)
	_check(golem_gepanzert and not held2.has_status(Enums.Status.DEF_UP),
		"Steinhaut landet beim Golem, nie beim Helden")

	# Bosse beherrschen alle Kombos ihres Grundtyps.
	var boss_karte := _card(77, 10, Enums.Biome.CRYPT)
	var bosse := EnemyFactory.make_encounter(boss_karte, _rng(9), true)
	var boss: Combatant = bosse[0]
	var erwartet := EnemyLibrary.kombos_fuer(boss.archetype_id, 10).size()
	var hat := 0
	for kombo in EnemyLibrary.kombos_fuer(boss.archetype_id, 10):
		for skill in boss.skills:
			if skill.display_name == kombo.display_name:
				hat += 1
				break
	_check(hat == erwartet, "Boss %s kennt alle %d Kombos" % [boss.display_name, erwartet])


func _gleich(wert: int) -> StatBlock:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, wert)
	return stats


func _test_sondergegner() -> void:
	print("Sondergegner (Gold, XP, Schatzkarte):")
	var arten := {}
	for i in 600:
		for enemy in EnemyFactory.make_encounter(_card(i, 10, Enums.Biome.FOREST), _rng(i * 11)):
			if enemy.get_meta(&"gulden", false):
				arten["gold"] = enemy
			elif enemy.get_meta(&"sonder", "") == "strahlend":
				arten["xp"] = enemy
			elif enemy.get_meta(&"schatzkarte", false):
				arten["karte"] = enemy
	_check(arten.has("gold") and arten.has("xp") and arten.has("karte"),
		"alle drei Sondergegner tauchen auf (%s)" % ", ".join(arten.keys()))
	if arten.has("xp"):
		_check(arten["xp"].xp_mult >= 8.0 and arten["xp"].flee_chance >= 0.3,
			"Strahlender: XP-Jackpot (×8), flüchtet gern")
	if arten.has("karte"):
		_check(arten["karte"].flee_chance == 0.0 and arten["karte"].display_name.begins_with("Kartenhüter"),
			"Kartenhüter: flieht nicht, trägt den Namen")
	var gleiche_karte := EnemyFactory.make_encounter(_card(42, 10, Enums.Biome.FOREST), _rng(42))
	var nochmal := EnemyFactory.make_encounter(_card(42, 10, Enums.Biome.FOREST), _rng(42))
	var gleich := gleiche_karte.size() == nochmal.size()
	for i in mini(gleiche_karte.size(), nochmal.size()):
		gleich = gleich and gleiche_karte[i].display_name == nochmal[i].display_name
	_check(gleich, "gleicher Seed » gleiche Gruppe inkl. Sondergegner")
	var legendaer := false
	var episch := false
	var stufen_ok := true
	for i in 40:
		var schatz := CardFactory.make_schatzkarte(10)
		stufen_ok = stufen_ok and schatz.tier >= 11 and schatz.tier <= 15
		legendaer = legendaer or schatz.card_rarity == Enums.Rarity.LEGENDARY
		episch = episch or schatz.card_rarity == Enums.Rarity.EPIC
	_check(stufen_ok, "Schatzkarte liegt 1-5 Stufen über der Karte")
	_check(legendaer and episch, "Schatzkarten sind episch oder legendär")


func _test_anfuehrer() -> void:
	print("Anführer-Affixe & Entzaubern:")
	var banner := EnemyLibrary.get_modifier(&"bannertraeger")
	_check(banner != null and banner.aura_status == Enums.Status.ATK_UP and banner.xp_multiplier > 1.0
		and banner.loot_multiplier > 1.0, "Bannerträger: Stärken-Aura, mehr XP und Beute")
	var mods: Array[EnemyModifier] = [banner]
	var traeger := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 10, _rng(1), mods)
	var kumpel := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 10, _rng(2))
	_check(traeger.has_meta(&"auren") and traeger.xp_mult >= 1.5, "Träger hat Aura und ×1,5 XP")
	var held_stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		held_stats.set(stat, 10)
	var held := Combatant.create("Held", held_stats, true)
	var battle := Battle.new()
	battle.start([held] as Array[Combatant], [traeger, kumpel] as Array[Combatant])
	battle._process_turn_start(traeger)
	var e1 := kumpel.get_status(Enums.Status.ATK_UP)
	battle._process_turn_start(traeger)
	var e2 := kumpel.get_status(Enums.Status.ATK_UP)
	_check(not e1.is_empty() and int(e2.get("stufe", 0)) == 2, "Aura stärkt die Gruppe jeden Zug — Stufe 2 nach zwei Zügen")
	_check(not held.has_status(Enums.Status.ATK_UP), "Helden bekommen die Gegner-Aura nicht")
	var entzaubern := Skill.new()
	entzaubern.blocks = [BlockLibrary.get_block(&"src_spell"), BlockLibrary.get_block(&"form_aoe"),
		BlockLibrary.get_block(&"eff_entzaubern")]
	held.mp = 999
	battle.use_skill(held, entzaubern, kumpel)
	_check(not kumpel.has_status(Enums.Status.ATK_UP) and not traeger.has_status(Enums.Status.ATK_UP),
		"Entzaubern (Fläche) nimmt allen Gegnern die Stärkungen")


## Reine Anzeige-Infos für die 3D-Figuren (STIL-3D.md 7k/9): die Variante als
## Meta am Gegner, die sprachfeste Skill-Kennung und das Battle-Ereignis
## "faehigkeit" — ohne an Werten oder Würfeln etwas zu ändern.
func _test_anzeige_infos() -> void:
	print("Anzeige-Infos für Figuren (Variante, Fähigkeits-Ereignis):")
	var varianten := {}
	for gruppe in EnemyFactory.VARIANT_GROUPS:
		for eintrag in EnemyFactory.VARIANT_GROUPS[gruppe]:
			varianten[String(eintrag["name"]).to_lower()] = true
	var ohne_akzent: Array = []
	for v in varianten:
		if not FigurenBau.VARIANTEN_AKZENT.has(v):
			ohne_akzent.append(v)
	_check(ohne_akzent.is_empty(), "jede Klassen-Variante hat eine Akzentfarbe %s" % [ohne_akzent])
	var slime := EnemyLibrary.get_archetype(&"schleim")
	var mit_meta := 0
	var stimmt := true
	for i in 60:
		var enemy := EnemyFactory.build(slime, 4, _rng(i * 3 + 1))
		var ohne := EnemyFactory.build(slime, 4, _rng(i * 3 + 1))
		if enemy.has_meta(&"variante"):
			mit_meta += 1
			stimmt = stimmt and enemy.display_name.to_lower().begins_with(String(enemy.get_meta(&"variante")))
		stimmt = stimmt and enemy.display_name == ohne.display_name and enemy.max_hp == ohne.max_hp
	_check(mit_meta > 0 and stimmt, "Schleim-Varianten tragen Meta \"variante\" passend zum Namen (%d)" % mit_meta)
	# Sprachfeste Kennung an Grund-, Kombo- und Varianten-Skills.
	var sprache: String = Loc.language
	Loc.language = "en"
	var igel_kombos := EnemyLibrary.kombos_fuer(&"verfluchtigel", 99)
	Loc.language = sprache
	var stachel: Skill = null
	for skill in igel_kombos:
		if String(skill.get_meta(&"fx_id", "")) == "Stachelpanzer":
			stachel = skill
	_check(stachel != null and stachel.display_name == "Spine armor",
		"Kombo-Skill trägt die Kennung \"Stachelpanzer\" auch auf Englisch (\"Spine armor\")")
	var koenig := EnemyLibrary.get_archetype(&"koenigschleim")
	var woge := false
	for skill in koenig.skill_pool:
		woge = woge or String(skill.get_meta(&"fx_id", "")) == "Schleimwoge"
	_check(woge, "Grund-Skill trägt die Kennung \"Schleimwoge\"")
	# Battle meldet die laufende Fähigkeit als Ereignis (von = Anwender).
	var igel := EnemyFactory.build(EnemyLibrary.get_archetype(&"verfluchtigel"), 5, _rng(3), [], -1,
		Enums.Element.NONE, false)
	var held := Combatant.create("Held", StatBlock.new(), true)
	held.max_hp = 500
	held.hp = 500
	var battle := Battle.new()
	battle.rng.seed = 4
	battle.start([held] as Array[Combatant], [igel] as Array[Combatant])
	var ereignisse: Array = []
	battle.effekt.connect(func(d: Dictionary) -> void:
		if d.get("art") == &"faehigkeit":
			ereignisse.append(d))
	igel.mp = 999
	battle.use_skill(igel, stachel, igel)
	_check(ereignisse.size() == 1 and ereignisse[0].get("von") == igel
		and ereignisse[0].get("skill") == "Stachelpanzer"
		and int(ereignisse[0].get("form")) == Enums.SkillForm.SELF,
		"Battle meldet \"faehigkeit\" mit Kennung und Form")


## Eigene Höhlen-Gegner (Lutz 2026-11-02): vorher teilte die Höhle alle
## Grundtypen mit Wald und Ruinen.
func _test_hoehlen_familie() -> void:
	print("Höhlen-Familie:")
	var exklusiv: Array[String] = []
	for arch in EnemyLibrary.all_archetypes():
		if arch.biomes.size() == 1 and arch.biomes[0] == Enums.Biome.CAVE:
			exklusiv.append(String(arch.id))
	_check(exklusiv.size() >= 3 and &"kristallkoenigin" in exklusiv,
		"die Höhle hat eigene Grundtypen und einen eigenen Boss %s" % [exklusiv])
	var fehlt: Array[String] = []
	for id in [&"grubenratte", &"kristallkaefer", &"blindolm", &"kristallkoenigin"]:
		var arch := EnemyLibrary.get_archetype(id)
		if arch == null or arch.armor_class == Enums.ArmorClass.NONE or arch.element_faktoren.is_empty() 				or EnemyLibrary.kombos_fuer(id, 999).size() < 3:
			fehlt.append(String(id))
		elif not arch.boss_only and Eigenheiten.fuer(id) == &"":
			fehlt.append("%s ohne Eigenheit" % id)
		if not (id in KreaturenBau.ARTEN or id in VierbeinerBau.ARTEN):
			fehlt.append("%s ohne Figur" % id)
	_check(fehlt.is_empty(), "neue Höhlen-Typen: Rüstungsklasse, Schwächen, Eigenheit, 3 Kombos, Figur %s" % [fehlt])
	var koenigin := EnemyLibrary.get_archetype(&"kristallkoenigin")
	_check(koenigin.boss_only and koenigin.is_boss_capable
		and EnemyFactory.BOSS_SIGNATURES.get(&"kristallkoenigin", &"") != &""
		and koenigin not in EnemyLibrary.archetypes_for_biome(Enums.Biome.CAVE, false, 999),
		"Kristallkönigin: nur Boss, mit Signatur, nie als normaler Gegner")
	var gefunden := false
	for seed_nr in 60:
		var card := DungeonCard.new()
		card.seed = seed_nr
		card.tier = 12
		card.biome = Enums.Biome.CAVE
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_nr
		if EnemyFactory.make_encounter(card, rng, true)[0].archetype_id == &"kristallkoenigin":
			gefunden = true
			break
	_check(gefunden, "Höhlen-Karten würfeln die Kristallkönigin als Boss")
	Loc.set_language("en")
	EnemyLibrary.reset_cache()
	var en := EnemyLibrary.get_archetype(&"blindolm").display_name
	Loc.set_language("de")
	EnemyLibrary.reset_cache()
	_check(en == "Blind Olm" and EnemyLibrary.get_archetype(&"blindolm").display_name == "Blindolm", "Namen DE und EN")


## Kombo-Ausbau (I3): Grundtypen mit einem Kombo bekommen 1-2 weitere, die erst
## auf höheren Kartenstufen dazukommen; DE/EN-Namen eindeutig.
func _test_kombo_ausbau() -> void:
	print("Kombo-Ausbau:")
	var zu_wenig: Array[String] = []
	for id in [&"schattenbestie", &"toddiener", &"leichenfresser", &"kleindaemon", &"demonenjager",
			&"verfluchtkatz", &"verfluchtigel", &"verfluchtdachs", &"verfluchtbock", &"pilzstamm", &"mimic",
			&"schleim", &"schleimstapel", &"koenigschleim", &"pilzkrabbel"]:
		var eintraege: Array = EnemyLibrary.KOMBOS.get(id, [])
		if eintraege.size() < 2:
			zu_wenig.append(String(id))
			continue
		var erste := int(eintraege[0][3])
		for e in eintraege.slice(1):
			if int(e[3]) <= erste or int(e[3]) < 25:
				zu_wenig.append("%s/%s ab %d" % [id, e[0], e[3]])
	_check(zu_wenig.is_empty(), "jeder Ein-Kombo-Typ hat weitere Kombos ab Stufe 25 %s" % [zu_wenig])
	var namen := {}
	var doppelt: Array[String] = []
	var unuebersetzt: Array[String] = []
	for id in EnemyLibrary.KOMBOS:
		for e in EnemyLibrary.KOMBOS[id]:
			if namen.has(e[0]):
				doppelt.append(e[0])
			namen[e[0]] = true
			if e[0] == e[1] or String(e[1]).is_empty():
				unuebersetzt.append(e[0])
			for block_id in e[2]:
				if BlockLibrary.get_block(block_id) == null:
					doppelt.append("%s: %s fehlt" % [e[0], block_id])
	_check(doppelt.is_empty(), "Kombo-Namen eindeutig, alle Klötze vorhanden %s" % [doppelt])
	_check(unuebersetzt.is_empty(), "jeder Kombo hat einen englischen Namen %s" % [unuebersetzt])
	# Frühe Karten unverändert: auf Stufe 20 hat kein Ein-Kombo-Typ mehr Kombos als vorher.
	_check(EnemyLibrary.kombos_fuer(&"toddiener", 20).size() == 1
		and EnemyLibrary.kombos_fuer(&"toddiener", 60).size() == 3, "Toddiener: 1 Kombo auf Stufe 20, 3 auf Stufe 60")
	var k := EnemyLibrary.kombos_fuer(&"mimic", 99)
	_check(k.size() == 3 and String(k[1].get_meta(&"fx_id")) == "Münzhagel", "Kombos tragen ihre sprachfeste fx_id")
