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
	for biome in [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS, Enums.Biome.CRYPT]:
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
		for enemy in EnemyFactory.make_encounter(_card(i, 2, Enums.Biome.FOREST, mods), _rng(i * 3)):
			if "[" in enemy.display_name:
				elite_found = true
	_check(elite_found, "Elite-Gegner mit Karten-Modifikator tauchen auf")


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

	# Biom-Fenster: Wald verschwindet auf hohen Stufen aus dem Karten-Pool.
	var high_biomes := {}
	for i in 60:
		var roll_rng := _rng(i)
		high_biomes[CardFactory.make_card(12, roll_rng).biome] = true
	_check(not high_biomes.has(Enums.Biome.FOREST),
		"Stufe 12: keine Wald-Karten mehr (Biom-Fenster)")
	_check(high_biomes.has(Enums.Biome.CRYPT), "Stufe 12: Krypta ist im Pool")


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

	# Wolf & Co. bleiben unangetastet (keine Varianten-Gruppe).
	var wolf := EnemyLibrary.get_archetype(&"wolf")
	var plain_wolf := EnemyFactory.build(wolf, 6, _rng(5))
	_check(plain_wolf.display_name == "Wolf", "Archetypen ohne Gruppe bleiben pur")
